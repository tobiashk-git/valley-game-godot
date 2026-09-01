extends Node2D

const TREE_SCENE := preload("res://scenes/props/Tree.tscn")
const ROCK_SCENE := preload("res://scenes/props/Rock.tscn")
const HOUSE_ENTRANCE_SCENE := preload("res://scenes/props/HouseEntrance.tscn")
const DUNGEON_ENTRANCE_SCENE := preload("res://scenes/props/DungeonEntrance.tscn")
const CASTLE_ENTRANCE_SCENE := preload("res://scenes/props/CastleEntrance.tscn")
const PORTAL_SCENE := preload("res://scenes/Portal.tscn")

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Player

func _tile_center(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * 32 + 16, pos.y * 32 + 16)

func _spawn_prop(scene: PackedScene, tile_pos: Vector2i) -> void:
	var instance: Node2D = scene.instantiate()
	instance.position = _tile_center(tile_pos)
	ysort.add_child(instance)

# The house entrance tile itself is solid (the HouseEntrance prop blocks it),
# so the player is always standing on an *adjacent* tile when "at" the
# house — size this bigger than one tile so it still triggers.
func _add_house_entrance(entrance_tile: Vector2i, target_scene: String, target_spawn: Vector2) -> void:
	_spawn_prop(HOUSE_ENTRANCE_SCENE, entrance_tile)
	var portal: Area2D = PORTAL_SCENE.instantiate()
	portal.position = _tile_center(entrance_tile)
	portal.get_node("CollisionShape2D").shape.size = Vector2(56, 56)
	portal.target_scene = target_scene
	portal.target_spawn = target_spawn
	add_child(portal)

func _ready() -> void:
	World.build_overworld_map(tilemap)
	if GameState.village_gates_open:
		World.open_gates(tilemap)

	for entry in World.scatter_trees_and_rocks(tilemap):
		var scene: PackedScene = TREE_SCENE if entry.scene == "Tree" else ROCK_SCENE
		_spawn_prop(scene, entry.pos)

	_spawn_prop(DUNGEON_ENTRANCE_SCENE, World.DUNGEON_ENTRANCE)
	_spawn_prop(CASTLE_ENTRANCE_SCENE, World.CASTLE_ENTRANCE)

	# House.tscn/VillageHouse door tiles are at (5,8) and (4,6) respectively —
	# target spawn is always the tile just inside the door (one row up).
	_add_house_entrance(World.HOUSE_ENTRANCE, "res://scenes/House.tscn", Vector2(5 * 32 + 16, 7 * 32 + 16))
	_add_house_entrance(World.ELDER_HOUSE_ENTRANCE, "res://scenes/ElderHouse.tscn", Vector2(4 * 32 + 16, 5 * 32 + 16))
	_add_house_entrance(World.TRADER_HOUSE_ENTRANCE, "res://scenes/TraderHouse.tscn", Vector2(4 * 32 + 16, 5 * 32 + 16))
	_add_house_entrance(World.EMPTY_HOUSE_ENTRANCE, "res://scenes/EmptyHouse.tscn", Vector2(4 * 32 + 16, 5 * 32 + 16))

	# Spawn just inside the village's south gate. The 4 gates start solid
	# (fence/gates tutorial - see quests.gd's meet_villagers), so a spawn
	# point outside the ring would strand a fresh player with no way in.
	var spawn_tile: Vector2i = World.VILLAGE_GATES.south + Vector2i(0, -2)
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
