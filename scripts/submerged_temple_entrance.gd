extends Node2D
# Placeholder shape for the Gloomfen Marsh interior's entrance - a
# moss-covered stone archway with dripping water accents, same "hand-drawn
# shape, no real sprite" convention as watchtower_entrance.gd/
# druid_circle_entrance.gd/volcano_entrance.gd. Each piece is kept simple/
# convex per the watchtower-entrance triangulation-crash lesson.

func _draw() -> void:
	var left_pillar := PackedVector2Array([
		Vector2(-14, 6), Vector2(-14, -20), Vector2(-6, -20), Vector2(-6, 6),
	])
	draw_colored_polygon(left_pillar, Color("#4a5245")) # dark mossy stone
	var right_pillar := PackedVector2Array([
		Vector2(6, 6), Vector2(6, -20), Vector2(14, -20), Vector2(14, 6),
	])
	draw_colored_polygon(right_pillar, Color("#4a5245"))
	var lintel := PackedVector2Array([
		Vector2(-16, -20), Vector2(16, -20), Vector2(14, -26), Vector2(-14, -26),
	])
	draw_colored_polygon(lintel, Color("#3c443a")) # darker capstone
	var moss := PackedVector2Array([
		Vector2(-14, -20), Vector2(-6, -20), Vector2(-8, -12), Vector2(-13, -10),
	])
	draw_colored_polygon(moss, Color(0.35, 0.5, 0.3, 0.85)) # moss patch, simple convex sliver
	draw_circle(Vector2(-2, 4), 2, Color(0.4, 0.55, 0.6, 0.8)) # dripping water accent
	draw_circle(Vector2(3, 6), 1.5, Color(0.4, 0.55, 0.6, 0.6))
