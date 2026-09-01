extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	World.build_overworld_map(tilemap)

	# Spawn just outside the village's south gate, matching roughly where the
	# JS game's house/village sits relative to the player's usual start.
	var spawn_tile: Vector2i = World.VILLAGE_GATES.south + Vector2i(0, 2)
	player.position = Vector2(spawn_tile.x * 32 + 16, spawn_tile.y * 32 + 16)

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = World.OVERWORLD_WIDTH * 32
	cam.limit_bottom = World.OVERWORLD_HEIGHT * 32
	# Without this the camera's smoothing tries to glide in from wherever it
	# was before the player was repositioned above (e.g. (0,0) on first
	# spawn), showing the wrong part of the map for the first several
	# frames — reset_smoothing() snaps it straight to the new position
	# instead. Also needed at every future teleport (portals, fast travel).
	cam.reset_smoothing()
