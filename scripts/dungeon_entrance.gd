extends Node2D
# Placeholder shape, matching how drawDungeonEntrance() in the JS game is
# also just a hand-drawn shape (never got a real sprite there either) — a
# simple dark archway, not attempting to replicate the exact bezier curve.

func _draw() -> void:
	draw_circle(Vector2(0, -20), 15, Color("#4a4a4a"))
	draw_rect(Rect2(-15, -20, 30, 26), Color("#4a4a4a"))
	draw_circle(Vector2(0, -16), 10, Color("#0a0a0a"))
	draw_rect(Rect2(-10, -16, 20, 22), Color("#0a0a0a"))
