extends CharacterBody2D

signal health_changed(current: float, max_hp: float)
signal weapon_changed(weapon: Weapon)
signal dash_cooldown_updated(current: float, max_cd: float)

@export var display_name: String = "You (P1)"
var peer_id: int = 1

var max_health: float = 100.0
var current_health: float = 100.0
var move_speed: float = 330.0

var weapons: Array[Weapon] = []
var current_weapon_idx: int = 0

var shoot_cooldown: float = 0.0
var dash_cooldown: float = 0.0
var max_dash_cooldown: float = 1.8

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_duration: float = 0.22
var dash_speed: float = 880.0
var dash_direction: Vector2 = Vector2.ZERO

var is_hidden: bool = false
var hiding_zone_count: int = 0
var is_dead: bool = false

# Touch controls reference (set by arena on mobile)
var touch_controls: Node = null
var _last_aim_vector: Vector2 = Vector2.RIGHT
var _touch_weapon_switch_consumed: bool = false
var _touch_dash_consumed: bool = false

@onready var muzzle: Node2D = $Muzzle
@onready var body_sprite: Polygon2D = $BodySprite

func is_local_player() -> bool:
	if not NetworkManager.is_online:
		return true
	return peer_id == NetworkManager.get_my_id()

func _ready() -> void:
	if is_local_player():
		GameManager.player_node = self
	GameManager.register_combatant(self)
	
	weapons = [
		Weapon.create_rifle(),
		Weapon.create_shotgun(),
		Weapon.create_railgun(),
		Weapon.create_launcher()
	]
	
	current_health = max_health
	health_changed.emit(current_health, max_health)
	weapon_changed.emit(weapons[current_weapon_idx])

var target_net_pos: Vector2 = Vector2.ZERO
var target_net_rot: float = 0.0
var net_sync_timer: float = 0.0
var last_sent_pos: Vector2 = Vector2.ZERO
var last_sent_rot: float = 0.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Stealth Visual Smooth Fade
	var target_alpha = 0.45 if is_hidden else 1.0
	modulate.a = lerp(modulate.a, target_alpha, delta * 10.0)
		
	# Process Cooldowns
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta
	if dash_cooldown > 0.0:
		dash_cooldown -= delta
		dash_cooldown_updated.emit(dash_cooldown, max_dash_cooldown)
		
	# If this is a remote network player, interpolate position & rotation smoothly
	if not is_local_player():
		if target_net_pos != Vector2.ZERO:
			global_position = global_position.lerp(target_net_pos, clamp(delta * 22.0, 0.0, 1.0))
			rotation = lerp_angle(rotation, target_net_rot, clamp(delta * 22.0, 0.0, 1.0))
		return

	# Determine if using touch controls
	var using_touch: bool = touch_controls != null and touch_controls.controls_container.visible
	
	# Process Aiming
	if using_touch:
		if touch_controls.aim_vector.length() > 0.1:
			_last_aim_vector = touch_controls.aim_vector
			rotation = _last_aim_vector.angle()
		else:
			rotation = _last_aim_vector.angle()
	else:
		var mouse_pos = get_global_mouse_position()
		look_at(mouse_pos)
	
	# Process Dashing
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		move_and_slide()
		_spawn_ghost_trail()
		_clamp_position_to_map()
		_sync_transform_to_peers(delta)
		if dash_timer <= 0.0:
			is_dashing = false
		return
		
	# Player Input Movement
	var input_vec: Vector2
	if using_touch:
		input_vec = touch_controls.move_vector
	else:
		input_vec = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vec.normalized() * move_speed
	move_and_slide()
	_clamp_position_to_map()
	_sync_transform_to_peers(delta)
	
	# Handle Dash Input
	var dash_requested: bool = false
	if using_touch:
		if touch_controls.dash_just_pressed and not _touch_dash_consumed:
			dash_requested = true
			_touch_dash_consumed = true
		if not touch_controls.dash_just_pressed:
			_touch_dash_consumed = false
	else:
		dash_requested = Input.is_action_just_pressed("dash")
	if dash_requested and dash_cooldown <= 0.0:
		_perform_dash(input_vec)
		
	# Handle Weapon Switching
	if using_touch:
		if touch_controls.weapon_switch_just_pressed and not _touch_weapon_switch_consumed:
			var next_idx = (current_weapon_idx + 1) % weapons.size()
			_switch_weapon(next_idx)
			_touch_weapon_switch_consumed = true
		if not touch_controls.weapon_switch_just_pressed:
			_touch_weapon_switch_consumed = false
	else:
		if Input.is_action_just_pressed("weapon_1"): _switch_weapon(0)
		elif Input.is_action_just_pressed("weapon_2"): _switch_weapon(1)
		elif Input.is_action_just_pressed("weapon_3"): _switch_weapon(2)
		elif Input.is_action_just_pressed("weapon_4"): _switch_weapon(3)
	
	# Handle Shooting Input
	var current_weapon = weapons[current_weapon_idx]
	var shoot_requested: bool = false
	if using_touch:
		shoot_requested = touch_controls.is_firing
	else:
		shoot_requested = Input.is_action_pressed("shoot")
	if shoot_requested and shoot_cooldown <= 0.0:
		_shoot(current_weapon)


func _sync_transform_to_peers(delta: float) -> void:
	if not NetworkManager.is_online:
		return

	net_sync_timer += delta
	if net_sync_timer < 0.05: # 20 Hz tick rate max (prevents network buffer bloat)
		return

	var pos_changed = global_position.distance_squared_to(last_sent_pos) > 0.25
	var rot_changed = abs(angle_difference(rotation, last_sent_rot)) > 0.02
	if not pos_changed and not rot_changed:
		return

	net_sync_timer = 0.0
	last_sent_pos = global_position
	last_sent_rot = rotation

	# Round position and rotation to reduce JSON string size
	var rounded_pos = Vector2(snappedf(global_position.x, 0.1), snappedf(global_position.y, 0.1))
	var rounded_rot = snappedf(rotation, 0.01)

	if NetworkManager.is_relay_mode:
		var node_path = str(get_path())
		NetworkManager.send_relay_rpc(node_path, "_relay_sync_transform", [
			NetworkManager.vec2_to_array(rounded_pos), rounded_rot
		])
	else:
		rpc("_client_sync_transform", rounded_pos, rounded_rot)


## Called via relay to sync transform from remote player
func _relay_sync_transform(pos_arr: Array, rot: float) -> void:
	target_net_pos = NetworkManager.array_to_vec2(pos_arr)
	target_net_rot = rot


@rpc("any_peer", "call_remote", "unreliable")
func _client_sync_transform(pos: Vector2, rot: float) -> void:
	target_net_pos = pos
	target_net_rot = rot

func _clamp_position_to_map() -> void:
	var bound = 1450.0
	global_position.x = clamp(global_position.x, -bound, bound)
	global_position.y = clamp(global_position.y, -bound, bound)

func _perform_dash(input_vec: Vector2) -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown = max_dash_cooldown
	dash_direction = input_vec.normalized() if input_vec != Vector2.ZERO else Vector2.RIGHT.rotated(rotation)
	SoundManager.play_dash()

func _switch_weapon(idx: int) -> void:
	if idx >= 0 and idx < weapons.size() and idx != current_weapon_idx:
		current_weapon_idx = idx
		weapon_changed.emit(weapons[current_weapon_idx])
		if NetworkManager.is_online and is_local_player():
			if NetworkManager.is_relay_mode:
				var node_path = str(get_path())
				NetworkManager.send_relay_rpc(node_path, "_relay_weapon_switch", [idx])
			else:
				rpc("_sync_weapon_switch", idx)


## Called via relay for weapon switch
func _relay_weapon_switch(idx: int) -> void:
	if idx >= 0 and idx < weapons.size():
		current_weapon_idx = idx
		weapon_changed.emit(weapons[current_weapon_idx])


@rpc("any_peer", "call_remote", "reliable")
func _sync_weapon_switch(idx: int) -> void:
	if idx >= 0 and idx < weapons.size():
		current_weapon_idx = idx
		weapon_changed.emit(weapons[current_weapon_idx])


func _shoot(weapon: Weapon) -> void:
	shoot_cooldown = 1.0 / weapon.fire_rate
	SoundManager.play_shoot(weapon.sound_id)
	
	if is_local_player():
		GameManager.request_camera_shake(weapon.camera_shake, 0.12)
		velocity -= Vector2.RIGHT.rotated(rotation) * weapon.recoil_force
		if NetworkManager.is_online:
			if NetworkManager.is_relay_mode:
				var node_path = str(get_path())
				NetworkManager.send_relay_rpc(node_path, "_relay_remote_shoot", [current_weapon_idx, rotation])
			else:
				rpc("_sync_remote_shoot", current_weapon_idx, rotation)
	
	var bullet_scene = load("res://scenes/bullet.tscn")
	for i in range(weapon.pellets_per_shot):
		var bullet = bullet_scene.instantiate()
		var spread_angle = deg_to_rad(randf_range(-weapon.bullet_spread, weapon.bullet_spread))
		var fire_dir = Vector2.RIGHT.rotated(rotation + spread_angle)
		
		bullet.global_position = muzzle.global_position if muzzle else global_position
		bullet.setup(self, fire_dir, weapon)
		get_parent().add_child(bullet)


## Called via relay for remote shoot
func _relay_remote_shoot(weapon_idx: int, shoot_rot: float) -> void:
	if weapon_idx >= 0 and weapon_idx < weapons.size():
		rotation = shoot_rot
		var w = weapons[weapon_idx]
		_shoot(w)


@rpc("any_peer", "call_remote", "unreliable")
func _sync_remote_shoot(weapon_idx: int, shoot_rot: float) -> void:
	if weapon_idx >= 0 and weapon_idx < weapons.size():
		rotation = shoot_rot
		var w = weapons[weapon_idx]
		_shoot(w)


func take_damage(amount: float, attacker = null) -> void:
	if is_dashing or is_dead:
		return # Invulnerable during dash
		
	if NetworkManager.is_online and not NetworkManager.is_host:
		var attacker_name: String = "Enemy"
		if attacker != null and is_instance_valid(attacker) and "display_name" in attacker:
			attacker_name = attacker.display_name
		if NetworkManager.is_relay_mode:
			var node_path = str(get_path())
			NetworkManager.send_relay_rpc(node_path, "_relay_take_damage", [amount, attacker_name])
		else:
			rpc_id(1, "_server_take_damage", amount, attacker_name)
		return
		
	_apply_damage_internal(amount, attacker)


## Called via relay for damage (routed to host)
func _relay_take_damage(amount: float, attacker_name: String) -> void:
	if not NetworkManager.is_host:
		return
	_apply_damage_internal(amount, null, attacker_name)


@rpc("any_peer", "call_remote", "reliable")
func _server_take_damage(amount: float, attacker_name: String) -> void:
	if not NetworkManager.is_host:
		return
	_apply_damage_internal(amount, null, attacker_name)


func _apply_damage_internal(amount: float, attacker = null, override_killer_name: String = "") -> void:
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	if NetworkManager.is_online and NetworkManager.is_host:
		if NetworkManager.is_relay_mode:
			var node_path = str(get_path())
			NetworkManager.send_relay_rpc(node_path, "_relay_sync_health", [current_health])
		else:
			rpc("_client_sync_health", current_health)
		
	_flash_damage()
	
	if current_health <= 0.0:
		var killer_name: String = override_killer_name if override_killer_name != "" else "Enemy"
		if attacker != null and is_instance_valid(attacker) and "display_name" in attacker:
			killer_name = attacker.display_name
			
		if is_local_player():
			GameManager.trigger_player_death(killer_name)
			
		var killer_node: Node2D = attacker if (attacker != null and is_instance_valid(attacker) and attacker is Node2D) else null
		die(killer_node, "Shot")


## Called via relay for health sync
func _relay_sync_health(new_health: float) -> void:
	current_health = new_health
	health_changed.emit(current_health, max_health)


@rpc("authority", "call_remote", "reliable")
func _client_sync_health(new_health: float) -> void:
	current_health = new_health
	health_changed.emit(current_health, max_health)

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

func _spawn_ghost_trail() -> void:
	var ghost = Polygon2D.new()
	ghost.polygon = body_sprite.polygon
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	ghost.color = Color(0.2, 0.8, 1.0, 0.5)
	ghost.z_index = z_index - 1
	get_parent().add_child(ghost)
	
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(ghost.queue_free)

func _spawn_death_particles() -> void:
	var p = CPUParticles2D.new()
	p.global_position = global_position
	p.emitting = true
	p.one_shot = true
	p.amount = 25
	p.lifetime = 0.6
	p.explosiveness = 0.9
	p.spread = 188.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 250.0
	p.color = Color(0.1, 0.8, 1.0)
	get_parent().add_child(p)
