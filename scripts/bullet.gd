extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 1000.0
var damage: float = 20.0
var shooter: Node2D = null
var bullet_color: Color = Color.YELLOW
var bullet_size: float = 6.0
var max_lifetime: float = 2.5
var lifetime: float = 0.0

var trail_points: Array[Vector2] = []
var max_trail: int = 6

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func setup(p_shooter: Node2D, p_dir: Vector2, weapon: Weapon) -> void:
	shooter = p_shooter
	direction = p_dir.normalized()
	rotation = direction.angle()
	speed = weapon.bullet_speed
	damage = weapon.damage
	bullet_color = weapon.bullet_color
	bullet_size = weapon.bullet_size

func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return
		
	var move_dist = direction * speed * delta
	global_position += move_dist
	
	# Maintain trail
	trail_points.push_front(global_position)
	if trail_points.size() > max_trail:
		trail_points.pop_back()
		
	queue_redraw()

func _draw() -> void:
	# Draw bullet trail
	if trail_points.size() > 1:
		for i in range(trail_points.size() - 1):
			var p1 = to_local(trail_points[i])
			var p2 = to_local(trail_points[i + 1])
			var alpha = 1.0 - (float(i) / trail_points.size())
			draw_line(p1, p2, Color(bullet_color.r, bullet_color.g, bullet_color.b, alpha * 0.7), bullet_size * 0.6)
	
	# Draw glowing projectile core
	draw_circle(Vector2.ZERO, bullet_size * 1.4, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.4))
	draw_circle(Vector2.ZERO, bullet_size, bullet_color)
	draw_circle(Vector2.ZERO, bullet_size * 0.5, Color.WHITE)

func _on_body_entered(body: Node2D) -> void:
	if is_instance_valid(shooter) and body == shooter:
		return # Don't hit self
		
	if body.has_method("take_damage"):
		var should_apply_damage: bool = true
		if NetworkManager.is_online:
			# In online match, Host is authoritative for applying damage
			should_apply_damage = NetworkManager.is_host
			
		if should_apply_damage:
			var valid_attacker = shooter if is_instance_valid(shooter) else null
			body.take_damage(damage, valid_attacker)
			
		SoundManager.play_hit()
		if body is CharacterBody2D:
			_spawn_floating_damage(body.global_position, damage)
		
	_create_impact_particles()
	queue_free()


func _spawn_floating_damage(pos: Vector2, amt: float) -> void:
	var label = Label.new()
	label.text = str(int(amt))
	label.modulate = Color(1.0, 0.3, 0.2)
	label.z_index = 50
	label.global_position = pos + Vector2(randf_range(-10, 10), -20)
	label.add_theme_font_size_override("font_size", 18)
	
	get_parent().add_child(label)
	
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -35), 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)

func _create_impact_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 10
	particles.lifetime = 0.3
	particles.direction = -direction
	particles.spread = 45.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = bullet_color
	
	get_parent().add_child(particles)
	
	var timer = get_tree().create_timer(0.4)
	timer.timeout.connect(particles.queue_free)
