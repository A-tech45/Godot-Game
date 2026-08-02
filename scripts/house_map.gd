extends Node2D

var map_width: float = 3000.0
var map_height: float = 3000.0
var map_origin: Vector2 = Vector2.ZERO

var cover_wall_scene = load("res://scenes/cover_wall.tscn")
var hiding_zone_scene = load("res://scenes/hiding_zone.tscn")

var ground_tex: Texture2D = null
var spawn_points: Array[Vector2] = []

func _ready() -> void:
	GameManager.current_tile_grid = self
	map_origin = Vector2(-map_width * 0.5, -map_height * 0.5)
	
	if ResourceLoader.exists("res://assets/ground.png"):
		ground_tex = load("res://assets/ground.png")
		
	_build_ruined_houses_map()
	queue_redraw()

func is_pos_collapsed(_world_pos: Vector2) -> bool:
	return false

func get_tile_state(_world_pos: Vector2) -> int:
	return 0

func crack_tile_at_world_pos(_world_pos: Vector2, _radius: int = 1) -> void:
	pass

func get_random_spawn_pos() -> Vector2:
	if spawn_points.size() > 0:
		return spawn_points[randi() % spawn_points.size()] + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	return Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000))

func _build_ruined_houses_map() -> void:
	var wall_thick = 48.0
	# 1. Outer Perimeter Solid Walls (3000x3000 Sandbox Boundary Lock)
	_spawn_wall(Vector2(0, -map_height * 0.5 - wall_thick * 0.5), Vector2(map_width + wall_thick * 2, wall_thick), "BRICK", false)
	_spawn_wall(Vector2(0, map_height * 0.5 + wall_thick * 0.5), Vector2(map_width + wall_thick * 2, wall_thick), "BRICK", false)
	_spawn_wall(Vector2(-map_width * 0.5 - wall_thick * 0.5, 0), Vector2(wall_thick, map_height + wall_thick * 2), "BRICK", false)
	_spawn_wall(Vector2(map_width * 0.5 + wall_thick * 0.5, 0), Vector2(wall_thick, map_height + wall_thick * 2), "BRICK", false)
	
	# 8 Ruined House Complexes across 3000x3000 Map
	var nw_center = Vector2(-900, -900)
	_build_house_room(nw_center, Vector2(400, 400))
	
	var ne_center = Vector2(900, -900)
	_build_house_room(ne_center, Vector2(400, 400))
	
	var sw_center = Vector2(-900, 900)
	_build_house_room(sw_center, Vector2(400, 400))
	
	var se_center = Vector2(900, 900)
	_build_house_room(se_center, Vector2(400, 400))
	
	var north_fort = Vector2(0, -900)
	_build_house_room(north_fort, Vector2(420, 360))
	
	var south_fort = Vector2(0, 900)
	_build_house_room(south_fort, Vector2(420, 360))
	
	var west_bunker = Vector2(-900, 0)
	_build_house_room(west_bunker, Vector2(360, 420))
	
	var east_bunker = Vector2(900, 0)
	_build_house_room(east_bunker, Vector2(360, 420))

	# Central Courtyard Destructible Crates & Wood Barricades (Open Middle Fighting Arena!)
	_spawn_wall(Vector2(-350, -150), Vector2(160, 40), "WOOD_BARRIER", true, 60.0)
	_spawn_wall(Vector2(350, 150), Vector2(160, 40), "WOOD_BARRIER", true, 60.0)
	_spawn_wall(Vector2(-350, 150), Vector2(160, 40), "WOOD_BARRIER", true, 60.0)
	_spawn_wall(Vector2(350, -150), Vector2(160, 40), "WOOD_BARRIER", true, 60.0)
	
	_spawn_wall(Vector2(-300, -400), Vector2(80, 80), "CRATE", true, 45.0)
	_spawn_wall(Vector2(300, 400), Vector2(80, 80), "CRATE", true, 45.0)
	_spawn_wall(Vector2(-300, 400), Vector2(80, 80), "CRATE", true, 45.0)
	_spawn_wall(Vector2(300, -400), Vector2(80, 80), "CRATE", true, 45.0)

	# 28 Stealth Hiding Zones (Camouflage Foliage Bushes & Ruined Shadows)
	_spawn_hiding_zone(Vector2(0, 0), "FOLIAGE", 130.0) # Central Mega Bush
	_spawn_hiding_zone(Vector2(-450, 0), "FOLIAGE", 100.0)
	_spawn_hiding_zone(Vector2(450, 0), "FOLIAGE", 100.0)
	_spawn_hiding_zone(Vector2(0, -450), "FOLIAGE", 100.0)
	_spawn_hiding_zone(Vector2(0, 450), "FOLIAGE", 100.0)
	
	# House Shadows
	_spawn_hiding_zone(nw_center, "RUINED_SHADOW", 100.0)
	_spawn_hiding_zone(ne_center, "RUINED_SHADOW", 100.0)
	_spawn_hiding_zone(sw_center, "RUINED_SHADOW", 100.0)
	_spawn_hiding_zone(se_center, "RUINED_SHADOW", 100.0)
	_spawn_hiding_zone(north_fort, "RUINED_SHADOW", 100.0)
	_spawn_hiding_zone(south_fort, "RUINED_SHADOW", 100.0)
	_spawn_hiding_zone(west_bunker, "RUINED_SHADOW", 100.0)
	_spawn_hiding_zone(east_bunker, "RUINED_SHADOW", 100.0)
	
	# Extra Foliage Corridors
	_spawn_hiding_zone(Vector2(-1200, -500), "FOLIAGE", 90.0)
	_spawn_hiding_zone(Vector2(-1200, 500), "FOLIAGE", 90.0)
	_spawn_hiding_zone(Vector2(1200, -500), "FOLIAGE", 90.0)
	_spawn_hiding_zone(Vector2(1200, 500), "FOLIAGE", 90.0)
	_spawn_hiding_zone(Vector2(-500, -1200), "FOLIAGE", 90.0)
	_spawn_hiding_zone(Vector2(500, -1200), "FOLIAGE", 90.0)
	_spawn_hiding_zone(Vector2(-500, 1200), "FOLIAGE", 90.0)
	_spawn_hiding_zone(Vector2(500, 1200), "FOLIAGE", 90.0)

	# Spawn points across 3000x3000 compound
	spawn_points = [
		nw_center, ne_center, sw_center, se_center, north_fort, south_fort, west_bunker, east_bunker,
		Vector2(-1200, 0), Vector2(1200, 0), Vector2(0, -1200), Vector2(0, 1200),
		Vector2(-600, -300), Vector2(600, 300), Vector2(-300, 600), Vector2(300, -600)
	]

func _build_house_room(center: Vector2, room_size: Vector2) -> void:
	var half_w = room_size.x * 0.5
	var half_h = room_size.y * 0.5
	var wall_thick = 32.0
	
	# North wall with wide 150px doorway gap
	_spawn_wall(center + Vector2(-half_w * 0.5 - 35, -half_h), Vector2(half_w - 70, wall_thick), "BRICK", false)
	_spawn_wall(center + Vector2(half_w * 0.5 + 35, -half_h), Vector2(half_w - 70, wall_thick), "BRICK", false)
	
	# South wall with wide 150px doorway gap
	_spawn_wall(center + Vector2(-half_w * 0.5 - 35, half_h), Vector2(half_w - 70, wall_thick), "BRICK", false)
	_spawn_wall(center + Vector2(half_w * 0.5 + 35, half_h), Vector2(half_w - 70, wall_thick), "BRICK", false)
	
	# West wall
	_spawn_wall(center + Vector2(-half_w, 0), Vector2(wall_thick, room_size.y), "BRICK", false)
	
	# East wall
	_spawn_wall(center + Vector2(half_w, 0), Vector2(wall_thick, room_size.y), "BRICK", false)
	
	# Destructible wooden crate in doorway
	_spawn_wall(center + Vector2(0, -half_h), Vector2(70, wall_thick * 0.8), "WOOD_BARRIER", true, 45.0)

func _spawn_wall(pos: Vector2, wall_size: Vector2, type: String, destructible: bool, hp: float = 60.0) -> void:
	var wall = cover_wall_scene.instantiate()
	wall.global_position = pos
	add_child(wall)
	wall.setup_wall(type, wall_size, destructible, hp)

func _spawn_hiding_zone(pos: Vector2, type: String, radius: float) -> void:
	var zone = hiding_zone_scene.instantiate()
	zone.global_position = pos
	add_child(zone)
	zone.setup_zone(type, radius)

func _draw() -> void:
	var rect = Rect2(map_origin, Vector2(map_width, map_height))
	
	# High quality cartoonish texture rendering if ground texture exists
	if ground_tex != null:
		draw_texture_rect_region(
			ground_tex,
			rect,
			Rect2(Vector2.ZERO, Vector2(map_width, map_height))
		)
	else:
		# Vibrant cartoonish muddy dirt floor base
		draw_rect(rect, Color(0.26, 0.18, 0.12))
		
		# Cartoonish dirt patches & path accents
		var patch_step = 160.0
		var x = map_origin.x
		while x < map_origin.x + map_width:
			var y = map_origin.y
			while y < map_origin.y + map_height:
				var hash_val = int(abs(sin(x * 0.01 + y * 0.02) * 100.0)) % 4
				if hash_val == 0:
					# Cartoon grass spot
					draw_circle(Vector2(x + 40, y + 40), 28.0, Color(0.22, 0.48, 0.18, 0.65))
				elif hash_val == 1:
					# Cartoon pebble spot
					draw_circle(Vector2(x + 30, y + 50), 12.0, Color(0.42, 0.35, 0.28, 0.5))
				elif hash_val == 2:
					# Dark mud patch
					draw_circle(Vector2(x + 60, y + 30), 35.0, Color(0.18, 0.12, 0.08, 0.55))
				y += patch_step
			x += patch_step
			
		# Stylized cartoonish grid lines
		var step = 150.0
		var gx = map_origin.x
		while gx < map_origin.x + map_width:
			draw_line(Vector2(gx, map_origin.y), Vector2(gx, map_origin.y + map_height), Color(0.35, 0.26, 0.18, 0.3), 1.5)
			gx += step
			
		var gy = map_origin.y
		while gy < map_origin.y + map_height:
			draw_line(Vector2(map_origin.x, gy), Vector2(map_origin.x + map_width, gy), Color(0.35, 0.26, 0.18, 0.3), 1.5)
			gy += step
			
	# Outer compound vibrant glowing border wall
	var outer_rect = Rect2(map_origin + Vector2(24, 24), Vector2(map_width - 48, map_height - 48))
	draw_rect(outer_rect, Color(1.0, 0.3, 0.1, 0.75), false, 5.0)
