extends Node2D
# Placeholder shape for Golden Plains' interior entrance - a low earthen
# burial mound with a dark doorway cut into it, same "hand-drawn shape, no
# real sprite" convention as watchtower_entrance.gd/druid_circle_entrance.gd/
# volcano_entrance.gd/submerged_temple_entrance.gd. Each piece is kept
# simple/convex per the watchtower-entrance triangulation-crash lesson.

func _draw() -> void:
	var mound := PackedVector2Array([
		Vector2(-16, 6), Vector2(-14, -8), Vector2(-6, -16), Vector2(6, -16), Vector2(14, -8), Vector2(16, 6),
	])
	draw_colored_polygon(mound, Color("#7a6a45")) # weathered earthen mound
	var grass_cap := PackedVector2Array([
		Vector2(-14, -8), Vector2(-6, -16), Vector2(6, -16), Vector2(14, -8), Vector2(10, -6), Vector2(-10, -6),
	])
	draw_colored_polygon(grass_cap, Color(0.45, 0.55, 0.25, 1.0)) # grassy cap, simple convex sliver
	var doorway := PackedVector2Array([
		Vector2(-5, 6), Vector2(-5, -4), Vector2(5, -4), Vector2(5, 6),
	])
	draw_colored_polygon(doorway, Color(0.08, 0.07, 0.06, 1.0)) # dark doorway into the barrow
