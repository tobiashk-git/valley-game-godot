extends Node2D
# Placeholder shape for the Verdantwood interior's entrance - a small ring
# of standing stones with a mossy/vine accent, same "hand-drawn shape, no
# real sprite" convention as dungeon_entrance.gd/watchtower_entrance.gd.

func _draw() -> void:
	var stone_positions := [
		Vector2(-14, -8), Vector2(-7, -18), Vector2(7, -18), Vector2(14, -8),
		Vector2(9, 2), Vector2(-9, 2),
	]
	for pos in stone_positions:
		draw_rect(Rect2(pos.x - 4, pos.y - 10, 8, 12), Color("#6b6559"))
	draw_circle(Vector2(0, -6), 5, Color(0.35, 0.55, 0.3, 0.6)) # moss/vine accent, center of the circle
