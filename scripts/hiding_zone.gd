extends Area2D

@export var zone_type: String = "FOLIAGE" # "FOLIAGE", "RUINED_SHADOW"
@export var zone_radius: float = 75.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detect players & bots
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if collision_shape:
		var circle = CircleShape2D.new()
		circle.radius = zone_radius
		collision_shape.shape = circle
		
	queue_redraw()

func setup_zone(p_type: String, radius: float) -> void:
	zone_type = p_type
	zone_radius = radius
	if collision_shape:
		var circle = CircleShape2D.new()
		circle.radius = zone_radius
		collision_shape.shape = circle
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if "is_hidden" in body:
		if not ("hiding_zone_count" in body):
			body.set("hiding_zone_count", 0)
		body.hiding_zone_count += 1
		body.is_hidden = true

func _on_body_exited(body: Node2D) -> void:
	if "is_hidden" in body and "hiding_zone_count" in body:
		body.hiding_zone_count = max(0, body.hiding_zone_count - 1)
		if body.hiding_zone_count <= 0:
			body.is_hidden = false

func _draw() -> void:
	if zone_type == "FOLIAGE":
		# Translucent overgrown camouflage foliage
		draw_circle(Vector2.ZERO, zone_radius, Color(0.1, 0.4, 0.15, 0.45))
		draw_circle(Vector2.ZERO, zone_radius * 0.8, Color(0.15, 0.5, 0.2, 0.35))
		draw_arc(Vector2.ZERO, zone_radius, 0, TAU, 32, Color(0.2, 0.6, 0.25, 0.6), 2.0)
		
		# Draw leaf accent details inside foliage bush
		for i in range(5):
			var angle = i * (TAU / 5.0)
			var offset = Vector2.RIGHT.rotated(angle) * (zone_radius * 0.4)
			draw_circle(offset, zone_radius * 0.3, Color(0.1, 0.45, 0.15, 0.4))
	else:
		# Dark ruined house room shadow
		draw_circle(Vector2.ZERO, zone_radius, Color(0.04, 0.04, 0.08, 0.6))
		draw_arc(Vector2.ZERO, zone_radius, 0, TAU, 32, Color(0.2, 0.2, 0.3, 0.4), 1.5)
