extends StaticBody2D

@export var is_destructible: bool = false
@export var max_hp: float = 60.0
@export var current_hp: float = 60.0
@export var wall_type: String = "BRICK" # "BRICK", "WOOD_BARRIER", "CRATE"
@export var size: Vector2 = Vector2(64, 64)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	current_hp = max_hp
	collision_layer = 1
	collision_mask = 6 # Collide with players, bots, bullets
	queue_redraw()

func setup_wall(p_type: String, p_size: Vector2, p_destructible: bool = false, hp: float = 60.0) -> void:
	wall_type = p_type
	size = p_size
	is_destructible = p_destructible
	max_hp = hp
	current_hp = hp
	
	if collision_shape:
		var rect = RectangleShape2D.new()
		rect.size = size
		collision_shape.shape = rect
		
	queue_redraw()

func take_damage(amount: float, _attacker = null) -> void:
	if not is_destructible:
		SoundManager.play_hit()
		_flash()
		return
		
	current_hp -= amount
	SoundManager.play_hit()
	_flash()
	
	if current_hp <= 0.0:
		_destroy()

func _flash() -> void:
	modulate = Color(2.5, 2.5, 2.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func _destroy() -> void:
	_spawn_debris_particles()
	SoundManager.play_tile_collapse()
	queue_free()

func _draw() -> void:
	var rect = Rect2(-size * 0.5, size)
	var outline_color = Color(0.12, 0.08, 0.05)
	
	match wall_type:
		"BRICK":
			# Vibrant Cartoon Terracotta Brick Wall
			draw_rect(rect, Color(0.82, 0.38, 0.22))
			# Bold Cartoon Outline
			draw_rect(rect, outline_color, false, 3.5)
			# Inner Cartoon Brick Lines
			var step_y = 18.0
			var y_pos = -size.y * 0.5 + step_y
			while y_pos < size.y * 0.5:
				draw_line(Vector2(-size.x * 0.5, y_pos), Vector2(size.x * 0.5, y_pos), Color(0.4, 0.18, 0.1, 0.7), 2.0)
				y_pos += step_y
				
		"WOOD_BARRIER":
			# Cartoon Golden Wood Planks
			var wood_col = Color(0.88, 0.58, 0.22) if not is_destructible else Color(0.95, 0.65, 0.28)
			draw_rect(rect, wood_col)
			# Bold Outline
			draw_rect(rect, outline_color, false, 3.5)
			# Diagonal Cartoon X Planks
			draw_line(-size * 0.45, size * 0.45, Color(0.45, 0.25, 0.08), 3.5)
			draw_line(Vector2(-size.x * 0.45, size.y * 0.45), Vector2(size.x * 0.45, -size.y * 0.45), Color(0.45, 0.25, 0.08), 3.5)
			
		"CRATE":
			# Cartoonish Bright Green Supply Crate
			draw_rect(rect, Color(0.25, 0.72, 0.35))
			# Bold Outline
			draw_rect(rect, outline_color, false, 3.5)
			# Cartoon Stencil Cross & Highlights
			draw_line(-size * 0.4, size * 0.4, Color(1.0, 0.88, 0.2), 3.0)
			draw_line(Vector2(-size.x * 0.4, size.y * 0.4), Vector2(size.x * 0.4, -size.y * 0.4), Color(1.0, 0.88, 0.2), 3.0)

func _spawn_debris_particles() -> void:
	var p = CPUParticles2D.new()
	p.global_position = global_position
	p.emitting = true
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.5
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector2(0, 100)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	
	if wall_type == "WOOD_BARRIER" or wall_type == "CRATE":
		p.color = Color(0.9, 0.6, 0.2)
	else:
		p.color = Color(0.8, 0.4, 0.25)
		
	get_parent().add_child(p)
	
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(p.queue_free)
