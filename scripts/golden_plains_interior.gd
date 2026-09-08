extends "res://scripts/maze_interior.gd"
# The Ancient Barrow - chapter 1's teaching dungeon (2026-09-08): no hazard
# tiles, but a few encounters from the dungeon pool on new ground (the
# lesson: dungeons bite), the fog, the two chests, and the Barrow Warden,
# tuned so the full leather set is needed to put it to sleep.

func _process(_delta: float) -> void:
	_step(true)
