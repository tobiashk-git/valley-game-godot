extends Node2D

const TREE_SCENE := preload("res://scenes/props/Tree.tscn")
const ROCK_SCENE := preload("res://scenes/props/Rock.tscn")
const HOUSE_ENTRANCE_SCENE := preload("res://scenes/props/HouseEntrance.tscn")
const DUNGEON_ENTRANCE_SCENE := preload("res://scenes/props/DungeonEntrance.tscn")
const CASTLE_ENTRANCE_SCENE := preload("res://scenes/props/CastleEntrance.tscn")
const WATCHTOWER_RUIN_ENTRANCE_SCENE := preload("res://scenes/props/WatchtowerRuinEntrance.tscn")
const DRUID_CIRCLE_ENTRANCE_SCENE := preload("res://scenes/props/DruidCircleEntrance.tscn")
const VOLCANO_ENTRANCE_SCENE := preload("res://scenes/props/VolcanoEntrance.tscn")
const SUBMERGED_TEMPLE_ENTRANCE_SCENE := preload("res://scenes/props/SubmergedTempleEntrance.tscn")
const ANCIENT_BARROW_ENTRANCE_SCENE := preload("res://scenes/props/AncientBarrowEntrance.tscn")
const MIGHTY_OAK_SCENE := preload("res://scenes/props/MightyOak.tscn")
const ICE_BOULDER_SCENE := preload("res://scenes/props/IceBoulder.tscn")
const ICE_CRYSTAL_SHARD_SCENE := preload("res://scenes/props/IceCrystalShard.tscn")
const ICE_POOL_SCENE := preload("res://scenes/props/IcePool.tscn")
const FALLEN_LOG_SCENE := preload("res://scenes/props/FallenLog.tscn")
const TANGLED_BUSH_SCENE := preload("res://scenes/props/TangledBush.tscn")
const SWAMP_TREE_SCENE := preload("res://scenes/props/SwampTree.tscn")
const SWAMP_FERNS_SCENE := preload("res://scenes/props/SwampFerns.tscn")
const SWAMP_MUSHROOMS_SCENE := preload("res://scenes/props/SwampMushrooms.tscn")
const BADLANDS_PALMS_SCENE := preload("res://scenes/props/BadlandsPalms.tscn")
const BADLANDS_FIRE_GEYSER_SCENE := preload("res://scenes/props/BadlandsFireGeyser.tscn")
const BADLANDS_TUMBLEWEED_SCENE := preload("res://scenes/props/BadlandsTumbleweed.tscn")
const NPC_SCENE := preload("res://scenes/props/NPC.tscn")
const PORTAL_SCENE := preload("res://scenes/Portal.tscn")
const ALTAR_TRIGGER_SCRIPT := preload("res://scripts/altar_trigger.gd")

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Player

var _final_boss_entrance_spawned := false
var _golden_plains_entrance_spawned := false
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

# Same reveal-on-completion pattern as reveal_final_boss_entrance() above -
# called once from _ready() below if GameState.world_progress already has it
# revealed. Golden Plains IS the valley (no ford to physically block it), so
# unlike the other 4 biome interiors, the entrance simply doesn't exist at
# all until the open_ancient_barrow quest completes - the quest completes
# while the player is inside TraderHouse.tscn, not this live scene, so there's
# no need for a direct cross-scene call here.
func reveal_golden_plains_entrance() -> void:
	if _golden_plains_entrance_spawned:
		return
	_golden_plains_entrance_spawned = true
	_add_entrance(ANCIENT_BARROW_ENTRANCE_SCENE, World.GOLDEN_PLAINS_INTERIOR_ENTRANCE, "res://scenes/GoldenPlainsInterior.tscn", Vector2.ZERO)

# Repaints every ford whose GameState flag is already true - safe to call
# repeatedly (repainting an already-open tile is a harmless no-op). Called
# once from _ready() (the state may already be true on a scene reload), and
# again on every Quests.changed signal (see _ready()'s connect below) - a
# housed quest-giver (Elder/Trader/Frostpeak Ranger) always reaches this via
# a fresh _ready() anyway, since turning in their quest and then leaving the
# house reloads Overworld.tscn - but a STANDALONE NPC (Druid/Prospector/Guide)
# stands directly in this already-live scene, so completing their quest
# doesn't reload anything at all. Without this signal connection the ford
# flag flips correctly but the tile the player is standing right next to
# stays solid until they happen to leave and re-enter the Overworld some
# other way (fast travel, a house visit) - reported directly by the user as
# "the bridge does not appear" after turning in a quest.
func _repaint_open_paths() -> void:
	for zone in ZONE_KEYS:
		if GameState.biome_paths_open[ZONE_KEYS[zone]]:
			World.open_biome_path(tilemap, zone)

func _on_quests_changed() -> void:
	_repaint_open_paths()

func _ready() -> void:
	World.build_overworld_map(tilemap)
	World.add_world_boundary(self)
	if GameState.village_gates_open:
		World.open_gates(tilemap)
	_repaint_open_paths()
	Quests.changed.connect(_on_quests_changed)

	for entry in World.scatter_trees_and_rocks(tilemap):
		var scene: PackedScene = TREE_SCENE if entry.scene == "Tree" else ROCK_SCENE
		_spawn_prop(scene, entry.pos)

	# Lakes paint before obstacles scatter - a scattered prop's ground_source
	# check (tilemap.get_cell_source_id(pos) != ground_source) automatically
	# excludes any tile a lake already claimed, the same way mountain/river
	# tiles are already excluded for free, but only if the lake painted
	# first. Getting this backwards would let a tree land on top of water.
	World.scatter_biome_lakes(tilemap)
	var obstacle_scenes := {
		"MightyOak": MIGHTY_OAK_SCENE,
		"IceBoulder": ICE_BOULDER_SCENE,
		"IceCrystalShard": ICE_CRYSTAL_SHARD_SCENE,
		"IcePool": ICE_POOL_SCENE,
		"FallenLog": FALLEN_LOG_SCENE,
		"TangledBush": TANGLED_BUSH_SCENE,
		"SwampTree": SWAMP_TREE_SCENE,
		"SwampFerns": SWAMP_FERNS_SCENE,
		"SwampMushrooms": SWAMP_MUSHROOMS_SCENE,
		"BadlandsPalms": BADLANDS_PALMS_SCENE,
		"BadlandsFireGeyser": BADLANDS_FIRE_GEYSER_SCENE,
		"BadlandsTumbleweed": BADLANDS_TUMBLEWEED_SCENE,
	}
	for entry in World.scatter_biome_obstacles(tilemap):
		_spawn_prop(obstacle_scenes[entry.scene], entry.pos)

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
	# No conditional gating needed here - the closed ford (see biome_paths_open
	# above) already physically blocks reaching this entrance until the
	# cross_frostpeak quest opens it.
	_add_entrance(WATCHTOWER_RUIN_ENTRANCE_SCENE, World.FROSTPEAK_INTERIOR_ENTRANCE, "res://scenes/FrostpeakInterior.tscn", Vector2.ZERO)
	_add_entrance(DRUID_CIRCLE_ENTRANCE_SCENE, World.VERDANTWOOD_INTERIOR_ENTRANCE, "res://scenes/VerdantwoodInterior.tscn", Vector2.ZERO)
	_add_entrance(VOLCANO_ENTRANCE_SCENE, World.BADLANDS_INTERIOR_ENTRANCE, "res://scenes/BadlandsInterior.tscn", Vector2.ZERO)
	_add_entrance(SUBMERGED_TEMPLE_ENTRANCE_SCENE, World.GLOOMFEN_INTERIOR_ENTRANCE, "res://scenes/GloomfenInterior.tscn", Vector2.ZERO)
	if GameState.world_progress.final_boss_revealed:
		reveal_final_boss_entrance()
	if GameState.world_progress.golden_plains_revealed:
		reveal_golden_plains_entrance()

	# The Verdantwood ford-crossing quest giver - unlike the Frostpeak
	# Ranger (housed in EmptyHouse.tscn, Phase 2's only empty village slot),
	# this one stands directly in the valley near the ford itself, a few
	# tiles off the direct crossing line so it doesn't block the path.
	var druid: StaticBody2D = NPC_SCENE.instantiate()
	druid.position = _tile_center(World.DRUID_GLADE_POS)
	druid.sprite_path = "res://assets/elder.png"
	druid.sprite_tint = Color(0.55, 0.75, 0.4, 1.0)
	druid.npc_name = "Forest Druid"
	druid.quest_id = "cross_verdantwood"
	druid.npc_id = "forest_druid"
	druid.intro_text = "You've wandered far from the village. Verdantwood lies beyond that ford - if you can call it a ford anymore. The old crossing's overgrown; I could use a hand clearing it."
	ysort.add_child(druid)

	# The Badlands ford-crossing quest giver - same standalone pattern as the Druid.
	var prospector: StaticBody2D = NPC_SCENE.instantiate()
	prospector.position = _tile_center(World.PROSPECTOR_CAMP_POS)
	prospector.sprite_path = "res://assets/trader.png"
	prospector.sprite_tint = Color(0.75, 0.45, 0.25, 1.0)
	prospector.npc_name = "Badlands Prospector"
	prospector.quest_id = "cross_badlands"
	prospector.npc_id = "badlands_prospector"
	prospector.intro_text = "Emberfall's past that ford - if the heat don't get you, the ground giving way underfoot will. I've been meaning to shore up the crossing, just need the stone for it."
	ysort.add_child(prospector)

	# The Gloomfen ford-crossing quest giver - same standalone pattern as the Druid/Prospector.
	var guide: StaticBody2D = NPC_SCENE.instantiate()
	guide.position = _tile_center(World.MARSH_GUIDE_POS)
	guide.sprite_path = "res://assets/elder.png"
	guide.sprite_tint = Color(0.35, 0.42, 0.32, 1.0)
	guide.npc_name = "Marsh Guide"
	guide.quest_id = "cross_gloomfen"
	guide.npc_id = "marsh_guide"
	guide.intro_text = "Gloomfen's past that ford, if you can call it that anymore - the old boards rotted through years back. Bring me wood and I'll lay a new crossing."
	ysort.add_child(guide)

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
