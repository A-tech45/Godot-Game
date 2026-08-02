extends Node

## NetworkManager: WebSocket Relay (Internet) & ENet (Local LAN) Multiplayer Manager.

signal lobby_updated
signal connection_failed(reason: String)
signal connection_succeeded
signal peer_joined_lobby(peer_id: int, info: Dictionary)
signal peer_left_lobby(peer_id: int)
signal match_start_requested
signal connection_status_changed(status_text: String)

const DEFAULT_PORT: int = 7350
const MAX_PLAYERS: int = 12

# ─── RELAY SERVER URL ───
# For local testing: "ws://localhost:9090"
const RELAY_URL: String = "wss://server-relay.onrender.com"

var is_online: bool = false
var is_host: bool = false
var local_player_name: String = "Player"
var room_code: String = ""
var is_private_room: bool = false
var manual_bot_count: int = 0

# Peer registry: peer_id -> { "name": String, "color": Color, "ready": bool }
var connected_players: Dictionary = {}

# ─── WEBSOCKET RELAY VARIABLES ───
var is_relay_mode: bool = false
var relay_socket: WebSocketPeer = null
var my_relay_id: int = 0
var relay_connected: bool = false
var relay_init_received: bool = false
var connection_timeout_timer: float = 0.0
const CONNECTION_TIMEOUT: float = 45.0  # Longer timeout for Render cold starts

# Retry logic for Render.com free tier cold starts
var _retry_count: int = 0
const MAX_RETRIES: int = 3
var _pending_room_code: String = ""
var _pending_is_hosting: bool = false

const CODE_CHARS = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if not is_online:
		return

	if is_relay_mode and relay_socket != null:
		relay_socket.poll()
		var state = relay_socket.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			if not relay_connected:
				relay_connected = true
				connection_timeout_timer = 0.0

			# Process incoming relay messages
			while relay_socket.get_available_packet_count() > 0:
				var pkt = relay_socket.get_packet()
				_handle_relay_message(pkt)

		elif state == WebSocketPeer.STATE_CONNECTING:
			connection_timeout_timer += delta
			if connection_timeout_timer >= CONNECTION_TIMEOUT:
				connection_failed.emit("Connection to relay server timed out.")
				reset_network()

		elif state == WebSocketPeer.STATE_CLOSING:
			pass  # Wait for close to complete

		elif state == WebSocketPeer.STATE_CLOSED:
			if relay_connected:
				# Was connected, lost connection
				relay_connected = false
				if is_online:
					connection_failed.emit("Lost connection to relay server.")
					reset_network()
					get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			else:
				# Never connected — try again (Render cold start)
				if _retry_count < MAX_RETRIES:
					_retry_count += 1
					connection_status_changed.emit("Server waking up... (attempt %d/%d)" % [_retry_count + 1, MAX_RETRIES + 1])
					_reconnect_relay()
				else:
					var close_code = relay_socket.get_close_code()
					var reason_text = relay_socket.get_close_reason()
					if reason_text == "":
						reason_text = "Could not reach relay server after %d attempts" % (MAX_RETRIES + 1)
					connection_failed.emit(reason_text)
					reset_network()


## Get this peer's network ID (works for both relay and ENet modes)
func get_my_id() -> int:
	if is_relay_mode:
		return my_relay_id
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


## Host a new multiplayer room via WebSocket relay
func host_room(p_name: String, p_is_private: bool, p_bot_count: int = 0) -> bool:
	reset_network()

	local_player_name = p_name if p_name.strip_edges() != "" else "Host_Player"
	is_private_room = p_is_private
	manual_bot_count = p_bot_count
	is_online = true
	is_host = true
	is_relay_mode = true

	# Generate clean 6-character room code
	room_code = _generate_random_code()

	# Connect to relay server
	_pending_room_code = room_code
	_pending_is_hosting = true
	_retry_count = 0
	relay_socket = WebSocketPeer.new()
	var url = RELAY_URL + "/room/" + room_code
	var err = relay_socket.connect_to_url(url)
	if err != OK:
		connection_failed.emit("Failed to connect to relay server.")
		reset_network()
		return false

	connection_timeout_timer = 0.0
	connection_status_changed.emit("Connecting to relay server...")

	# We'll register host info once we receive the "init" message from relay
	return true


## Join an existing room via Room Code or Direct IP address
func join_room_by_code(code: String, p_name: String) -> void:
	reset_network()

	local_player_name = p_name if p_name.strip_edges() != "" else "Player_" + str(randi_range(100, 999))
	var clean_code = code.strip_edges().to_upper()
	room_code = clean_code

	# Check if code is a direct local IP address (e.g. 192.168.1.5)
	if clean_code.is_valid_ip_address() or (":" in clean_code and not clean_code.begins_with("[")):
		_join_enet_lan(clean_code)
		return

	# WebSocket Relay Join
	is_online = true
	is_host = false
	is_relay_mode = true
	_pending_room_code = room_code
	_pending_is_hosting = false
	_retry_count = 0

	relay_socket = WebSocketPeer.new()
	var url = RELAY_URL + "/room/" + room_code
	var err = relay_socket.connect_to_url(url)
	if err != OK:
		connection_failed.emit("Failed to connect to relay server.")
		reset_network()
		return

	connection_timeout_timer = 0.0
	connection_status_changed.emit("Connecting to relay server...")


func _join_enet_lan(ip_str: String) -> void:
	is_online = true
	is_host = false
	is_relay_mode = false

	var host_ip = ip_str.split(":")[0]
	var port = DEFAULT_PORT
	if ":" in ip_str:
		var parts = ip_str.split(":")
		if parts.size() > 1 and parts[1].is_valid_int():
			port = parts[1].to_int()

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(host_ip, port)
	if err != OK:
		connection_failed.emit("Could not connect to LAN host " + ip_str)
		reset_network()
		return

	multiplayer.multiplayer_peer = peer


func reset_network() -> void:
	is_online = false
	is_host = false
	is_relay_mode = false
	room_code = ""
	connected_players.clear()
	relay_connected = false
	relay_init_received = false
	my_relay_id = 0
	connection_timeout_timer = 0.0
	_retry_count = 0
	_pending_room_code = ""
	_pending_is_hosting = false

	if relay_socket != null:
		relay_socket.close()
		relay_socket = null

	if multiplayer.has_multiplayer_peer():
		var old_peer = multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer = null
		if old_peer:
			old_peer.close()


## Retry connecting to relay (for Render.com cold starts)
func _reconnect_relay() -> void:
	if _pending_room_code == "":
		return

	# Close old socket
	if relay_socket != null:
		relay_socket.close()
		relay_socket = null

	# Restore state
	room_code = _pending_room_code
	is_online = true
	is_relay_mode = true
	is_host = _pending_is_hosting
	relay_connected = false
	relay_init_received = false

	relay_socket = WebSocketPeer.new()
	var url = RELAY_URL + "/room/" + room_code
	var err = relay_socket.connect_to_url(url)
	if err != OK:
		connection_failed.emit("Failed to reconnect to relay server.")
		reset_network()
		return

	connection_timeout_timer = 0.0


## Host starts match for all peers
func start_multiplayer_match() -> void:
	if not is_host or not is_online:
		return
	if is_relay_mode:
		# Send start_match through relay to all peers
		_send_relay_json({
			"type": "start_match",
			"bot_count": manual_bot_count
		})
		# Also start locally
		GameManager.start_match(manual_bot_count, 22, 22)
		match_start_requested.emit()
		get_tree().change_scene_to_file("res://scenes/arena.tscn")
	else:
		rpc("_client_receive_start_match")


@rpc("call_local", "reliable")
func _client_receive_start_match() -> void:
	var bots_to_spawn: int = manual_bot_count
	GameManager.start_match(bots_to_spawn, 22, 22)
	match_start_requested.emit()
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


# ─── RELAY: SEND HELPERS ───

func _send_relay_json(data: Dictionary) -> void:
	if relay_socket == null or relay_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var json_str = JSON.stringify(data)
	relay_socket.send_text(json_str)


## Send a game-time RPC through the relay (broadcast to all other peers)
func send_relay_rpc(node_path: String, method: String, args: Array) -> void:
	_send_relay_json({
		"type": "rpc_relay",
		"sender_id": my_relay_id,
		"node_path": node_path,
		"method": method,
		"args": args
	})


## Serialize a Vector2 to a relay-safe array
func vec2_to_array(v: Vector2) -> Array:
	return [v.x, v.y]

## Deserialize a relay array back to a Vector2
func array_to_vec2(a: Array) -> Vector2:
	if a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO

## Serialize a Color to a relay-safe array
func color_to_array(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]

## Deserialize a relay array back to a Color
func array_to_color(a: Array) -> Color:
	if a.size() >= 4:
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	elif a.size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color.WHITE


# ─── RELAY: MESSAGE HANDLING ───

func _handle_relay_message(data: PackedByteArray) -> void:
	var text = data.get_string_from_utf8()
	var json = JSON.parse_string(text)
	if json == null or not (json is Dictionary):
		return

	var msg_type = json.get("type", "")

	if msg_type == "init":
		_on_relay_init(json)
	elif msg_type == "peer_joined":
		_on_relay_peer_joined(json)
	elif msg_type == "peer_left":
		_on_relay_peer_left(json)
	elif msg_type == "player_info":
		_on_relay_player_info(json)
	elif msg_type == "lobby_sync":
		_on_relay_lobby_sync(json)
	elif msg_type == "start_match":
		_on_relay_start_match(json)
	elif msg_type == "rpc_relay":
		_on_relay_rpc(json)


func _on_relay_init(data: Dictionary) -> void:
	my_relay_id = int(data.get("your_id", 0))
	var is_relay_host = data.get("is_host", false)
	relay_init_received = true

	if is_relay_host:
		is_host = true
		# Register host in connected_players
		var host_color = Color.from_hsv(randf(), 0.8, 0.95)
		connected_players[1] = {
			"id": 1,
			"name": local_player_name,
			"color": host_color,
			"ready": true
		}
		lobby_updated.emit()
		connection_succeeded.emit()
	else:
		is_host = false
		# Send our player info to the room (host will process it)
		var p_color = Color.from_hsv(randf(), 0.85, 0.95)
		_send_relay_json({
			"type": "player_info",
			"peer_id": my_relay_id,
			"name": local_player_name,
			"color_r": p_color.r,
			"color_g": p_color.g,
			"color_b": p_color.b
		})
		connection_succeeded.emit()


func _on_relay_peer_joined(_data: Dictionary) -> void:
	# The new peer will send their player_info, host will then broadcast lobby_sync
	pass


func _on_relay_peer_left(data: Dictionary) -> void:
	var peer_id = int(data.get("peer_id", 0))
	if peer_id == 0:
		return

	if connected_players.has(peer_id):
		connected_players.erase(peer_id)
		peer_left_lobby.emit(peer_id)
		lobby_updated.emit()

		# If in game, remove their combatant
		if GameManager.is_game_active:
			for combatant in GameManager.alive_combatants:
				if is_instance_valid(combatant) and "peer_id" in combatant and combatant.peer_id == peer_id:
					GameManager.on_combatant_died(combatant, null, "Disconnected")
					if not combatant.is_queued_for_deletion():
						combatant.queue_free()
					break

	# If host left, everyone goes back to menu
	if peer_id == 1:
		connection_failed.emit("Host disconnected.")
		reset_network()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_relay_player_info(data: Dictionary) -> void:
	# Only host processes player_info
	if not is_host:
		return

	var peer_id = int(data.get("peer_id", 0))
	var p_name = data.get("name", "Player")
	var p_color = Color(
		float(data.get("color_r", 0.5)),
		float(data.get("color_g", 0.5)),
		float(data.get("color_b", 0.5))
	)

	connected_players[peer_id] = {
		"id": peer_id,
		"name": p_name,
		"color": p_color,
		"ready": true
	}

	# Broadcast updated lobby to all peers
	_broadcast_lobby_sync()


func _on_relay_lobby_sync(data: Dictionary) -> void:
	# Clients receive the full player list from host
	var players_data = data.get("players", {})
	connected_players.clear()
	for key in players_data.keys():
		var pid = int(key)
		var p_info = players_data[key]
		connected_players[pid] = {
			"id": pid,
			"name": p_info.get("name", "Player"),
			"color": Color(
				float(p_info.get("color_r", 0.5)),
				float(p_info.get("color_g", 0.5)),
				float(p_info.get("color_b", 0.5))
			),
			"ready": p_info.get("ready", true)
		}

	manual_bot_count = int(data.get("bot_count", 0))
	lobby_updated.emit()


func _on_relay_start_match(data: Dictionary) -> void:
	var bots_to_spawn = int(data.get("bot_count", 0))
	manual_bot_count = bots_to_spawn
	GameManager.start_match(bots_to_spawn, 22, 22)
	match_start_requested.emit()
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _on_relay_rpc(data: Dictionary) -> void:
	# Generic RPC relay — used for game-time state sync
	var method = data.get("method", "")
	var args = data.get("args", [])
	var target_node = data.get("node_path", "")

	if method == "" or target_node == "":
		return

	var node = get_tree().root.get_node_or_null(target_node)
	if node == null:
		return

	if node.has_method(method):
		node.callv(method, args)


func _broadcast_lobby_sync() -> void:
	# Host serializes connected_players and broadcasts
	var players_data = {}
	for pid in connected_players.keys():
		var p_info = connected_players[pid]
		var color = p_info.get("color", Color.CYAN)
		players_data[str(pid)] = {
			"name": p_info.get("name", "Player"),
			"color_r": color.r,
			"color_g": color.g,
			"color_b": color.b,
			"ready": p_info.get("ready", true)
		}

	_send_relay_json({
		"type": "lobby_sync",
		"players": players_data,
		"bot_count": manual_bot_count
	})

	lobby_updated.emit()


# ─── ENet MULTIPLAYER CALLBACKS (for LAN mode) ───

func _on_peer_connected(id: int) -> void:
	if is_host and not is_relay_mode:
		rpc_id(id, "_client_receive_lobby_sync", connected_players, manual_bot_count)


func _on_peer_disconnected(id: int) -> void:
	if is_relay_mode:
		return  # Handled by relay_peer_left
	if connected_players.has(id):
		connected_players.erase(id)
		peer_left_lobby.emit(id)
		lobby_updated.emit()

		if GameManager.is_game_active:
			for combatant in GameManager.alive_combatants:
				if is_instance_valid(combatant) and "peer_id" in combatant and combatant.peer_id == id:
					GameManager.on_combatant_died(combatant, null, "Disconnected")
					if not combatant.is_queued_for_deletion():
						combatant.queue_free()
					break


func _on_connected_to_server() -> void:
	if is_relay_mode:
		return  # Handled by relay init
	connection_succeeded.emit()
	var p_color = Color.from_hsv(randf(), 0.85, 0.95)
	var my_id = multiplayer.get_unique_id()
	rpc_id(1, "_server_register_peer_info", my_id, local_player_name, p_color)


func _on_connection_failed() -> void:
	if is_relay_mode:
		return
	reset_network()
	connection_failed.emit("Failed to connect to host room.")


func _on_server_disconnected() -> void:
	if is_relay_mode:
		return
	reset_network()
	connection_failed.emit("Host disconnected.")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


@rpc("any_peer", "call_local", "reliable")
func _server_register_peer_info(peer_id: int, p_name: String, p_color: Color) -> void:
	if not is_host:
		return

	connected_players[peer_id] = {
		"id": peer_id,
		"name": p_name,
		"color": p_color,
		"ready": true
	}

	rpc("_client_receive_lobby_sync", connected_players, manual_bot_count)


@rpc("authority", "call_local", "reliable")
func _client_receive_lobby_sync(synced_players: Dictionary, p_bots_count: int) -> void:
	connected_players = synced_players
	manual_bot_count = p_bots_count
	lobby_updated.emit()


func _generate_random_code() -> String:
	var code = ""
	for i in range(6):
		var idx = randi() % CODE_CHARS.length()
		code += CODE_CHARS[idx]
	return code
