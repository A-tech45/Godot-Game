extends CharacterBody2D

enum BotState { ROAM, HUNT, SEEK_STEALTH }

@export var display_name: String = "Bot"
var max_health: float = 100.0
var current_health: float = 100.0
var move_speed: float = 290.0

var weapon: Weapon
var shoot_cooldown: float = 0.0
var target_entity: Node2D = null

var state: BotState = BotState.ROAM
var roam_direction: Vector2 = Vector2.ZERO
var roam_timer: float = 0.0
var stuck_timer: float = 0.0
var unstick_dir: Vector2 = Vector2.ZERO

var is_hidden: bool = false
var hiding_zone_count: int = 0
var is_dead: bool = false

var bot_names = [
	"Nexus", "Viper", "Spectre", "Raptor", "Ghost", "Apex", 
	"Titan", "Cipher", "Shadow", "Blaze", "Fury", "Havoc", 
	"Zenith", "Pulse", "Warlock", "Storm"
]

@onready var muzzle: Node2D = $Muzzle
@onready var body_sprite: Polygon2D = $BodySprite

func _ready() -> void:
	if weapon == null:
		var weapons_pool = [
			Weapon.create_rifle(),
			Weapon.create_shotgun(),
			Weapon.create_railgun(),
			Weapon.create_launcher()
		]
		weapon = weapons_pool[randi() % weapons_pool.size()]
	
	if display_name == "Bot":
		var id = randi() % bot_names.size()
		display_name = bot_names[id] + "_" + str(randi_range(10, 99))
		
	if body_sprite and body_sprite.color == Color.WHITE:
		body_sprite.color = Color.from_hsv(randf(), 0.85, 0.95)
		
	current_health = max_health
	GameManager.register_combatant(self)
	_pick_new_roam_dir()


func setup_bot(p_name: String, hue: float, weapon_idx: int) -> void:
	display_name = p_name
	var weapons_pool = [
		Weapon.create_rifle(),
		Weapon.create_shotgun(),
		Weapon.create_railgun(),
		Weapon.create_launcher()
	]
	var safe_idx = clamp(weapon_idx, 0, weapons_pool.size() - 1)
	weapon = weapons_pool[safe_idx]
	if body_sprite:
		body_sprite.color = Color.from_hsv(hue, 0.85, 0.95)


var target_net_pos: Vector2 = Vector2.ZERO
var target_net_rot: float = 0.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Stealth Visual Smooth Fade
	var target_alpha = 0.45 if is_hidden else 1.0
	modulate.a = lerp(modulate.a, target_alpha, delta * 10.0)
		
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta
		
	# Non-host clients interpolate position from host
	if NetworkManager.is_online and not NetworkManager.is_host:
		if target_net_pos != Vector2.ZERO:
			global_position = global_position.lerp(target_net_pos, delta * 18.0)
			rotation = lerp_angle(rotation, target_net_rot, delta * 18.0)
		return
			
	# Update Target
	_find_nearest_target()
	
	# Decide Movement & Shooting State
	var steer_vec := Vector2.ZERO
	
	if target_entity != null and is_instance_valid(target_entity):
		state = BotState.HUNT
		var has_los = _has_line_of_sight(target_entity)
		var dist = global_position.distance_to(target_entity.global_position)
		
		if has_los:
			look_at(target_entity.global_position)
			if dist > 180.0:
				steer_vec = (target_entity.global_position - global_position).normalized()
			else:
				# Strafe around target
				steer_vec = (target_entity.global_position - global_position).orthogonal().normalized()
				
			# ONLY Shoot target if line of sight is clear!
			if shoot_cooldown <= 0.0 and dist < 750.0:
				_shoot()
		else:
			# Line of sight blocked by wall: Flank around wall to find clear sightline!
			var direct_dir = (target_entity.global_position - global_position).normalized()
			steer_vec = direct_dir.orthogonal() if randf() > 0.5 else -direct_dir.orthogonal()
			if steer_vec != Vector2.ZERO:
				rotation = lerp_angle(rotation, steer_vec.angle(), delta * 6.0)
	else:
		state = BotState.ROAM
		roam_timer -= delta
		if roam_timer <= 0.0:
			_pick_new_roam_dir()
		steer_vec = roam_direction
		if steer_vec != Vector2.ZERO:
			rotation = lerp_angle(rotation, steer_vec.angle(), delta * 6.0)

	# Wall collision & unstick steering
	if get_slide_collision_count() > 0:
		stuck_timer += delta
		if stuck_timer > 0.3:
			if unstick_dir == Vector2.ZERO:
				var col = get_slide_collision(0)
				unstick_dir = col.get_normal().rotated(randf_range(-1.0, 1.0))
			steer_vec = unstick_dir
			if stuck_timer > 0.8:
				stuck_timer = 0.0
				unstick_dir = Vector2.ZERO
				_pick_new_roam_dir()
	else:
		stuck_timer = 0.0
		unstick_dir = Vector2.ZERO

	velocity = steer_vec.normalized() * move_speed
	move_and_slide()
	_clamp_position_to_map()
	
	if NetworkManager.is_online and NetworkManager.is_host:
		if NetworkManager.is_relay_mode:
			var node_path = str(get_path())
			NetworkManager.send_relay_rpc(node_path, "_relay_bot_transform", [
				NetworkManager.vec2_to_array(global_position), rotation
			])
		else:
			rpc("_sync_bot_transform", global_position, rotation)


## Called via relay for bot transform sync
func _relay_bot_transform(pos_arr: Array, rot: float) -> void:
	target_net_pos = NetworkManager.array_to_vec2(pos_arr)
	target_net_rot = rot


@rpc("authority", "call_remote", "unreliable")
func _sync_bot_transform(pos: Vector2, rot: float) -> void:
	target_net_pos = pos
	target_net_rot = rot

func _has_line_of_sight(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.collision_mask = 1 # Solid wall layer
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _clamp_position_to_map() -> void:
	var bound = 1450.0
	global_position.x = clamp(global_position.x, -bound, bound)
	global_position.y = clamp(global_position.y, -bound, bound)

func _pick_new_roam_dir() -> void:
	roam_direction = Vector2.RIGHT.rotated(randf() * TAU)
	roam_timer = randf_range(1.2, 2.8)

func _find_nearest_target() -> void:
	var closest_dist := 999999.0
	var best_target: Node2D = null
	
	for combatant in GameManager.alive_combatants:
		if combatant == self or not is_instance_valid(combatant):
			continue
			
		# Stealth check: If combatant is hidden, cannot detect unless close
		var is_target_hidden = ("is_hidden" in combatant) and combatant.is_hidden
		var d = global_position.distance_to(combatant.global_position)
		
		if is_target_hidden:
			# Only detect if very close or inside same hiding spot
			if d > 140.0 and not is_hidden:
				continue
				
		if d < closest_dist:
			closest_dist = d
			best_target = combatant
			
	target_entity = best_target

func _shoot() -> void:
	shoot_cooldown = 1.0 / weapon.fire_rate + randf_range(0.04, 0.15)
	SoundManager.play_shoot(weapon.sound_id)
	
	var bullet_scene = load("res://scenes/bullet.tscn")
	for i in range(weapon.pellets_per_shot):
		var bullet = bullet_scene.instantiate()
		var spread_angle = deg_to_rad(randf_range(-weapon.bullet_spread * 1.5, weapon.bullet_spread * 1.5))
		var fire_dir = Vector2.RIGHT.rotated(rotation + spread_angle)
		
		bullet.global_position = muzzle.global_position if muzzle else global_position
		bullet.setup(self, fire_dir, weapon)
		get_parent().add_child(bullet)

func take_damage(amount: float, attacker = null) -> void:
	if is_dead:
		return
		
	current_health -= amount
	_flash_damage()
	
	if current_health <= 0.0:
		var killer_node: Node2D = attacker if (attacker != null and is_instance_valid(attacker) and attacker is Node2D) else null
		die(killer_node, "Shot")

func die(killer: Node2D = null, cause: String = "Eliminated") -> void:
	if is_dead:
		return
	is_dead = true
	_spawn_death_particles()
	GameManager.on_combatant_died(self, killer, cause)
	queue_free()

func _flash_damage() -> void:
	if body_sprite:
		body_sprite.modulate = Color(3.0, 0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(body_sprite, "modulate", Color.WHITE, 0.15)

func _spawn_death_particles() -> void:
	var p = CPUParticles2D.new()
	p.global_position = global_position
	p.emitting = true
	p.one_shot = true
	p.amount = 20
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.color = body_sprite.color if body_sprite else Color.RED
	get_parent().add_child(p)
