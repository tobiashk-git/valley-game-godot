extends Node2D
# Oliver's own house interior — port of the hand-placed furniture layout in
# world.js's World 1 house block (11x9 room, door at (5,8)). Chest is a
# visual/solid prop only for now — no storage/inventory UI ported yet.

const WIDTH := 11
const HEIGHT := 9
const DOOR_TILE := Vector2i(5, 8)

# Painted room shell (Leonardo, Stardew-style straight-on interior): walls,
# windows, skirting and floor as one picture laid over the tile map, which
# keeps providing the collision. Props stay separate, y-sorted nodes.
const ROOM_SHELL := "res://assets/interiors/house_shell.png"
const BED_SCENE := preload("res://scenes/props/Bed.tscn")
# Where Oliver comes to after a nap (a lost fight): the floor tile right of
# his bed (the bed stands at (2, 4)).
const NAP_SPAWN_TILE := Vector2i(3, 4)
const CHAIR_SCENE := preload("res://scenes/props/Chair.tscn")
const TABLE_SCENE := preload("res://scenes/props/Table.tscn")
const STOVE_SCENE := preload("res://scenes/props/Stove.tscn")
const CHEST_SCENE := preload("res://scenes/props/Chest.tscn")

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Player
@onready var out_portal: Area2D = $OutPortal

func _tile_center(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * 32 + 16, pos.y * 32 + 16)

func _spawn_prop(scene: PackedScene, tile_pos: Vector2i) -> void:
	var instance: Node2D = scene.instantiate()
	instance.position = _tile_center(tile_pos)
	ysort.add_child(instance)

func _ready() -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var on_border: bool = x == 0 or x == WIDTH - 1 or y == 0 or y == HEIGHT - 1
			terrain.set_cell(Vector2i(x, y), 0 if on_border else 1, Vector2i(0, 0)) # 0=wall,1=floor

	terrain.set_cell(Vector2i(0, 6), 2, Vector2i(0, 0)) # window, west wall
	terrain.set_cell(Vector2i(0, 7), 2, Vector2i(0, 0))
	terrain.set_cell(Vector2i(10, 3), 2, Vector2i(0, 0)) # window, east wall
	terrain.set_cell(Vector2i(10, 4), 2, Vector2i(0, 0))
	terrain.set_cell(DOOR_TILE, 1, Vector2i(0, 0)) # door is walkable floor
	if ResourceLoader.exists(ROOM_SHELL):
		var shell := Sprite2D.new()
		shell.name = "RoomShell"
		shell.texture = load(ROOM_SHELL)
		shell.centered = false
		add_child(shell)
		move_child(shell, terrain.get_index() + 1) # over the tiles, under the props

	# The door is a hole carved into the border wall, with nothing at all
	# beyond it (no wall, no floor) - without a blocker here the player can
	# just keep walking straight through into that undefined void, drifting
	# out of the OutPortal's trigger range with no way back except
	# backtracking north onto the door tile and pressing E. This invisible
	# blocker stops them right at the threshold instead, one tile past the
	# door — they can still stand on the door tile itself (where the portal
	# is) and press E normally.
	var door_blocker := StaticBody2D.new()
	door_blocker.position = _tile_center(DOOR_TILE + Vector2i(0, 1))
	var blocker_shape := CollisionShape2D.new()
	var blocker_rect := RectangleShape2D.new()
	blocker_rect.size = Vector2(32, 32)
	blocker_shape.shape = blocker_rect
	door_blocker.add_child(blocker_shape)
	add_child(door_blocker)

	_spawn_prop(BED_SCENE, Vector2i(2, 4))
	_spawn_prop(STOVE_SCENE, Vector2i(8, 2)) # standing on the painted skirting under the right window
	_spawn_prop(TABLE_SCENE, Vector2i(8, 5))
	_spawn_prop(CHAIR_SCENE, Vector2i(8, 4))
	_spawn_prop(CHAIR_SCENE, Vector2i(8, 6))
	_spawn_prop(CHEST_SCENE, Vector2i(2, 6))

	if not GameState.consume_next_spawn(player):
		player.position = _tile_center(DOOR_TILE + Vector2i(0, -1))

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = WIDTH * 32
	cam.limit_bottom = HEIGHT * 32
	cam.reset_smoothing()

	# A brand-new game opens here: Oliver's first morning (see intro.gd).
	if GameState.intro_pending:
		Intro.play(player)

	out_portal.position = _tile_center(DOOR_TILE)
	out_portal.target_scene = "res://scenes/Overworld.tscn"
	out_portal.target_spawn = Vector2(World.HOUSE_ENTRANCE.x * 32 + 16, (World.HOUSE_ENTRANCE.y + 1) * 32 + 16)
