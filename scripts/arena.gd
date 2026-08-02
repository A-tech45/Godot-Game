extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var house_map: Node2D = $HouseMap
@onready var entities: Node2D = $Entities
@onready var touch_controls: Node = $TouchControls

var shake_intensity: float = 0.0
var shake_duration: float = 0.0

func _ready() -> void:
	GameManager.camera_shake_requested.connect(_on_camera_shake_requested)
	
	# Spawn match combatants inside ruined houses
	_spawn_match()

func _physics_process(delta: float) -> void:
	# Smoothly track player position with camera
	if GameManager.player_node != null and is_instance_valid(GameManager.player_node):
		var target_pos = GameManager.player_node.global_position
		camera.global_position = camera.global_position.lerp(target_pos, delta * 10.0)
		
	# Apply camera shake
	if shake_duration > 0.0:
		shake_duration -= delta
		camera.offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		if shake_duration <= 0.0:
			camera.offset = Vector2.ZERO

func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration

func _spawn_match() -> void:
	# Clear old entities
	for child in entities.get_children():
		child.queue_free()
		
	var player_scene = load("res://scenes/player.tscn")
	var bot_scene = load("res://scenes/bot.tscn")
	var first_spawn_pos = Vector2.ZERO
	
	if NetworkManager.is_online:
		# Spawn human players for each connected peer with deterministic node names
		for pid in NetworkManager.connected_players:
			var p_info = NetworkManager.connected_players[pid]
			var p_node = player_scene.instantiate()
			p_node.name = "Player_" + str(pid)
			p_node.peer_id = pid
			p_node.display_name = p_info.get("name", "Player")
			
			var spawn_pos = house_map.get_random_spawn_pos() if house_map.has_method("get_random_spawn_pos") else Vector2(randf_range(-500, 500), randf_range(-500, 500))
			p_node.global_position = spawn_pos
			entities.add_child(p_node)
			
			if pid == NetworkManager.get_my_id():
				p_node.touch_controls = touch_controls
				first_spawn_pos = spawn_pos
				camera.global_position = spawn_pos
	else:
		# Single-player mode
		var player = player_scene.instantiate()
		player.name = "Player_1"
		var p_spawn = house_map.get_random_spawn_pos() if house_map.has_method("get_random_spawn_pos") else Vector2.ZERO
		player.display_name = NetworkManager.local_player_name if NetworkManager.local_player_name != "" else "You (P1)"
		player.global_position = p_spawn
		player.touch_controls = touch_controls
		entities.add_child(player)
		
		first_spawn_pos = p_spawn
		camera.global_position = p_spawn
		
	# Spawn Bots around ruined house compound
	if not NetworkManager.is_online or NetworkManager.is_host:
		var num_bots = GameManager.selected_bot_count
		var bot_names_list = ["Nexus", "Viper", "Spectre", "Raptor", "Ghost", "Apex", "Titan", "Cipher", "Shadow", "Blaze", "Fury", "Havoc"]
		var bots_data: Array = []

		for i in range(num_bots):
			var bot = bot_scene.instantiate()
			bot.name = "Bot_" + str(i)
			var spawn_pos = house_map.get_random_spawn_pos() if house_map.has_method("get_random_spawn_pos") else Vector2(randf_range(-600, 600), randf_range(-600, 600))
			
			while spawn_pos.distance_to(first_spawn_pos) < 260.0:
				spawn_pos = house_map.get_random_spawn_pos() if house_map.has_method("get_random_spawn_pos") else Vector2(randf_range(-600, 600), randf_range(-600, 600))
				
			bot.global_position = spawn_pos
			var name_idx = i % bot_names_list.size()
			var b_name = bot_names_list[name_idx] + "_" + str(randi_range(10, 99))
			var b_hue = randf()
			var b_weapon_idx = randi() % 4
			
			if bot.has_method("setup_bot"):
				bot.setup_bot(b_name, b_hue, b_weapon_idx)
				
			entities.add_child(bot)
			
			bots_data.append({
				"index": i,
				"name": b_name,
				"hue": b_hue,
				"weapon_idx": b_weapon_idx,
				"spawn_pos": spawn_pos
			})
			
		if NetworkManager.is_online and NetworkManager.is_host:
			if NetworkManager.is_relay_mode:
				# Serialize bot spawn data for relay (convert Vector2 to arrays)
				var relay_bots_data = []
				for b_info in bots_data:
					relay_bots_data.append({
						"index": b_info["index"],
						"name": b_info["name"],
						"hue": b_info["hue"],
						"weapon_idx": b_info["weapon_idx"],
						"spawn_pos": NetworkManager.vec2_to_array(b_info["spawn_pos"])
					})
				var node_path = str(get_path())
				NetworkManager.send_relay_rpc(node_path, "_relay_sync_bots_spawn", [relay_bots_data])
			else:
				rpc("_client_sync_bots_spawn", bots_data)


## Called via relay to spawn bots on clients
func _relay_sync_bots_spawn(bots_data: Array) -> void:
	var bot_scene = load("res://scenes/bot.tscn")
	for b_info in bots_data:
		var idx = int(b_info.get("index", 0))
		var bot_name_node = "Bot_" + str(idx)
		if entities.has_node(bot_name_node):
			continue
			
		var bot = bot_scene.instantiate()
		bot.name = bot_name_node
		var spawn_arr = b_info.get("spawn_pos", [0.0, 0.0])
		bot.global_position = NetworkManager.array_to_vec2(spawn_arr)
		
		if bot.has_method("setup_bot"):
			bot.setup_bot(b_info.get("name", "Bot"), float(b_info.get("hue", 0.5)), int(b_info.get("weapon_idx", 0)))
			
		entities.add_child(bot)


@rpc("authority", "call_remote", "reliable")
func _client_sync_bots_spawn(bots_data: Array) -> void:
	var bot_scene = load("res://scenes/bot.tscn")
	for b_info in bots_data:
		var idx = int(b_info.get("index", 0))
		var bot_name_node = "Bot_" + str(idx)
		if entities.has_node(bot_name_node):
			continue
			
		var bot = bot_scene.instantiate()
		bot.name = bot_name_node
		bot.global_position = b_info.get("spawn_pos", Vector2.ZERO)
		
		if bot.has_method("setup_bot"):
			bot.setup_bot(b_info.get("name", "Bot"), float(b_info.get("hue", 0.5)), int(b_info.get("weapon_idx", 0)))
			
		entities.add_child(bot)

