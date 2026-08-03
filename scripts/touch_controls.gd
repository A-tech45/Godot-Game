extends CanvasLayer

## Touch controls overlay & HUD Layout Customizer.
## Provides dual joysticks, weapon switch, and dash buttons with customizable positions.

signal edit_mode_closed

# Exposed state for player.gd to read each frame
var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.ZERO
var is_firing: bool = false
var dash_just_pressed: bool = false
var weapon_switch_just_pressed: bool = false

# Edit mode state
var is_edit_mode: bool = false
var _dragging_node: Control = null
var _drag_start_global: Vector2 = Vector2.ZERO
var _node_start_global: Vector2 = Vector2.ZERO
var _initial_positions: Dictionary = {}
var _default_positions: Dictionary = {}

const LAYOUT_SAVE_PATH: String = "user://hud_layout.json"

@onready var left_joystick: TouchJoystick = %LeftJoystick
@onready var right_joystick: TouchJoystick = %RightJoystick
@onready var dash_button: Button = %DashButton
@onready var weapon_switch_button: Button = %WeaponSwitchButton
@onready var controls_container: Control = %ControlsContainer

var edit_bar_container: PanelContainer = null


func _ready() -> void:
	layer = 11  # Above HUD
	process_mode = PROCESS_MODE_ALWAYS
	
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
	
	# Connect gui_input for drag & drop layout customization
	var draggable_nodes = [left_joystick, right_joystick, dash_button, weapon_switch_button]
	for node in draggable_nodes:
		node.gui_input.connect(_on_control_gui_input.bind(node))
	
	# Style buttons for touch-friendly appearance
	_style_touch_button(dash_button, Color(0.1, 0.3, 0.4, 0.6), Color(0.15, 0.5, 0.6, 0.8))
	_style_touch_button(weapon_switch_button, Color(0.35, 0.25, 0.05, 0.6), Color(0.5, 0.4, 0.1, 0.8))
	
	# Cache default positions
	call_deferred("_store_default_positions")
	
	# Load custom saved layout if present
	call_deferred("load_layout")


func _store_default_positions() -> void:
	_default_positions = {
		"left_joystick": left_joystick.global_position,
		"right_joystick": right_joystick.global_position,
		"dash_button": dash_button.global_position,
		"weapon_switch_button": weapon_switch_button.global_position
	}


func _physics_process(_delta: float) -> void:
	if is_edit_mode:
		return

	if dash_just_pressed:
		call_deferred("_clear_dash_flag")
	if weapon_switch_just_pressed:
		call_deferred("_clear_weapon_flag")


func _clear_dash_flag() -> void:
	dash_just_pressed = false

func _clear_weapon_flag() -> void:
	weapon_switch_just_pressed = false


func _on_left_joystick_changed(vec: Vector2) -> void:
	if not is_edit_mode: move_vector = vec

func _on_left_joystick_released() -> void:
	move_vector = Vector2.ZERO

func _on_right_joystick_changed(vec: Vector2) -> void:
	if not is_edit_mode:
		aim_vector = vec
		is_firing = vec.length() > 0.2

func _on_right_joystick_released() -> void:
	aim_vector = Vector2.ZERO
	is_firing = false

func _on_dash_pressed() -> void:
	if not is_edit_mode: dash_just_pressed = true

func _on_weapon_switch_pressed() -> void:
	if not is_edit_mode: weapon_switch_just_pressed = true


func force_show() -> void:
	controls_container.visible = true


# ─── CUSTOM HUD LAYOUT EDITOR (GUI INPUT DRAG & DROP) ───

func start_edit_mode() -> void:
	if is_edit_mode: return
	is_edit_mode = true
	controls_container.visible = true
	
	# Convert controls to TOP_LEFT anchoring so global_position movement works freely
	var draggable_nodes = [left_joystick, right_joystick, dash_button, weapon_switch_button]
	for node in draggable_nodes:
		var cur_pos = node.global_position
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.global_position = cur_pos
	
	# Store initial positions for Cancel option
	_initial_positions = {
		"left_joystick": left_joystick.global_position,
		"right_joystick": right_joystick.global_position,
		"dash_button": dash_button.global_position,
		"weapon_switch_button": weapon_switch_button.global_position
	}
	
	_create_edit_top_bar()


func _on_control_gui_input(event: InputEvent, node: Control) -> void:
	if not is_edit_mode:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging_node = node
				_drag_start_global = event.global_position
				_node_start_global = node.global_position
				node.accept_event()
			else:
				if _dragging_node == node:
					_dragging_node = null
					node.accept_event()

	elif event is InputEventMouseMotion and _dragging_node == node:
		var delta_pos = event.global_position - _drag_start_global
		var new_pos = _node_start_global + delta_pos
		
		# Clamp within screen dimensions
		var vp_size = get_viewport().get_visible_rect().size
		new_pos.x = clamp(new_pos.x, 10, vp_size.x - node.size.x - 10)
		new_pos.y = clamp(new_pos.y, 10, vp_size.y - node.size.y - 10)
		
		node.global_position = new_pos
		node.accept_event()

	elif event is InputEventScreenTouch:
		if event.pressed:
			_dragging_node = node
			_drag_start_global = event.position
			_node_start_global = node.global_position
			node.accept_event()
		else:
			if _dragging_node == node:
				_dragging_node = null
				node.accept_event()

	elif event is InputEventScreenDrag and _dragging_node == node:
		var delta_pos = event.position - _drag_start_global
		var new_pos = _node_start_global + delta_pos
		
		var vp_size = get_viewport().get_visible_rect().size
		new_pos.x = clamp(new_pos.x, 10, vp_size.x - node.size.x - 10)
		new_pos.y = clamp(new_pos.y, 10, vp_size.y - node.size.y - 10)
		
		node.global_position = new_pos
		node.accept_event()


func _create_edit_top_bar() -> void:
	if edit_bar_container != null and is_instance_valid(edit_bar_container):
		edit_bar_container.show()
		return
		
	edit_bar_container = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	style.border_color = Color(0.0, 0.94, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	edit_bar_container.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	
	var title = Label.new()
	title.text = "✏️ CUSTOM HUD EDITOR (DRAG BUTTONS TO REPOSITION)"
	title.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0))
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)
	
	var reset_btn = Button.new()
	reset_btn.text = "RESET DEFAULTS"
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.pressed.connect(_on_reset_layout_pressed)
	hbox.add_child(reset_btn)
	
	var save_btn = Button.new()
	save_btn.text = "SAVE & CLOSE"
	save_btn.add_theme_font_size_override("font_size", 14)
	save_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	save_btn.pressed.connect(_on_save_layout_pressed)
	hbox.add_child(save_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.add_theme_font_size_override("font_size", 13)
	cancel_btn.pressed.connect(_on_cancel_layout_pressed)
	hbox.add_child(cancel_btn)
	
	margin.add_child(hbox)
	edit_bar_container.add_child(margin)
	
	# Position top bar
	edit_bar_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	edit_bar_container.offset_left = 30
	edit_bar_container.offset_right = -30
	edit_bar_container.offset_top = 20
	edit_bar_container.offset_bottom = 80
	
	add_child(edit_bar_container)


func _on_save_layout_pressed() -> void:
	save_layout()
	_close_edit_mode()


func _on_cancel_layout_pressed() -> void:
	if _initial_positions.size() > 0:
		left_joystick.global_position = _initial_positions.get("left_joystick", left_joystick.global_position)
		right_joystick.global_position = _initial_positions.get("right_joystick", right_joystick.global_position)
		dash_button.global_position = _initial_positions.get("dash_button", dash_button.global_position)
		weapon_switch_button.global_position = _initial_positions.get("weapon_switch_button", weapon_switch_button.global_position)
	_close_edit_mode()


func _on_reset_layout_pressed() -> void:
	reset_default_layout()


func _close_edit_mode() -> void:
	is_edit_mode = false
	_dragging_node = null
	if edit_bar_container != null and is_instance_valid(edit_bar_container):
		edit_bar_container.hide()
	
	# Re-check auto-hide for non-touch
	var is_touch: bool = DisplayServer.is_touchscreen_available()
	controls_container.visible = is_touch
	
	edit_mode_closed.emit()


# ─── PERSISTENCE (SAVE / LOAD LAYOUT) ───

func save_layout() -> void:
	var layout_data = {
		"left_joystick": { "pos_x": left_joystick.global_position.x, "pos_y": left_joystick.global_position.y },
		"right_joystick": { "pos_x": right_joystick.global_position.x, "pos_y": right_joystick.global_position.y },
		"dash_button": { "pos_x": dash_button.global_position.x, "pos_y": dash_button.global_position.y },
		"weapon_switch_button": { "pos_x": weapon_switch_button.global_position.x, "pos_y": weapon_switch_button.global_position.y }
	}
	
	var file = FileAccess.open(LAYOUT_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(layout_data))
		file.close()


func load_layout() -> void:
	if not FileAccess.file_exists(LAYOUT_SAVE_PATH):
		return
		
	var file = FileAccess.open(LAYOUT_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
		
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(text)
	if json == null or not (json is Dictionary):
		return
		
	_apply_global_pos(left_joystick, json.get("left_joystick", {}))
	_apply_global_pos(right_joystick, json.get("right_joystick", {}))
	_apply_global_pos(dash_button, json.get("dash_button", {}))
	_apply_global_pos(weapon_switch_button, json.get("weapon_switch_button", {}))


func _apply_global_pos(node: Control, data: Dictionary) -> void:
	if node != null and is_instance_valid(node) and data.has("pos_x") and data.has("pos_y"):
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.global_position = Vector2(float(data["pos_x"]), float(data["pos_y"]))


func reset_default_layout() -> void:
	if DirAccess.remove_absolute(LAYOUT_SAVE_PATH) == OK:
		pass
	if _default_positions.size() > 0:
		_apply_global_pos(left_joystick, _default_positions.get("left_joystick", {}))
		_apply_global_pos(right_joystick, _default_positions.get("right_joystick", {}))
		_apply_global_pos(dash_button, _default_positions.get("dash_button", {}))
		_apply_global_pos(weapon_switch_button, _default_positions.get("weapon_switch_button", {}))


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
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("hover", style_normal)
