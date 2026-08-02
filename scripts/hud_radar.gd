extends Control

var map_size: float = 3000.0
var minimap_size: Vector2 = Vector2(160, 160)

func _ready() -> void:
	custom_minimum_size = minimap_size

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Draw Minimap background
	var rect = Rect2(Vector2.ZERO, minimap_size)
	draw_rect(rect, Color(0.04, 0.06, 0.1, 0.85))
	draw_rect(rect, Color(0.2, 0.8, 1.0, 0.8), false, 2.0)
	
	# World position to Minimap vector converter
	var scale_factor = minimap_size.x / map_size
	var map_center = minimap_size * 0.5
	
	# Draw Hiding Foliage spots on minimap
	var foliage_spots = [
		Vector2(0, 0), Vector2(-450, 0), Vector2(450, 0), Vector2(0, -450), Vector2(0, 450),
		Vector2(-1200, -500), Vector2(-1200, 500), Vector2(1200, -500), Vector2(1200, 500)
	]
	for spot in foliage_spots:
		var mini_pos = map_center + spot * scale_factor
		draw_circle(mini_pos, 4.0, Color(0.15, 0.6, 0.2, 0.5))
		
	# Draw Alive Combatant Dots
	for combatant in GameManager.alive_combatants:
		if not is_instance_valid(combatant) or combatant.is_queued_for_deletion():
			continue
			
		var mini_pos = map_center + combatant.global_position * scale_factor
		mini_pos.x = clamp(mini_pos.x, 4.0, minimap_size.x - 4.0)
		mini_pos.y = clamp(mini_pos.y, 4.0, minimap_size.y - 4.0)
		
		if combatant == GameManager.player_node:
			# Local Player: Glowing Cyan Dot
			draw_circle(mini_pos, 4.5, Color(0.1, 0.9, 1.0))
			draw_circle(mini_pos, 2.0, Color.WHITE)
		else:
			var is_hidden_target = ("is_hidden" in combatant) and combatant.is_hidden
			if not is_hidden_target:
				var is_human = ("peer_id" in combatant) and combatant.peer_id > 0
				if is_human:
					# Remote Human Player: Gold Dot
					draw_circle(mini_pos, 4.0, Color(1.0, 0.85, 0.2))
				else:
					# AI Bot: Crimson Red Dot
					draw_circle(mini_pos, 3.5, Color(1.0, 0.25, 0.2))
