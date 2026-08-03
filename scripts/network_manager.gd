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
var connection_timeout_timer: float = 0.0
const CONNECTION_TIMEOUT: float = 45.0

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
	if not is_online or not is_relay_mode or relay_socket == null:
		return

	relay_socket.poll()
	var state = relay_socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not relay_connected:
			relay_connected = true
			connection_timeout_timer = 0.0

		while relay_socket.get_available_packet_count() > 0:
			_handle_relay_message(relay_socket.get_packet())

	elif state == WebSocketPeer.STATE_CONNECTING:
		connection_timeout_timer += delta
		if connection_timeout_timer >= CONNECTION_TIMEOUT:
			connection_failed.emit("Connection to relay server timed out.")
			reset_network()

	elif state == WebSocketPeer.STATE_CLOSED:
		if relay_connected:
			relay_connected = false
			if is_online:
				connection_failed.emit("Lost connection to relay server.")
				reset_network()
				get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		else:
			if _retry_count < MAX_RETRIES:
				_retry_count += 1
				connection_status_changed.emit("Server waking up... (attempt %d/%d)" % [_retry_count + 1, MAX_RETRIES + 1])
				_reconnect_relay()
			else:
				var reason = relay_socket.get_close_reason()
				if reason == "":
					reason = "Could not reach relay server after %d attempts" % (MAX_RETRIES + 1)
				connection_failed.emit(reason)
				reset_network()


func get_my_id() -> int:
	if is_relay_mode:
		return my_relay_id
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func host_room(p_name: String, p_is_private: bool, p_bot_count: int = 0) -> bool:
	reset_network()
	local_player_name = p_name if p_name.strip_edges() != "" else "Host_Player"
	is_private_room = p_is_private
	manual_bot_count = p_bot_count
	is_host = true
	room_code = _generate_random_code()
	return _start_relay_connection(room_code, true)


func join_room_by_code(code: String, p_name: String) -> void:
	reset_network()
	local_player_name = p_name if p_name.strip_edges() != "" else "Player_" + str(randi_range(100, 999))
	var clean_code = code.strip_edges().to_upper()

	if clean_code.is_valid_ip_address() or (":" in clean_code and not clean_code.begins_with("[")):
		_join_enet_lan(clean_code)
		return

	room_code = clean_code
	is_host = false
	_start_relay_connection(room_code, false)


func _start_relay_connection(p_code: String, p_is_hosting: bool) -> bool:
	is_online = true
	is_relay_mode = true
	_pending_room_code = p_code
	_pending_is_hosting = p_is_hosting
	_retry_count = 0

	relay_socket = WebSocketPeer.new()
	var err = relay_socket.connect_to_url(RELAY_URL + "/room/" + p_code)
	if err != OK:
		connection_failed.emit("Failed to connect to relay server.")
		reset_network()
		return false

	connection_timeout_timer = 0.0
	connection_status_changed.emit("Connecting to relay server...")
	return true


func _reconnect_relay() -> void:
	if _pending_room_code == "": return
	if relay_socket != null: relay_socket.close()

	room_code = _pending_room_code
	is_online = true
	is_relay_mode = true
	is_host = _pending_is_hosting
	relay_connected = false

	relay_socket = WebSocketPeer.new()
	if relay_socket.connect_to_url(RELAY_URL + "/room/" + room_code) != OK:
		connection_failed.emit("Failed to reconnect to relay server.")
		reset_network()
		return
	connection_timeout_timer = 0.0


func _join_enet_lan(ip_str: String) -> void:
	is_online = true
	is_host = false
	is_relay_mode = false

	var parts = ip_str.split(":")
	var host_ip = parts[0]
	var port = parts[1].to_int() if parts.size() > 1 and parts[1].is_valid_int() else DEFAULT_PORT

	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(host_ip, port) != OK:
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
		if old_peer: old_peer.close()


func start_multiplayer_match() -> void:
	if not is_host or not is_online: return
	if is_relay_mode:
		_send_relay_json({ "type": "start_match", "bot_count": manual_bot_count })
		_start_local_match(manual_bot_count)
	else:
		rpc("_client_receive_start_match")


func _start_local_match(bot_count: int) -> void:
	GameManager.start_match(bot_count, 22, 22)
	match_start_requested.emit()
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


@rpc("call_local", "reliable")
func _client_receive_start_match() -> void:
	_start_local_match(manual_bot_count)


# ─── RELAY HELPERS ───

func _send_relay_json(data: Dictionary) -> void:
	if relay_socket != null and relay_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		relay_socket.send_text(JSON.stringify(data))


func send_relay_rpc(node_path: String, method: String, args: Array) -> void:
	_send_relay_json({ "type": "rpc_relay", "sender_id": my_relay_id, "node_path": node_path, "method": method, "args": args })


func vec2_to_array(v: Vector2) -> Array:
	return [v.x, v.y]

func array_to_vec2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a.size() >= 2 else Vector2.ZERO


# ─── RELAY MESSAGE DISPATCH ───

func _handle_relay_message(data: PackedByteArray) -> void:
	var json = JSON.parse_string(data.get_string_from_utf8())
	if json == null or not (json is Dictionary): return

	match json.get("type", ""):
		"init": _on_relay_init(json)
		"peer_left": _on_relay_peer_left(json)
		"player_info": _on_relay_player_info(json)
		"lobby_sync": _on_relay_lobby_sync(json)
		"start_match": _start_local_match(int(json.get("bot_count", 0)))
		"rpc_relay": _on_relay_rpc(json)


func _on_relay_init(data: Dictionary) -> void:
	my_relay_id = int(data.get("your_id", 0))
	is_host = data.get("is_host", false)

	if is_host:
		connected_players[1] = { "id": 1, "name": local_player_name, "color": Color.from_hsv(randf(), 0.8, 0.95), "ready": true }
		lobby_updated.emit()
	else:
		var p_color = Color.from_hsv(randf(), 0.85, 0.95)
		_send_relay_json({ "type": "player_info", "peer_id": my_relay_id, "name": local_player_name, "color_r": p_color.r, "color_g": p_color.g, "color_b": p_color.b })
	connection_succeeded.emit()


func _on_relay_peer_left(data: Dictionary) -> void:
	var peer_id = int(data.get("peer_id", 0))
	if peer_id == 0: return

	if connected_players.has(peer_id):
		connected_players.erase(peer_id)
		peer_left_lobby.emit(peer_id)
		lobby_updated.emit()

		if GameManager.is_game_active:
			for combatant in GameManager.alive_combatants:
				if is_instance_valid(combatant) and "peer_id" in combatant and combatant.peer_id == peer_id:
					GameManager.on_combatant_died(combatant, null, "Disconnected")
					if not combatant.is_queued_for_deletion(): combatant.queue_free()
					break

	if peer_id == 1:
		connection_failed.emit("Host disconnected.")
		reset_network()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_relay_player_info(data: Dictionary) -> void:
	if not is_host: return
	var peer_id = int(data.get("peer_id", 0))
	connected_players[peer_id] = {
		"id": peer_id,
		"name": data.get("name", "Player"),
		"color": Color(float(data.get("color_r", 0.5)), float(data.get("color_g", 0.5)), float(data.get("color_b", 0.5))),
		"ready": true
	}
	_broadcast_lobby_sync()


func _on_relay_lobby_sync(data: Dictionary) -> void:
	var players_data = data.get("players", {})
	connected_players.clear()
	for key in players_data.keys():
		var pid = int(key)
		var p_info = players_data[key]
		connected_players[pid] = {
			"id": pid,
			"name": p_info.get("name", "Player"),
			"color": Color(float(p_info.get("color_r", 0.5)), float(p_info.get("color_g", 0.5)), float(p_info.get("color_b", 0.5))),
			"ready": p_info.get("ready", true)
		}
	manual_bot_count = int(data.get("bot_count", 0))
	lobby_updated.emit()


func _on_relay_rpc(data: Dictionary) -> void:
	var method = data.get("method", "")
	var target_node = data.get("node_path", "")
	if method == "" or target_node == "": return

	var node = get_tree().root.get_node_or_null(target_node)
	if node != null and node.has_method(method):
		node.callv(method, data.get("args", []))


func _broadcast_lobby_sync() -> void:
	var players_data = {}
	for pid in connected_players.keys():
		var p_info = connected_players[pid]
		var color = p_info.get("color", Color.CYAN)
		players_data[str(pid)] = {
			"name": p_info.get("name", "Player"),
			"color_r": color.r, "color_g": color.g, "color_b": color.b,
			"ready": p_info.get("ready", true)
		}
	_send_relay_json({ "type": "lobby_sync", "players": players_data, "bot_count": manual_bot_count })
	lobby_updated.emit()


# ─── ENet MULTIPLAYER CALLBACKS (LAN Mode) ───

func _on_peer_connected(id: int) -> void:
	if is_host and not is_relay_mode:
		rpc_id(id, "_client_receive_lobby_sync", connected_players, manual_bot_count)


func _on_peer_disconnected(id: int) -> void:
	if is_relay_mode: return
	if connected_players.has(id):
		connected_players.erase(id)
		peer_left_lobby.emit(id)
		lobby_updated.emit()


func _on_connected_to_server() -> void:
	if is_relay_mode: return
	connection_succeeded.emit()
	rpc_id(1, "_server_register_peer_info", multiplayer.get_unique_id(), local_player_name, Color.from_hsv(randf(), 0.85, 0.95))


func _on_connection_failed() -> void:
	if is_relay_mode: return
	reset_network()
	connection_failed.emit("Failed to connect to host room.")


func _on_server_disconnected() -> void:
	if is_relay_mode: return
	reset_network()
	connection_failed.emit("Host disconnected.")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


@rpc("any_peer", "call_local", "reliable")
func _server_register_peer_info(peer_id: int, p_name: String, p_color: Color) -> void:
	if not is_host: return
	connected_players[peer_id] = { "id": peer_id, "name": p_name, "color": p_color, "ready": true }
	rpc("_client_receive_lobby_sync", connected_players, manual_bot_count)


@rpc("authority", "call_local", "reliable")
func _client_receive_lobby_sync(synced_players: Dictionary, p_bots_count: int) -> void:
	connected_players = synced_players
	manual_bot_count = p_bots_count
	lobby_updated.emit()


func _generate_random_code() -> String:
	var code = ""
	for i in range(6):
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	return code
