extends CanvasLayer

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_text: Label = %HealthText
@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var dash_bar: ProgressBar = %DashBar
@onready var kills_label: Label = %KillsLabel
@onready var alive_label: Label = %AliveLabel
@onready var kill_feed_box: VBoxContainer = %KillFeedBox

@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var game_over_title: Label = %GameOverTitle
@onready var game_over_stats: Label = %GameOverStats
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton
@onready var exit_match_button: Button = %ExitMatchButton

var connected_player: Node2D = null

func _ready() -> void:
	game_over_panel.hide()
	_apply_pro_styling()
	
	GameManager.kill_feed_event.connect(_on_kill_feed_event)
	GameManager.player_count_changed.connect(_on_player_count_changed)
	GameManager.game_over.connect(_on_game_over)
	
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	if exit_match_button:
		exit_match_button.pressed.connect(_on_exit_match_pressed)


func _apply_pro_styling() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	panel_style.border_color = Color(0.0, 0.94, 1.0, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0.0, 0.8, 1.0, 0.2)
	panel_style.shadow_size = 25
	game_over_panel.add_theme_stylebox_override("panel", panel_style)
	
	_style_hud_btn(restart_button, Color(0.05, 0.22, 0.12, 0.95), Color(0.1, 0.55, 0.25, 0.95), Color(0.2, 1.0, 0.4))
	_style_hud_btn(menu_button, Color(0.12, 0.14, 0.2, 0.85), Color(0.2, 0.24, 0.35, 0.95), Color(0.4, 0.6, 1.0))
	if exit_match_button:
		_style_hud_btn(exit_match_button, Color(0.25, 0.08, 0.1, 0.85), Color(0.5, 0.12, 0.18, 0.95), Color(1.0, 0.25, 0.35))


func _on_exit_match_pressed() -> void:
	if NetworkManager.is_online:
		NetworkManager.reset_network()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _style_hud_btn(btn: Button, bg: Color, hover_bg: Color, accent: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.4)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(8)
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = hover_bg
	hover.border_color = accent
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(10)
	hover.set_content_margin_all(8)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.3)
	hover.shadow_size = 8
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)

func _unhandled_input(event: InputEvent) -> void:
	# Quick key restart when dead/game over screen is visible
	if game_over_panel.visible:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_R or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				_on_restart_pressed()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_restart_pressed()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	# Ensure player signals are connected as soon as player node exists
	if GameManager.player_node != null and is_instance_valid(GameManager.player_node):
		if connected_player != GameManager.player_node:
			_connect_player(GameManager.player_node)
			
		var p = GameManager.player_node
		kills_label.text = "KILLS: " + str(GameManager.player_kills)
		
		# Update current weapon info & stealth state
		if p.weapons.size() > p.current_weapon_idx:
			var w: Weapon = p.weapons[p.current_weapon_idx]
			var stealth_str = "  |  STEALTH [HIDDEN IN RUINS]" if p.is_hidden else ""
			weapon_name_label.text = w.weapon_name.to_upper() + " [KEY " + str(p.current_weapon_idx + 1) + "]" + stealth_str
			weapon_name_label.modulate = Color(0.2, 1.0, 0.5) if p.is_hidden else Color(0.3, 0.9, 1.0)
			ammo_label.text = "READY"

func _connect_player(player: Node2D) -> void:
	connected_player = player
	if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	if player.has_signal("dash_cooldown_updated") and not player.dash_cooldown_updated.is_connected(_on_dash_cooldown_updated):
		player.dash_cooldown_updated.connect(_on_dash_cooldown_updated)
	if player.has_signal("weapon_changed") and not player.weapon_changed.is_connected(_on_weapon_changed):
		player.weapon_changed.connect(_on_weapon_changed)

func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current
	health_text.text = str(int(max(0, current))) + " / " + str(int(max_hp))
	
	# Instant UI Failsafe: When health reaches <= 0.0, show Play Again screen!
	if current <= 0.0 and not game_over_panel.visible:
		_on_game_over("Enemy", false)

func _on_dash_cooldown_updated(current: float, max_cd: float) -> void:
	dash_bar.max_value = max_cd
	dash_bar.value = max_cd - current

func _on_weapon_changed(weapon: Weapon) -> void:
	weapon_name_label.text = weapon.weapon_name.to_upper()

func _on_player_count_changed(alive: int, total: int) -> void:
	alive_label.text = "ALIVE: " + str(alive) + " / " + str(total)

func _on_kill_feed_event(killer: String, victim: String, _cause: String) -> void:
	var item = Label.new()
	item.text = killer + "  -->  " + victim
	item.modulate = Color(1.0, 0.9, 0.3)
		
	item.add_theme_font_size_override("font_size", 14)
	kill_feed_box.add_child(item)
	
	# Limit feed length
	if kill_feed_box.get_child_count() > 5:
		kill_feed_box.get_child(0).queue_free()
		
	# Fade out after 4 seconds
	var tween = create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(item, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(item.queue_free)

func _on_game_over(winner_name: String, is_player_winner: bool) -> void:
	game_over_panel.show()
	
	if NetworkManager.is_online and not NetworkManager.is_host:
		restart_button.text = "WAITING FOR HOST..."
		restart_button.disabled = true
	else:
		restart_button.text = "PLAY AGAIN [R / Space / Click]"
		restart_button.disabled = false
		restart_button.grab_focus()
	
	if is_player_winner:
		game_over_title.text = "VICTORY ROYALE!"
		game_over_title.modulate = Color(0.2, 1.0, 0.4)
		game_over_stats.text = "YOU ARE THE LAST SURVIVOR!\nYour Kills: " + str(GameManager.player_kills)
		SoundManager.play_victory()
	else:
		game_over_title.text = "GAME OVER!"
		game_over_title.modulate = Color(1.0, 0.25, 0.2)
		game_over_stats.text = "Winner: " + winner_name + "\nYour Kills: " + str(GameManager.player_kills)
		SoundManager.play_defeat()

func _on_restart_pressed() -> void:
	if NetworkManager.is_online:
		if NetworkManager.is_host:
			NetworkManager.start_multiplayer_match()
	else:
		GameManager.restart_match()

func _on_menu_pressed() -> void:
	if NetworkManager.is_online:
		NetworkManager.reset_network()
	GameManager.go_to_main_menu()
