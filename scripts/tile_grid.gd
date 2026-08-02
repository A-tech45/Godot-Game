extends Node2D

enum TileState { NORMAL, CRACKED, COLLAPSED }

class ArenaTileCell:
	var state: TileState = TileState.NORMAL
	var crack_timer: float = 0.0
	var shake_offset: Vector2 = Vector2.ZERO
	var crack_seed: float = 0.0

var width: int = 22
var height: int = 22
var tile_size: float = 64.0
var grid_origin: Vector2 = Vector2.ZERO

# 2D Array [x][y] storing ArenaTileCell
var grid: Array = []
var crack_duration: float = 1.4

func _ready() -> void:
	width = GameManager.grid_width
	height = GameManager.grid_height
	tile_size = GameManager.tile_size
	GameManager.current_tile_grid = self
	
	# Center grid around origin (0, 0)
	grid_origin = Vector2(-width * tile_size * 0.5, -height * tile_size * 0.5)
	_initialize_grid()
	_create_boundary_walls()

func _initialize_grid() -> void:
	grid.clear()
	for x in range(width):
		var column: Array = []
		for y in range(height):
			var tile := ArenaTileCell.new()
			tile.crack_seed = randf() * 100.0
			column.append(tile)
		grid.append(column)
	queue_redraw()

func _create_boundary_walls() -> void:
	var total_w = width * tile_size
	var total_h = height * tile_size
	var wall_thickness = 40.0
	
	# Static body to hold boundary collision shapes
	var wall_body = StaticBody2D.new()
	wall_body.name = "BoundaryWalls"
	wall_body.collision_layer = 1
	wall_body.collision_mask = 3
	add_child(wall_body)
	
	# Top Wall
	var top_shape = CollisionShape2D.new()
	var top_rect = RectangleShape2D.new()
	top_rect.size = Vector2(total_w + wall_thickness * 2, wall_thickness)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0, grid_origin.y - wall_thickness * 0.5)
	wall_body.add_child(top_shape)
	
	# Bottom Wall
	var bot_shape = CollisionShape2D.new()
	var bot_rect = RectangleShape2D.new()
	bot_rect.size = Vector2(total_w + wall_thickness * 2, wall_thickness)
	bot_shape.shape = bot_rect
	bot_shape.position = Vector2(0, grid_origin.y + total_h + wall_thickness * 0.5)
	wall_body.add_child(bot_shape)
	
	# Left Wall
	var left_shape = CollisionShape2D.new()
	var left_rect = RectangleShape2D.new()
	left_rect.size = Vector2(wall_thickness, total_h + wall_thickness * 2)
	left_shape.shape = left_rect
	left_shape.position = Vector2(grid_origin.x - wall_thickness * 0.5, 0)
	wall_body.add_child(left_shape)
	
	# Right Wall
	var right_shape = CollisionShape2D.new()
	var right_rect = RectangleShape2D.new()
	right_rect.size = Vector2(wall_thickness, total_h + wall_thickness * 2)
	right_shape.shape = right_rect
	right_shape.position = Vector2(grid_origin.x + total_w + wall_thickness * 0.5, 0)
	wall_body.add_child(right_shape)

func _process(delta: float) -> void:
	var needs_redraw := false
	
	for x in range(width):
		for y in range(height):
			var tile: ArenaTileCell = grid[x][y]
			if tile.state == TileState.CRACKED:
				tile.crack_timer -= delta
				tile.shake_offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
				needs_redraw = true
				
				if tile.crack_timer <= 0.0:
					tile.state = TileState.COLLAPSED
					tile.shake_offset = Vector2.ZERO
					SoundManager.play_tile_collapse()
					GameManager.request_camera_shake(7.0, 0.3)
					_spawn_collapse_debris(get_world_pos_for_cell(x, y))
					
	if needs_redraw:
		queue_redraw()

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos = world_pos - grid_origin
	var gx = int(floor(local_pos.x / tile_size))
	var gy = int(floor(local_pos.y / tile_size))
	return Vector2i(gx, gy)

func get_world_pos_for_cell(gx: int, gy: int) -> Vector2:
	return grid_origin + Vector2((gx + 0.5) * tile_size, (gy + 0.5) * tile_size)

func is_valid_cell(gx: int, gy: int) -> bool:
	return gx >= 0 and gx < width and gy >= 0 and gy < height

func is_pos_collapsed(world_pos: Vector2) -> bool:
	var cell = world_to_grid(world_pos)
	if not is_valid_cell(cell.x, cell.y):
		return true # Outside arena counts as void
	var tile: ArenaTileCell = grid[cell.x][cell.y]
	return tile.state == TileState.COLLAPSED

func get_tile_state(world_pos: Vector2) -> TileState:
	var cell = world_to_grid(world_pos)
	if not is_valid_cell(cell.x, cell.y):
		return TileState.COLLAPSED
	return grid[cell.x][cell.y].state

func crack_tile_at_world_pos(world_pos: Vector2, radius: int = 1) -> void:
	var center = world_to_grid(world_pos)
	var cracked_any := false
	
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var gx = center.x + dx
			var gy = center.y + dy
			if is_valid_cell(gx, gy):
				var tile: ArenaTileCell = grid[gx][gy]
				if tile.state == TileState.NORMAL:
					tile.state = TileState.CRACKED
					tile.crack_timer = crack_duration
					cracked_any = true
					_spawn_crack_sparks(get_world_pos_for_cell(gx, gy))
					
	if cracked_any:
		SoundManager.play_tile_crack()
		queue_redraw()

func _draw() -> void:
	# Draw background abyss underneath tiles
	var full_rect = Rect2(grid_origin - Vector2(100, 100), Vector2(width * tile_size + 200, height * tile_size + 200))
	draw_rect(full_rect, Color(0.04, 0.04, 0.08))
	
	for x in range(width):
		for y in range(height):
			var tile: ArenaTileCell = grid[x][y]
			var top_left = grid_origin + Vector2(x * tile_size, y * tile_size) + tile.shake_offset
			var cell_rect = Rect2(top_left, Vector2(tile_size - 2, tile_size - 2))
			
			match tile.state:
				TileState.NORMAL:
					# Dark futuristic slate tile with cyan border
					draw_rect(cell_rect, Color(0.12, 0.15, 0.22))
					draw_rect(cell_rect, Color(0.2, 0.4, 0.6, 0.4), false, 1.5)
					# Inner tile accent
					draw_circle(top_left + Vector2(tile_size * 0.5, tile_size * 0.5), 3.0, Color(0.25, 0.5, 0.7, 0.3))
					
				TileState.CRACKED:
					# Glowing orange/red danger state
					var pulse = 0.6 + 0.4 * sin(Engine.get_physics_frames() * 0.3)
					draw_rect(cell_rect, Color(0.6, 0.2, 0.05, pulse))
					draw_rect(cell_rect, Color(1.0, 0.4, 0.1), false, 2.0)
					
					# Draw procedural crack lines
					var center = top_left + Vector2(tile_size * 0.5, tile_size * 0.5)
					draw_line(center, top_left + Vector2(4, 8), Color(1.0, 0.8, 0.3), 2.0)
					draw_line(center, top_left + Vector2(tile_size - 6, 12), Color(1.0, 0.8, 0.3), 2.0)
					draw_line(center, top_left + Vector2(10, tile_size - 6), Color(1.0, 0.8, 0.3), 2.0)
					draw_line(center, top_left + Vector2(tile_size - 8, tile_size - 4), Color(1.0, 0.8, 0.3), 2.0)
					
				TileState.COLLAPSED:
					# Void hole with dark shadow and glowing outer rim
					draw_rect(cell_rect, Color(0.02, 0.02, 0.05))
					draw_rect(cell_rect, Color(0.9, 0.1, 0.2, 0.3), false, 1.0)
					
	# Draw glowing outer boundary energy barrier
	var outer_rect = Rect2(grid_origin, Vector2(width * tile_size, height * tile_size))
	var pulse_barrier = 0.8 + 0.2 * sin(Engine.get_physics_frames() * 0.2)
	draw_rect(outer_rect, Color(0.1, 0.8, 1.0, pulse_barrier), false, 4.0)

func _spawn_crack_sparks(pos: Vector2) -> void:
	var p = CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = 8
	p.lifetime = 0.3
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 100.0
	p.color = Color(1.0, 0.6, 0.1)
	add_child(p)
	
	var timer = get_tree().create_timer(0.4)
	timer.timeout.connect(p.queue_free)

func _spawn_collapse_debris(pos: Vector2) -> void:
	var p = CPUParticles2D.new()
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.5
	p.spread = 180.0
	p.gravity = Vector2(0, 150) # Fall downward
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(0.3, 0.35, 0.45)
	add_child(p)
	
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(p.queue_free)
