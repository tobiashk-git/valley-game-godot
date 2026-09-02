extends Node2D
# Placeholder shape for the Frostpeak Ridge interior's entrance - a ruined
# watchtower, same "hand-drawn shape, no real sprite" convention as
# dungeon_entrance.gd/castle_entrance.gd. A weathered stone shaft on a wider
# rubble base, a jagged broken top instead of a roof, and a small pale
# ice-crystal accent to tie it to the biome.

func _draw() -> void:
	draw_rect(Rect2(-8, -28, 16, 30), Color("#5a6470")) # tower shaft
	draw_rect(Rect2(-14, -2, 28, 10), Color("#4a5460")) # rubble base
	var jagged := PackedVector2Array([
		Vector2(-8, -28), Vector2(-8, -34), Vector2(-3, -30), Vector2(2, -36), Vector2(8, -30), Vector2(8, -28),
	])
	draw_colored_polygon(jagged, Color("#3f4854")) # broken top
	draw_circle(Vector2(0, -18), 4, Color(0.75, 0.9, 1.0, 0.85)) # ice crystal accent
