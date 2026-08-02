class_name TouchJoystick
extends Control

## Reusable on-screen virtual joystick for touch controls.
## Renders a base ring and a draggable thumb knob.
## Exposes 'output' (normalized direction) and 'is_active' (finger held).

signal joystick_changed(output_vector: Vector2)
signal joystick_released

@export var base_radius: float = 75.0
@export var knob_radius: float = 30.0
@export var dead_zone: float = 0.15
@export var base_color: Color = Color(1.0, 1.0, 1.0, 0.12)
@export var base_outline_color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var knob_color: Color = Color(1.0, 1.0, 1.0, 0.35)
@export var knob_active_color: Color = Color(0.3, 0.9, 1.0, 0.6)

var output: Vector2 = Vector2.ZERO
var is_active: bool = false

var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Set minimum size so layout containers respect our dimensions
	custom_minimum_size = Vector2(base_radius * 2, base_radius * 2)
	_center = size / 2.0
	_knob_position = _center


func _draw() -> void:
	var center = size / 2.0
	
	# Base circle fill
	draw_circle(center, base_radius, base_color)
	
	# Base circle outline ring
	_draw_circle_outline(center, base_radius, base_outline_color, 2.0)
	
	# Inner guide circle
	_draw_circle_outline(center, base_radius * 0.4, Color(1.0, 1.0, 1.0, 0.08), 1.0)
	
	# Knob
	var current_knob_color = knob_active_color if is_active else knob_color
	draw_circle(_knob_position, knob_radius, current_knob_color)
	
	# Knob highlight ring
	_draw_circle_outline(_knob_position, knob_radius, Color(1.0, 1.0, 1.0, 0.5 if is_active else 0.2), 1.5)


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var point_count: int = 48
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(point_count + 1):
		var angle = TAU * i / point_count
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for i in range(point_count):
		draw_line(points[i], points[i + 1], color, width, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index == -1:
			_touch_index = event.index
			_center = size / 2.0
			is_active = true
			_update_knob_position(event.position)
	else:
		if event.index == _touch_index:
			_reset()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _touch_index:
		_update_knob_position(event.position)


func _update_knob_position(touch_pos: Vector2) -> void:
	var diff = touch_pos - _center
	var dist = diff.length()
	
	# Clamp to base radius
	if dist > base_radius:
		diff = diff.normalized() * base_radius
	
	_knob_position = _center + diff
	
	# Calculate normalized output with dead zone
	var normalized = diff / base_radius
	if normalized.length() < dead_zone:
		output = Vector2.ZERO
	else:
		output = normalized
	
	joystick_changed.emit(output)
	queue_redraw()


func _reset() -> void:
	_touch_index = -1
	is_active = false
	output = Vector2.ZERO
	_knob_position = size / 2.0
	joystick_released.emit()
	queue_redraw()
