extends Node2D
# Placeholder shape, matching how drawCastleEntrance() in the JS game is also
# just hand-drawn rects (never got a real sprite there either) — a simple
# tan gatehouse with two flanking towers.

func _draw() -> void:
	draw_rect(Rect2(-13, -22, 26, 28), Color("#9a8a6a"))
	draw_rect(Rect2(-16, -28, 8, 14), Color("#7a6a4a"))
	draw_rect(Rect2(8, -28, 8, 14), Color("#7a6a4a"))
	draw_rect(Rect2(-4, -8, 8, 14), Color("#3a2a1a"))
	draw_rect(Rect2(-14, -34, 6, 6), Color("#c0392b"))
