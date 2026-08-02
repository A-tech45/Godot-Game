extends Control

@onready var bot_option_btn: OptionButton = %BotOptionButton
@onready var grid_option_btn: OptionButton = %GridOptionButton
@onready var start_button: Button = %StartButton
@onready var multiplayer_button: Button = %MultiplayerButton
@onready var guide_button: Button = %GuideButton
@onready var quit_button: Button = %QuitButton
@onready var guide_panel: PanelContainer = %GuidePanel
@onready var close_guide_button: Button = %CloseGuideButton

func _ready() -> void:
	guide_panel.hide()
	
	# Populate Bot Count Options
	bot_option_btn.clear()
	bot_option_btn.add_item("8 Combatants (1 Player + 7 Bots)", 0)
	bot_option_btn.add_item("12 Combatants (1 Player + 11 Bots)", 1)
	bot_option_btn.add_item("16 Combatants (1 Player + 15 Bots)", 2)
	bot_option_btn.add_item("20 Chaos Combatants (1 Player + 19 Bots)", 3)
	bot_option_btn.select(2) # Default 16
	
	# Populate Compound Size Options
	grid_option_btn.clear()
	grid_option_btn.add_item("Standard Ruined Compound", 0)
	grid_option_btn.add_item("Large Fortified Compound", 1)
	grid_option_btn.select(0)
	
	_apply_pro_styling()
	
	start_button.pressed.connect(_on_start_pressed)
	if multiplayer_button:
		multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	guide_button.pressed.connect(_on_guide_pressed)
	close_guide_button.pressed.connect(_on_close_guide_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _apply_pro_styling() -> void:
	# Style buttons with glowing dark glassmorphism
	_style_button(start_button, Color(0.08, 0.12, 0.22, 0.95), Color(0.12, 0.4, 0.55, 0.95), Color(0.0, 0.94, 1.0))
	if multiplayer_button:
		_style_button(multiplayer_button, Color(0.05, 0.22, 0.2, 0.95), Color(0.0, 0.5, 0.45, 0.95), Color(0.0, 0.96, 0.83))
	_style_button(guide_button, Color(0.12, 0.14, 0.2, 0.85), Color(0.2, 0.24, 0.35, 0.95), Color(0.4, 0.6, 1.0))
	_style_button(quit_button, Color(0.2, 0.08, 0.1, 0.85), Color(0.45, 0.12, 0.18, 0.95), Color(1.0, 0.2, 0.35))
	_style_button(close_guide_button, Color(0.12, 0.14, 0.2, 0.95), Color(0.2, 0.24, 0.35, 0.95), Color(0.0, 0.94, 1.0))
	
	# Style guide panel card
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	panel_style.border_color = Color(0.0, 0.94, 1.0, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0.0, 0.8, 1.0, 0.15)
	panel_style.shadow_size = 20
	guide_panel.add_theme_stylebox_override("panel", panel_style)


func _style_button(btn: Button, bg: Color, hover_bg: Color, accent: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.4)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = hover_bg
	hover.border_color = accent
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(10)
	hover.set_content_margin_all(10)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.3)
	hover.shadow_size = 8
	
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(accent.r * 0.4, accent.g * 0.4, accent.b * 0.4, 0.95)
	pressed.border_color = accent
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(10)
	pressed.set_content_margin_all(10)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)

func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_start_pressed() -> void:
	var bots_count := 15
	match bot_option_btn.selected:
		0: bots_count = 7
		1: bots_count = 11
		2: bots_count = 15
		3: bots_count = 19
		
	GameManager.start_match(bots_count, 22, 22)
	get_tree().change_scene_to_file("res://scenes/arena.tscn")

func _on_guide_pressed() -> void:
	guide_panel.show()

func _on_close_guide_pressed() -> void:
	guide_panel.hide()

func _on_quit_pressed() -> void:
	get_tree().quit()
