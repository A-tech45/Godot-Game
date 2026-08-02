class_name Weapon
extends Resource

@export var weapon_name: String = "Assault Rifle"
@export var fire_rate: float = 8.0 # Shots per second
@export var damage: float = 18.0
@export var bullet_speed: float = 1100.0
@export var bullet_spread: float = 4.0 # Spread in degrees
@export var pellets_per_shot: int = 1
@export var recoil_force: float = 120.0
@export var max_ammo: int = 30
@export var reload_time: float = 1.4
@export var sound_id: int = 0
@export var bullet_color: Color = Color(1.0, 0.85, 0.3)
@export var bullet_size: float = 6.0
@export var camera_shake: float = 4.0

static func create_rifle() -> Weapon:
	var w = Weapon.new()
	w.weapon_name = "Assault Rifle"
	w.fire_rate = 8.5
	w.damage = 22.0
	w.bullet_speed = 1200.0
	w.bullet_spread = 5.0
	w.pellets_per_shot = 1
	w.recoil_force = 80.0
	w.max_ammo = 30
	w.reload_time = 1.2
	w.sound_id = 0
	w.bullet_color = Color(1.0, 0.85, 0.2)
	w.bullet_size = 6.0
	w.camera_shake = 3.5
	return w

static func create_shotgun() -> Weapon:
	var w = Weapon.new()
	w.weapon_name = "Scatter Shotgun"
	w.fire_rate = 1.4
	w.damage = 16.0 # Per pellet x 6 = 96 max
	w.bullet_speed = 950.0
	w.bullet_spread = 18.0
	w.pellets_per_shot = 6
	w.recoil_force = 320.0
	w.max_ammo = 8
	w.reload_time = 1.8
	w.sound_id = 1
	w.bullet_color = Color(1.0, 0.4, 0.1)
	w.bullet_size = 7.0
	w.camera_shake = 10.0
	return w

static func create_railgun() -> Weapon:
	var w = Weapon.new()
	w.weapon_name = "Plasma Railgun"
	w.fire_rate = 1.0
	w.damage = 85.0
	w.bullet_speed = 2200.0
	w.bullet_spread = 0.5
	w.pellets_per_shot = 1
	w.recoil_force = 450.0
	w.max_ammo = 5
	w.reload_time = 2.0
	w.sound_id = 2
	w.bullet_color = Color(0.1, 0.9, 1.0)
	w.bullet_size = 10.0
	w.camera_shake = 14.0
	return w

static func create_launcher() -> Weapon:
	var w = Weapon.new()
	w.weapon_name = "Tile Breaker"
	w.fire_rate = 2.0
	w.damage = 45.0
	w.bullet_speed = 800.0
	w.bullet_spread = 3.0
	w.pellets_per_shot = 1
	w.recoil_force = 200.0
	w.max_ammo = 12
	w.reload_time = 1.6
	w.sound_id = 3
	w.bullet_color = Color(0.3, 1.0, 0.4)
	w.bullet_size = 12.0
	w.camera_shake = 8.0
	return w
