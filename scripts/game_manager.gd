extends Node

signal kill_feed_event(killer_name: String, victim_name: String, cause: String)
signal player_count_changed(alive_count: int, total_count: int)
signal game_over(winner_name: String, is_player: bool)
signal camera_shake_requested(intensity: float, duration: float)

# Game settings
var selected_bot_count: int = 11  # Default total 12 players (1 Human + 11 Bots)
var grid_width: int = 22
var grid_height: int = 22
var tile_size: float = 64.0

# Game state
var is_game_active: bool = false
var is_match_initialized: bool = false
var is_player_dead: bool = false
var player_node: Node2D = null
var current_tile_grid: Node2D = null

var alive_combatants: Array[Node2D] = []
var total_combatants_start: int = 0
var player_kills: int = 0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if is_game_active and is_match_initialized and not is_player_dead:
		var current_alive = get_alive_combatants_count()
		player_count_changed.emit(current_alive, total_combatants_start)
		check_match_over()

func start_match(bots_count: int = 11, width: int = 22, height: int = 22) -> void:
	selected_bot_count = bots_count
	grid_width = width
	grid_height = height
	player_kills = 0
	is_game_active = true
	is_match_initialized = false
	is_player_dead = false
	alive_combatants.clear()
	var num_humans = NetworkManager.connected_players.size() if NetworkManager.is_online else 1
	total_combatants_start = bots_count + num_humans

func register_combatant(combatant: Node2D) -> void:
	if not alive_combatants.has(combatant):
		alive_combatants.append(combatant)
		var current_alive = get_alive_combatants_count()
		player_count_changed.emit(current_alive, total_combatants_start)
		
		# Mark initialized once all registered
		if alive_combatants.size() >= total_combatants_start:
			is_match_initialized = true

func get_alive_combatants_count() -> int:
	var valid: Array[Node2D] = []
	for c in alive_combatants:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			if "is_dead" in c and c.is_dead:
				continue
			valid.append(c)
	alive_combatants = valid
	return alive_combatants.size()

func trigger_player_death(killer_name: String = "Enemy") -> void:
	if is_player_dead:
		return
	is_player_dead = true
	is_game_active = false
	game_over.emit(killer_name, false)

func on_combatant_died(victim: Node2D, killer: Node2D = null, cause: String = "Shot") -> void:
	var victim_name: String = "Combatant"
	if is_instance_valid(victim) and "display_name" in victim:
		victim_name = victim.display_name
		
	var killer_name: String = "Void"
	if killer != null and is_instance_valid(killer):
		killer_name = killer.display_name if "display_name" in killer else "Combatant"
		if killer == player_node:
			player_kills += 1
	
	if alive_combatants.has(victim):
		alive_combatants.erase(victim)
		
	var current_alive = get_alive_combatants_count()
	
	if NetworkManager.is_online and NetworkManager.is_host:
		if NetworkManager.is_relay_mode:
			var node_path = str(get_path())
			NetworkManager.send_relay_rpc(node_path, "_relay_kill_feed", [killer_name, victim_name, cause, current_alive])
			# Also apply locally for the host
			kill_feed_event.emit(killer_name, victim_name, cause)
			player_count_changed.emit(current_alive, total_combatants_start)
		else:
			rpc("_sync_kill_feed", killer_name, victim_name, cause, current_alive)
	else:
		kill_feed_event.emit(killer_name, victim_name, cause)
		player_count_changed.emit(current_alive, total_combatants_start)
	
	# Failsafe: Check if victim is local player
	var is_victim_player = (victim == player_node)
	if is_victim_player:
		trigger_player_death(killer_name)
		return
	
	# Host checks win condition
	if not NetworkManager.is_online or NetworkManager.is_host:
		check_match_over()


## Called via relay for kill feed
func _relay_kill_feed(p_killer_name: String, p_victim_name: String, p_cause: String, p_current_alive: int) -> void:
	_sync_kill_feed(p_killer_name, p_victim_name, p_cause, p_current_alive)


@rpc("authority", "call_local", "reliable")
func _sync_kill_feed(killer_name: String, victim_name: String, cause: String, current_alive: int) -> void:
	kill_feed_event.emit(killer_name, victim_name, cause)
	player_count_changed.emit(current_alive, total_combatants_start)


func check_match_over() -> void:
	if not is_game_active or not is_match_initialized:
		return
		
	var current_alive = get_alive_combatants_count()
	
	if current_alive <= 1:
		is_game_active = false
		var winner_name: String = "Nobody"
		var is_player_win: bool = false
		
		if current_alive == 1:
			var winner = alive_combatants[0]
			if is_instance_valid(winner):
				winner_name = winner.display_name if "display_name" in winner else "Winner"
				is_player_win = (winner == player_node)
		
		if NetworkManager.is_online and NetworkManager.is_host:
			if NetworkManager.is_relay_mode:
				var node_path = str(get_path())
				NetworkManager.send_relay_rpc(node_path, "_relay_game_over", [winner_name])
				# Also emit locally for host
				game_over.emit(winner_name, is_player_win)
			else:
				rpc("_sync_game_over_event", winner_name)
		else:
			game_over.emit(winner_name, is_player_win)


## Called via relay for game over
func _relay_game_over(p_winner_name: String) -> void:
	_sync_game_over_event(p_winner_name)


@rpc("authority", "call_local", "reliable")
func _sync_game_over_event(winner_name: String) -> void:
	var is_my_win = (player_node != null and is_instance_valid(player_node) and player_node.display_name == winner_name)
	game_over.emit(winner_name, is_my_win)

func request_camera_shake(intensity: float = 8.0, duration: float = 0.3) -> void:
	camera_shake_requested.emit(intensity, duration)

func restart_match() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
