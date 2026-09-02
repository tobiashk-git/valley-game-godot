extends Node2D
# Placeholder shape for the Emberfall Badlands interior's entrance - a small
# cracked-rock cone with a glowing fissure, same "hand-drawn shape, no real
# sprite" convention as watchtower_entrance.gd/druid_circle_entrance.gd.

func _draw() -> void:
	var cone := PackedVector2Array([
		Vector2(-14, 4), Vector2(-8, -18), Vector2(0, -24), Vector2(8, -18), Vector2(14, 4),
	])
	draw_colored_polygon(cone, Color("#3a2c26")) # dark volcanic rock
	var fissure := PackedVector2Array([
		Vector2(-2, -20), Vector2(2, -20), Vector2(3, -2), Vector2(-3, -2),
	])
	draw_colored_polygon(fissure, Color(0.95, 0.45, 0.1, 0.9)) # glowing orange fissure - simple convex sliver
	draw_circle(Vector2(0, -2), 3, Color(1.0, 0.7, 0.2, 0.85)) # ember accent at the base
