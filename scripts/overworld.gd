extends Node2D

const TREE_SCENE := preload("res://scenes/props/Tree.tscn")
const ROCK_SCENE := preload("res://scenes/props/Rock.tscn")
const HOUSE_ENTRANCE_SCENE := preload("res://scenes/props/HouseEntrance.tscn")
const DUNGEON_ENTRANCE_SCENE := preload("res://scenes/props/DungeonEntrance.tscn")
const CASTLE_ENTRANCE_SCENE := preload("res://scenes/props/CastleEntrance.tscn")
const PORTAL_SCENE := preload("res://scenes/Portal.tscn")
const ALTAR_TRIGGER_SCRIPT := preload("res://scripts/altar_trigger.gd")

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Player

var _final_boss_entrance_spawned := false
var _last_tile := Vector2i(-9999, -9999)

const ZONE_KEYS := {
	World.Zone.FROSTPEAK: "frostpeak",
	World.Zone.VERDANTWOOD: "verdantwood",
	World.Zone.BADLANDS: "badlands",
	World.Zone.GLOOMFEN: "gloomfen",
}

func _tile_center(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * 32 + 16, pos.y * 32 + 16)

func _spawn_prop(scene: PackedScene, tile_pos: Vector2i) -> void:
	var instance: Node2D = scene.instantiate()
	instance.position = _tile_center(tile_pos)
	ysort.add_child(instance)

# The entrance tile itself is solid (the prop blocks it), so the player is
# always standing on an *adjacent* tile when "at" the entrance — size this
# bigger than one tile so it still triggers.
func _add_entrance(prop_scene: PackedScene, entrance_tile: Vector2i, target_scene: String, target_spawn: Vector2) -> void:
	_spawn_prop(prop_scene, entrance_tile)
	var portal: Area2D = PORTAL_SCENE.instantiate()
	portal.position = _tile_center(entrance_tile)
	portal.get_node("CollisionShape2D").shape.size = Vector2(56, 56)
	portal.target_scene = target_scene
	portal.target_spawn = target_spawn
	add_child(portal)

# Called once by Altar.gd the moment 2 Magic Crystals reveal it, and again
# from _ready() on every later visit once GameState.world_progress already
# has it revealed — reuses DungeonEntrance's arch prop (no unique art for
# "a hidden path" exists), leading to FinalBoss.tscn.
func reveal_final_boss_entrance() -> void:
	if _final_boss_entrance_spawned:
		return
	_final_boss_entrance_spawned = true
	_add_entrance(DUNGEON_ENTRANCE_SCENE, World.FINAL_BOSS_ENTRANCE, "res://scenes/FinalBoss.tscn", Vector2.ZERO)

func _ready() -> void:
	World.build_overworld_map(tilemap)
	World.add_world_boundary(self)
	if GameState.village_gates_open:
		World.open_gates(tilemap)
	for zone in ZONE_KEYS:
		if GameState.biome_paths_open[ZONE_KEYS[zone]]:
			World.open_biome_path(tilemap, zone)

	for entry in World.scatter_trees_and_rocks(tilemap):
		var scene: PackedScene = TREE_SCENE if entry.scene == "Tree" else ROCK_SCENE
		_spawn_prop(scene, entry.pos)

	# House.tscn/VillageHouse door tiles are at (5,8) and (4,6) respectively —
	# target spawn is always the tile just inside the door (one row up).
	_add_entrance(HOUSE_ENTRANCE_SCENE, World.HOUSE_ENTRANCE, "res://scenes/House.tscn", Vector2(5 * 32 + 16, 7 * 32 + 16))
	_add_entrance(HOUSE_ENTRANCE_SCENE, World.ELDER_HOUSE_ENTRANCE, "res://scenes/ElderHouse.tscn", Vector2(4 * 32 + 16, 5 * 32 + 16))
	_add_entrance(HOUSE_ENTRANCE_SCENE, World.TRADER_HOUSE_ENTRANCE, "res://scenes/TraderHouse.tscn", Vector2(4 * 32 + 16, 5 * 32 + 16))
	_add_entrance(HOUSE_ENTRANCE_SCENE, World.EMPTY_HOUSE_ENTRANCE, "res://scenes/EmptyHouse.tscn", Vector2(4 * 32 + 16, 5 * 32 + 16))
	# Dungeon.tscn/Castle.tscn/FinalBoss.tscn all regenerate their maze fresh
	# every visit and always spawn the player at their own entrance, so the
	# target_spawn passed here is unused.
	_add_entrance(DUNGEON_ENTRANCE_SCENE, World.DUNGEON_ENTRANCE, "res://scenes/Dungeon.tscn", Vector2.ZERO)
	_add_entrance(CASTLE_ENTRANCE_SCENE, World.CASTLE_ENTRANCE, "res://scenes/Castle.tscn", Vector2.ZERO)
	if GameState.world_progress.final_boss_revealed:
		reveal_final_boss_entrance()

	# The altar tile (painted solid by build_overworld_map()) just needs an
	# interact trigger on top of it - it isn't a separate prop/scene like
	# the entrances above.
	var altar_trigger := Area2D.new()
	altar_trigger.position = _tile_center(World.ALTAR_POS)
	altar_trigger.set_script(ALTAR_TRIGGER_SCRIPT)
	var altar_shape := CollisionShape2D.new()
	var altar_rect := RectangleShape2D.new()
	# The altar tile is solid, so the player can only ever stand one full
	# adjacent tile away (32px) - matching _add_entrance()'s 56x56 sizing
	# for the same reason, not the smaller 48x48 used by NPCs/chests/
	# gatherables (which the player can approach more closely).
	altar_rect.size = Vector2(56, 56)
	altar_shape.shape = altar_rect
	altar_trigger.add_child(altar_shape)
	add_child(altar_trigger)

	if not GameState.consume_next_spawn(player):
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

# The biome revamp's random encounters - the open overworld had none at all
# before this (Combat.check_random_encounter() was only ever called from
# maze_interior.gd). Golden Plains (Zone.VALLEY, which includes the village)
# stays encounter-free by simply never calling it there - no special-casing
# needed beyond the guard below, and it's what keeps the existing "walk many
# steps across the village, confirm zero encounters" test passing unchanged.
func _process(_delta: float) -> void:
	var current_tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if current_tile != _last_tile:
		_last_tile = current_tile
		var zone: int = World.biome_at(current_tile.x, current_tile.y).zone
		if zone != World.Zone.VALLEY:
			Combat.check_random_encounter(zone)
