extends CanvasLayer

## Touch controls overlay — provides dual joysticks, weapon switch, and dash buttons.
## Auto-hides on non-touch devices. The player script reads our exposed properties.

# Exposed state for player.gd to read each frame
var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.ZERO
var is_firing: bool = false
var dash_just_pressed: bool = false
var weapon_switch_just_pressed: bool = false

@onready var left_joystick: TouchJoystick = %LeftJoystick
@onready var right_joystick: TouchJoystick = %RightJoystick
@onready var dash_button: Button = %DashButton
@onready var weapon_switch_button: Button = %WeaponSwitchButton
@onready var controls_container: Control = %ControlsContainer


func _ready() -> void:
	layer = 11  # Above HUD
	
	# Auto-detect touch capability
	var is_touch: bool = DisplayServer.is_touchscreen_available()
	controls_container.visible = is_touch
	
	# Connect joystick signals
	left_joystick.joystick_changed.connect(_on_left_joystick_changed)
	left_joystick.joystick_released.connect(_on_left_joystick_released)
	right_joystick.joystick_changed.connect(_on_right_joystick_changed)
	right_joystick.joystick_released.connect(_on_right_joystick_released)
	
	# Connect button signals
	dash_button.pressed.connect(_on_dash_pressed)
	weapon_switch_button.pressed.connect(_on_weapon_switch_pressed)
	
	# Style buttons for touch-friendly appearance
	_style_touch_button(dash_button, Color(0.1, 0.3, 0.4, 0.6), Color(0.15, 0.5, 0.6, 0.8))
	_style_touch_button(weapon_switch_button, Color(0.35, 0.25, 0.05, 0.6), Color(0.5, 0.4, 0.1, 0.8))


func _physics_process(_delta: float) -> void:
	# Reset one-shot flags at end of physics frame.
	# By the time _physics_process runs here, the player's _physics_process
	# has already read the flags (since TouchControls is a sibling added after Player).
	# We use call_deferred to clear after all physics processing is done.
	if dash_just_pressed:
		call_deferred("_clear_dash_flag")
	if weapon_switch_just_pressed:
		call_deferred("_clear_weapon_flag")


func _clear_dash_flag() -> void:
	dash_just_pressed = false


func _clear_weapon_flag() -> void:
	weapon_switch_just_pressed = false


func _on_left_joystick_changed(vec: Vector2) -> void:
	move_vector = vec


func _on_left_joystick_released() -> void:
	move_vector = Vector2.ZERO


func _on_right_joystick_changed(vec: Vector2) -> void:
	aim_vector = vec
	is_firing = vec.length() > 0.2


func _on_right_joystick_released() -> void:
	aim_vector = Vector2.ZERO
	is_firing = false


func _on_dash_pressed() -> void:
	dash_just_pressed = true


func _on_weapon_switch_pressed() -> void:
	weapon_switch_just_pressed = true


## Force show touch controls (useful for testing on desktop)
func force_show() -> void:
	controls_container.visible = true


func _style_touch_button(btn: Button, normal_color: Color, hover_color: Color) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = normal_color
	style_normal.border_color = Color(hover_color.r, hover_color.g, hover_color.b, 0.5)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(14)
	style_normal.set_content_margin_all(8)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = hover_color
	style_pressed.border_color = Color.WHITE
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(14)
	style_pressed.set_content_margin_all(8)
	style_pressed.shadow_color = Color(hover_color.r, hover_color.g, hover_color.b, 0.4)
	style_pressed.shadow_size = 10
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(normal_color.r, normal_color.g, normal_color.b, normal_color.a + 0.15)
	style_hover.border_color = hover_color
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(14)
	style_hover.set_content_margin_all(8)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("focus", style_normal)
