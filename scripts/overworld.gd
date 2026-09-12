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
const BOSS_SCENE := preload("res://scenes/props/Boss.tscn")
const WILD_MONSTER_SCENE := preload("res://scenes/props/WildMonster.tscn")
const NPC_SCENE := preload("res://scenes/props/NPC.tscn")
const PORTAL_SCENE := preload("res://scenes/Portal.tscn")
const ALTAR_TRIGGER_SCRIPT := preload("res://scripts/altar_trigger.gd")
const VILLAGE_GROUND := "res://assets/interiors/village_ground.png"

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Player

var _final_boss_entrance_spawned := false
var _golden_plains_entrance_spawned := false
var _last_tile := Vector2i(-9999, -9999)
var _verdantwood_maze_blocker: StaticBody2D = null
var _verdantwood_guardian_cleared := false
# Kept around (not just a local in _ready()) so verify_verdantwood_maze.gd
# can read back the actual generated positions after the scene loads, same
# reason maze_interior.gd keeps its own _gen around.
var verdantwood_maze_data: Dictionary = {}
# Same reasoning - lets verify_wild_monsters.gd read back the actual
# generated placements (World.scatter_wild_monsters()'s own return value)
# after the scene loads, since the loop that spawns them doesn't otherwise
# keep it anywhere.
var wild_monster_data: Array = []

const ZONE_KEYS := {
	World.Zone.FROSTPEAK: "frostpeak",
	World.Zone.VERDANTWOOD: "verdantwood",
	World.Zone.BADLANDS: "badlands",
	World.Zone.GLOOMFEN: "gloomfen",
}

func _tile_center(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * 32 + 16, pos.y * 32 + 16)

# The recipe's own props and wild monsters (see map_recipe.gd). Props by
# scene name (the biome obstacles plus Tree / Rock); monsters by species,
# fighting in the species' own biome pool (a dungeon species fights with
# the dungeon pool) so a designed camp works anywhere on the map.
func _spawn_recipe(recipe: Dictionary, obstacle_scenes: Dictionary) -> void:
	var scenes: Dictionary = obstacle_scenes.duplicate()
	scenes["Tree"] = TREE_SCENE
	scenes["Rock"] = ROCK_SCENE
	for entry in MapRecipe.props(recipe):
		if scenes.has(entry.scene):
			_spawn_prop(scenes[entry.scene], entry.pos)
		else:
			push_warning("MapRecipe: unknown prop scene '%s' at %s" % [entry.scene, str(entry.pos)])
	for entry in MapRecipe.monsters(recipe):
		var def: Dictionary = Enemies.ENEMIES.get(entry.enemy_id, {})
		if def.is_empty():
			push_warning("MapRecipe: unknown enemy '%s' at %s" % [entry.enemy_id, str(entry.pos)])
			continue
		var zones: Array = def.get("zones", [])
		var placement := {"enemy_id": entry.enemy_id, "zone": int(zones[0]) if not zones.is_empty() else -1, "placement_key": "recipe:%d,%d" % [entry.pos.x, entry.pos.y], "pos": entry.pos}
		var monster: StaticBody2D = WILD_MONSTER_SCENE.instantiate()
		monster.enemy_id = placement.enemy_id
		monster.zone = placement.zone
		monster.placement_key = placement.placement_key
		ysort.add_child(monster)
		monster.position = _tile_center(entry.pos)
		wild_monster_data.append(placement)

func _spawn_prop(scene: PackedScene, tile_pos: Vector2i) -> Node2D:
	var instance: Node2D = scene.instantiate()
	instance.position = _tile_center(tile_pos)
	ysort.add_child(instance)
	return instance

# The entrance tile itself is solid (the prop blocks it), so the player is
# always standing on an *adjacent* tile when "at" the entrance — size this
# bigger than one tile so it still triggers.
# texture_path: optional per-instance sprite swap for props that share one
# scene - the village houses all use HouseEntrance.tscn (baked to
# assets/house.png) but the Elder's/Ranger's get their own roof-recoloured
# variant. Every house PNG is exactly 123px tall, so the scene's baked
# scale/offset keep working unchanged.
func _add_entrance(prop_scene: PackedScene, entrance_tile: Vector2i, target_scene: String, target_spawn: Vector2, texture_path: String = "", lock_quest: String = "", locked_text: String = "") -> Area2D:
	var prop: Node2D = _spawn_prop(prop_scene, entrance_tile)
	if texture_path != "":
		prop.get_node("Sprite2D").texture = load(texture_path)
	var portal: Area2D = PORTAL_SCENE.instantiate()
	portal.position = _tile_center(entrance_tile)
	portal.get_node("CollisionShape2D").shape.size = Vector2(56, 56)
	portal.target_scene = target_scene
	portal.target_spawn = target_spawn
	portal.lock_quest = lock_quest
	portal.locked_text = locked_text
	add_child(portal)
	return portal

# Called once by Altar.gd the moment 2 Magic Crystals reveal it, and again
# from _ready() on every later visit once GameState.world_progress already
# has it revealed — reuses DungeonEntrance's arch prop (no unique art for
# "a hidden path" exists), leading to FinalBoss.tscn.
func reveal_final_boss_entrance() -> void:
	if _final_boss_entrance_spawned:
		return
	_final_boss_entrance_spawned = true
	_add_entrance(DUNGEON_ENTRANCE_SCENE, World.place("final_boss"), "res://scenes/FinalBoss.tscn", Vector2.ZERO)

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
	_add_entrance(ANCIENT_BARROW_ENTRANCE_SCENE, World.place("golden_plains_interior"), "res://scenes/GoldenPlainsInterior.tscn", Vector2.ZERO)

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
	_refresh_ford_bridges()

# River crossing art (2026-09-08, the user's Leonardo render): an open ford
# draws a painted plank footbridge over its crossing tile - the ford tile
# itself now looks like river, so the bridge is what marks the way. Upright
# on the northern and southern fords (the river runs east-west there), a
# quarter turn on the eastern and western ones. Drawn right after the tile
# map, so walkers and the companions waiting on the ford pass over it.
const FORD_BRIDGE := "res://assets/ford_bridge.png"
const EW_BRIDGE_DROP := 14.0

func _refresh_ford_bridges() -> void:
	if not ResourceLoader.exists(FORD_BRIDGE):
		return
	for zone in ZONE_KEYS:
		var node_name := "FordBridge%d" % zone
		if not GameState.biome_paths_open[ZONE_KEYS[zone]] or has_node(node_name):
			continue
		var bridge := Sprite2D.new()
		bridge.name = node_name
		bridge.texture = load(FORD_BRIDGE)
		bridge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bridge.position = _tile_center(World.BIOME_FORDS[zone])
		if zone == World.Zone.VERDANTWOOD or zone == World.Zone.GLOOMFEN:
			bridge.rotation = PI / 2.0
			# Oliver's sprite is centred on his position, so his feet draw
			# ~29 px below it: a turned bridge (34 px band) sits under his
			# feet, his body above (user, 2026-09-08), not under his belt.
			bridge.position.y += EW_BRIDGE_DROP
		add_child(bridge)
		move_child(bridge, tilemap.get_index() + 1)

func _on_quests_changed() -> void:
	_repaint_open_paths()
	_place_companions()
	_place_guides()
	_refresh_altar_marker()

var _altar_marker: Label
var _altar_marker_base_y := 0.0

func _refresh_altar_marker() -> void:
	if _altar_marker != null:
		_altar_marker.visible = Altar.has_offering()

# The four guides step across once their ford opens (user, 2026-09-08):
# they stand a few tiles past the crossing on the biome side, off the path,
# so the hunt is found on the way in rather than missed back in the
# village - and they STAY there: from that spot they are each zone's main
# side-quest giver (the Druid's Thornback hunt today, more lines to come).
var _ranger: StaticBody2D
var _druid: StaticBody2D
var _prospector: StaticBody2D
var _guide: StaticBody2D
const GUIDE_STEPS_IN := 3

func _guide_spot(zone: int) -> Vector2i:
	var ford: Vector2i = World.BIOME_FORDS[zone]
	var inward := Vector2i(signi(World.WORLD_CENTER_X - ford.x), signi(World.WORLD_CENTER_Y - ford.y))
	var perp := Vector2i(1, 0) if inward.y != 0 else Vector2i(0, 1)
	return ford - inward * GUIDE_STEPS_IN + perp

func _place_guides() -> void:
	var done := func(id: String) -> bool: return Quests.quest_state.get(id, "") == "completed"
	if _ranger != null:
		_ranger.position = _tile_center(_guide_spot(World.Zone.FROSTPEAK) if done.call("cross_frostpeak") else World.place("ranger_camp"))
	if _druid != null:
		_druid.position = _tile_center(_guide_spot(World.Zone.VERDANTWOOD) if done.call("cross_verdantwood") else World.place("druid_glade"))
	if _prospector != null:
		_prospector.position = _tile_center(_guide_spot(World.Zone.BADLANDS) if done.call("cross_badlands") else World.place("prospector_camp"))
	if _guide != null:
		_guide.position = _tile_center(_guide_spot(World.Zone.GLOOMFEN) if done.call("cross_gloomfen") else World.place("marsh_guide"))

# --- Companions on the map (2026-09-07). Where Luigi and Eden stand follows
# the story (quests.gd: the joining events). "With Oliver" = off the map.
#   Luigi: the southern ford once it opens (blocking, with the pair's quest);
#          else, after Eden's event, home on the square; else, after his own
#          event, beside Eden at the eastern ford if that is open (waiting to
#          be sent home) or with Oliver; else on the northern ford once it
#          opens (blocking, with his quest); else the square.
#   Eden:  beside Luigi at the pair's ford; else with Oliver after her event;
#          else on the eastern ford once it opens (blocking, with her quest);
#          else the square.
# The one ON the ford blocks the single crossing tile (an NPC is solid); the
# other stands on the valley bank beside it.
var _luigi: StaticBody2D
var _eden: StaticBody2D

func _ford_spots(zone: int) -> Dictionary:
	var ford: Vector2i = World.BIOME_FORDS[zone]
	var inward := Vector2i(signi(World.WORLD_CENTER_X - ford.x), signi(World.WORLD_CENTER_Y - ford.y))
	var perp := Vector2i(1, 0) if inward.y != 0 else Vector2i(0, 1)
	# Two tiles along the bank: out of reach of a player standing before the
	# crossing, so only the blocker answers E there.
	return {"block": ford, "beside": ford + inward + perp * 2}

# The pair's ford: the southern one, once it is open.
func _pair_zone() -> int:
	return World.Zone.BADLANDS if GameState.biome_paths_open.badlands else -1

func _station(npc: StaticBody2D, tile: Vector2i, quest_ids: Array[String], idle: String) -> void:
	npc.visible = true
	npc.process_mode = Node.PROCESS_MODE_INHERIT
	npc.position = _tile_center(tile)
	npc.quest_ids = quest_ids
	npc.dialogue_text = idle
	npc._refresh_marker()

func _with_oliver(npc: StaticBody2D) -> void:
	npc.visible = false
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	npc.position = Vector2(-4000, -4000)
	npc.quest_ids.clear()

func _place_companions() -> void:
	if _luigi == null or _eden == null:
		return
	var done := func(id: String) -> bool: return Quests.quest_state.get(id, "") == "completed"
	var pair_zone: int = _pair_zone()
	var luigi_idle := "Stand tall, pup. The valley is full of things worth barking at, and I have barked at every one of them."
	var eden_idle := "Psst. The valley remembers everything, you know. Where the monsters sleep, where the old doors are - even where you hid your gold."
	# --- Luigi ---
	if done.call("join_pair"):
		_with_oliver(_luigi)
	elif pair_zone != -1:
		_station(_luigi, _ford_spots(pair_zone).block, ["join_pair"], luigi_idle)
	elif done.call("join_eden"):
		_station(_luigi, World.place("luigi"), [], "Woods, pup? Eden says the brambles don't like dogs. I say the brambles haven't met me. ...Fine. I'll guard the square. Again.")
	elif done.call("join_luigi"):
		if GameState.biome_paths_open.verdantwood:
			_station(_luigi, _ford_spots(World.Zone.VERDANTWOOD).beside, [], "The woods next, pup? Eden's got opinions about that. Loud ones.")
		else:
			_with_oliver(_luigi)
	elif GameState.biome_paths_open.frostpeak:
		_station(_luigi, _ford_spots(World.Zone.FROSTPEAK).block, ["join_luigi"], luigi_idle)
	else:
		_station(_luigi, World.place("luigi"), [], luigi_idle)
	# --- Eden ---
	if done.call("join_pair"):
		_with_oliver(_eden)
	elif pair_zone != -1:
		_station(_eden, _ford_spots(pair_zone).beside, [], "Talk to Luigi - he's rehearsed a speech. It has cats in it.")
	elif done.call("join_eden"):
		_with_oliver(_eden)
	elif GameState.biome_paths_open.verdantwood:
		_station(_eden, _ford_spots(World.Zone.VERDANTWOOD).block, ["join_eden"], eden_idle)
	else:
		_station(_eden, World.place("eden"), [], eden_idle)

func _ready() -> void:
	World.reload_places() # the recipe may have moved doors and camps
	World.build_overworld_map(tilemap)
	# Phase 1 "overland dungeon" prototype - carved before add_world_boundary/
	# obstacle scatter so the maze's WALL cells are already painted (and thus
	# excluded by _scatter()'s ground_source check) by the time
	# scatter_biome_obstacles() runs below. Overworld.tscn (this scene) only
	# for now - see World.carve_verdantwood_maze()'s header comment for why
	# bringing it to Overworld2.tscn needs a distinct per-world boss_id first.
	var verdantwood_maze: Dictionary = World.carve_verdantwood_maze(tilemap)
	verdantwood_maze_data = verdantwood_maze
	# The map design recipe (maps/overworld.json, see map_recipe.gd): its
	# tiles go on before the scatters so they respect them (a scattered
	# prop never lands on anything but its biome's plain ground), and the
	# tiles it claims - removed ones plus every recipe prop / monster tile -
	# filter everything the generator would have put there.
	var recipe: Dictionary = MapRecipe.load_active()
	MapRecipe.apply_tiles(tilemap, recipe)
	var claimed: Dictionary = MapRecipe.claimed(recipe)
	World.add_world_boundary(self)
	if GameState.village_gates_open:
		World.open_gates(tilemap)
	_repaint_open_paths()
	Quests.changed.connect(_on_quests_changed)

	for entry in World.scatter_trees_and_rocks(tilemap):
		if claimed.has(entry.pos):
			continue
		var scene: PackedScene = TREE_SCENE if entry.scene == "Tree" else ROCK_SCENE
		_spawn_prop(scene, entry.pos)

	# Static farmable overworld monsters (see wild_monster.gd) - one visible
	# sprite per placement, tagged to a specific species. Interacting rolls a
	# real fight (still 1-3 enemies, same weighting the now-disabled random
	# encounters use) with that species guaranteed present. Scattered BEFORE
	# scatter_biome_lakes()/scatter_biome_obstacles() (not after) so its own
	# placement stays fully self-contained/deterministic - see
	# World.scatter_wild_monsters()'s header comment for why that dependency
	# direction matters (lakes/obstacles paint tiles non-deterministically;
	# monster scatter can't run after anything that does that). Lakes and
	# obstacles are told about these positions instead, so neither can land
	# on top of a monster.
	wild_monster_data = World.scatter_wild_monsters(tilemap).filter(func(e: Dictionary) -> bool: return not claimed.has(e.pos))
	for entry in wild_monster_data:
		var monster: StaticBody2D = WILD_MONSTER_SCENE.instantiate()
		monster.enemy_id = entry.enemy_id
		monster.zone = entry.zone
		monster.placement_key = entry.placement_key
		ysort.add_child(monster)
		monster.position = _tile_center(entry.pos)
	var monster_occupied := {}
	for entry in wild_monster_data:
		monster_occupied[entry.pos] = true
	for pos in claimed.keys():
		monster_occupied[pos] = true

	# Lakes paint before obstacles scatter - a scattered prop's ground_source
	# check (tilemap.get_cell_source_id(pos) != ground_source) automatically
	# excludes any tile a lake already claimed, the same way mountain/river
	# tiles are already excluded for free, but only if the lake painted
	# first. Getting this backwards would let a tree land on top of water.
	World.scatter_biome_lakes(tilemap, monster_occupied)
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
	var obstacle_entries: Array = World.scatter_biome_obstacles(tilemap, monster_occupied)
	for entry in obstacle_entries:
		if claimed.has(entry.pos):
			continue
		_spawn_prop(obstacle_scenes[entry.scene], entry.pos)

	# Verdantwood overland maze's guardian + blocker - instanced directly
	# (not via _spawn_prop()/obstacle_scenes above) since the guardian needs
	# boss_id set before it starts running, same order maze_interior.gd uses
	# for every dungeon/biome-interior boss.
	var guardian: StaticBody2D = BOSS_SCENE.instantiate()
	guardian.position = _tile_center(verdantwood_maze.guardian_pos)
	guardian.boss_id = verdantwood_maze.guardian_id
	ysort.add_child(guardian)
	_verdantwood_maze_blocker = FALLEN_LOG_SCENE.instantiate()
	_verdantwood_maze_blocker.position = _tile_center(verdantwood_maze.blocker_pos)
	ysort.add_child(_verdantwood_maze_blocker)
	# Real MightyOak/TangledBush props along the wall mass's visible boundary
	# - the actual "thick lush forest" visual; the tile underneath
	# (SRC_FOREST_WALL) is what guarantees collision. Mostly oaks with a
	# little TangledBush mixed in for variety (see VERDANTWOOD_MAZE_BUSH_CHANCE
	# in world.gd), reusing the same obstacle_scenes lookup already built
	# above for the normal biome scatter, packed densely here instead of
	# sparsely.
	for entry in verdantwood_maze.boundary_positions:
		_spawn_prop(obstacle_scenes[entry.scene], entry.pos)

	_spawn_recipe(recipe, obstacle_scenes)

	# House.tscn/VillageHouse door tiles are at (5,8) and (4,6) respectively —
	# target spawn is always the tile just inside the door (one row up).
	_add_entrance(HOUSE_ENTRANCE_SCENE, World.HOUSE_ENTRANCE, "res://scenes/House.tscn", Vector2(5 * 32 + 16, 7 * 32 + 16))
	# Elder = moss-green roof, Ranger (the old empty house) = dark shingle;
	# Trader and Oliver's own house keep the terracotta default.
	_add_entrance(HOUSE_ENTRANCE_SCENE, World.ELDER_HOUSE_ENTRANCE, "res://scenes/ElderHouse.tscn", Vector2(4 * 32 + 16, 5 * 32 + 16), "res://assets/house_elder.png")
	_add_entrance(HOUSE_ENTRANCE_SCENE, World.TRADER_HOUSE_ENTRANCE, "res://scenes/TraderHouse.tscn", Vector2(4 * 32 + 16, 5 * 32 + 16))
	_add_entrance(HOUSE_ENTRANCE_SCENE, World.BLACKSMITH_HOUSE_ENTRANCE, "res://scenes/BlacksmithHouse.tscn", Vector2(4 * 32 + 16, 5 * 32 + 16), "res://assets/house_smithy.png")
	# Dungeon.tscn/Castle.tscn/FinalBoss.tscn all regenerate their maze fresh
	# every visit and always spawn the player at their own entrance, so the
	# target_spawn passed here is unused.
	# Barred until the Elder hands out their hunts (chapter 1 / the finale).
	var dungeon_portal: Area2D = _add_entrance(DUNGEON_ENTRANCE_SCENE, World.place("dungeon"), "res://scenes/Dungeon.tscn", Vector2.ZERO, "", "hunt_dungeon", "The old gate is barred with iron and rune. The Village Elder might know how to get it open.")
	dungeon_portal.name = "DungeonPortal"
	var castle_portal: Area2D = _add_entrance(CASTLE_ENTRANCE_SCENE, World.place("castle"), "res://scenes/Castle.tscn", Vector2.ZERO, "", "hunt_castle", "The castle gate is chained shut. The Village Elder might know how to get it open.")
	castle_portal.name = "CastlePortal"
	# No conditional gating needed here - the closed ford (see biome_paths_open
	# above) already physically blocks reaching this entrance until the
	# cross_frostpeak quest opens it.
	_add_entrance(WATCHTOWER_RUIN_ENTRANCE_SCENE, World.place("frostpeak_interior"), "res://scenes/FrostpeakInterior.tscn", Vector2.ZERO)
	_add_entrance(DRUID_CIRCLE_ENTRANCE_SCENE, World.place("verdantwood_interior"), "res://scenes/VerdantwoodInterior.tscn", Vector2.ZERO)
	_add_entrance(VOLCANO_ENTRANCE_SCENE, World.place("badlands_interior"), "res://scenes/BadlandsInterior.tscn", Vector2.ZERO)
	_add_entrance(SUBMERGED_TEMPLE_ENTRANCE_SCENE, World.place("gloomfen_interior"), "res://scenes/GloomfenInterior.tscn", Vector2.ZERO)
	if GameState.world_progress.final_boss_revealed:
		reveal_final_boss_entrance()
	if GameState.world_progress.golden_plains_revealed:
		reveal_golden_plains_entrance()

	# The Village Elder, outside his house on the square (moved out of
	# ElderHouse.tscn so the player has to come to him for the tutorial
	# quest). Two quests in order: Meet the Village, then A Village in Need.
	var elder: StaticBody2D = NPC_SCENE.instantiate()
	elder.position = _tile_center(World.ELDER_POS)
	elder.sprite_path = "res://assets/elder.png"
	elder.npc_name = "Village Elder"
	# The story line in chapter order; locked chapters are skipped by
	# npc.active_quest(), so the biome hunts come in whatever order the fords open.
	var elder_chain: Array[String] = ["meet_villagers", "gather_wood", "bank_gold", "open_ancient_barrow", "hunt_barrow", "hunt_dungeon", "hunt_frostpeak", "hunt_verdantwood", "hunt_badlands", "hunt_gloomfen", "hunt_castle", "two_guardians", "ancient_warden"]
	elder.quest_ids = elder_chain
	elder.npc_id = "village_elder"
	elder.intro_text = "Ah, a new face! I'm the Village Elder - I look after this little settlement. Good to meet you, traveler."
	ysort.add_child(elder)

	# Luigi the Fearless, a battle hound, and Eden, a fairy - the village's
	# two newest faces (2026-09-07), companions in the story to come. Both
	# use painted art when it exists (npc.gd art_height) and a tinted
	# placeholder sprite until then.
	var luigi: StaticBody2D = NPC_SCENE.instantiate()
	luigi.position = _tile_center(World.place("luigi"))
	if ResourceLoader.exists("res://assets/npc_luigi.png"):
		luigi.sprite_path = "res://assets/npc_luigi.png"
		luigi.art_height = 52.0
	else:
		luigi.sprite_path = "res://assets/trader.png"
		luigi.sprite_tint = Color(0.75, 0.55, 0.35, 1.0)
	luigi.npc_name = "Luigi the Fearless"
	luigi.npc_id = "luigi"
	luigi.intro_text = "Woof! Ahem - hail, small human. Luigi the Fearless, at your service. Once I guarded the castle gate; now I guard this square, and nothing gets past me. Except cats. Cats are fast."
	luigi.dialogue_text = "Stand tall, pup. The valley is full of things worth barking at, and I have barked at every one of them."
	ysort.add_child(luigi)
	_luigi = luigi

	var eden: StaticBody2D = NPC_SCENE.instantiate()
	eden.position = _tile_center(World.place("eden"))
	if ResourceLoader.exists("res://assets/npc_eden.png"):
		eden.sprite_path = "res://assets/npc_eden.png"
		eden.art_height = 40.0
	else:
		eden.sprite_path = "res://assets/elder.png"
		eden.sprite_tint = Color(0.75, 0.95, 0.7, 1.0)
	eden.npc_name = "Eden"
	eden.npc_id = "eden"
	eden.intro_text = "Oh! A new face - and such big feet. I'm Eden. I live in the light over the altar, mostly. Small, yes, but I have a scream so mighty it can flatten any monster in this valley. Ask the Bogmaw. Well - you can't, it's still got its paws over its ears."
	eden.dialogue_text = "Psst. The valley remembers everything, you know. Where the monsters sleep, where the old doors are - even where you hid your gold."
	ysort.add_child(eden)
	_eden = eden
	_place_companions() # where the story has them right now

	# The Frostpeak ford-crossing quest giver, camped in the valley near the
	# northern ford (moved out of the village's bottom-right house, which is
	# the Blacksmith's now).
	var ranger: StaticBody2D = NPC_SCENE.instantiate()
	ranger.position = _tile_center(World.place("ranger_camp"))
	ranger.sprite_path = "res://assets/trader.png"
	ranger.sprite_tint = Color(0.75, 0.88, 1.0, 1.0)
	ranger.npc_name = "Frostpeak Ranger"
	var ranger_chain: Array[String] = ["cross_frostpeak", "hunt_frostpeak"] # the ford, then the hunt (turned in at the Elder)
	ranger.quest_ids = ranger_chain
	ranger.npc_id = "frostpeak_ranger"
	ranger.intro_text = "You made it this far? Frostpeak Ridge lies past that river to the north - the old ford's been washed out for ages, or I'd be up there myself."
	ysort.add_child(ranger)
	_ranger = ranger

	# The Verdantwood ford-crossing quest giver stands in the valley near
	# the ford itself, a few tiles off the direct crossing line so it
	# doesn't block the path.
	var druid: StaticBody2D = NPC_SCENE.instantiate()
	druid.position = _tile_center(World.place("druid_glade"))
	druid.sprite_path = "res://assets/elder.png"
	druid.sprite_tint = Color(0.55, 0.75, 0.4, 1.0)
	druid.npc_name = "Forest Druid"
	var druid_chain: Array[String] = ["cross_verdantwood", "hunt_verdantwood", "thornback_warden"] # the ford, the hunt (turned in at the Elder), then a side hunt
	druid.quest_ids = druid_chain
	druid.npc_id = "forest_druid"
	druid.intro_text = "You've wandered far from the village. Verdantwood lies beyond that ford - if you can call it a ford anymore. The old crossing's overgrown; I could use a hand clearing it."
	ysort.add_child(druid)
	_druid = druid

	# The Badlands ford-crossing quest giver - same standalone pattern as the Druid.
	var prospector: StaticBody2D = NPC_SCENE.instantiate()
	prospector.position = _tile_center(World.place("prospector_camp"))
	prospector.sprite_path = "res://assets/trader.png"
	prospector.sprite_tint = Color(0.75, 0.45, 0.25, 1.0)
	prospector.npc_name = "Badlands Prospector"
	var prospector_chain: Array[String] = ["cross_badlands", "hunt_badlands"] # the ford, then the hunt (turned in at the Elder)
	prospector.quest_ids = prospector_chain
	prospector.npc_id = "badlands_prospector"
	prospector.intro_text = "Emberfall's past that ford - if the heat don't get you, the ground giving way underfoot will. I've been meaning to shore up the crossing, just need the stone for it."
	ysort.add_child(prospector)
	_prospector = prospector

	# The Gloomfen ford-crossing quest giver - same standalone pattern as the Druid/Prospector.
	var guide: StaticBody2D = NPC_SCENE.instantiate()
	guide.position = _tile_center(World.place("marsh_guide"))
	guide.sprite_path = "res://assets/elder.png"
	guide.sprite_tint = Color(0.35, 0.42, 0.32, 1.0)
	guide.npc_name = "Marsh Guide"
	var guide_chain: Array[String] = ["cross_gloomfen", "hunt_gloomfen"] # the ford, then the hunt (turned in at the Elder)
	guide.quest_ids = guide_chain
	guide.npc_id = "marsh_guide"
	guide.intro_text = "Gloomfen's past that ford, if you can call it that anymore - the old boards rotted through years back. Bring me wood and I'll lay a new crossing."
	ysort.add_child(guide)
	_guide = guide
	_place_guides()

	# Painted village ground (see house.gd's room shell for the idea): one
	# picture of the plaza, paths and grass over the interior tiles, under
	# the props and the player; the tile map keeps the collision and the
	# fence/gate ring stays visible around it. The altar tile is under the
	# plate too, so its sprite is redrawn on top.
	if ResourceLoader.exists(VILLAGE_GROUND):
		var ground := Sprite2D.new()
		ground.name = "VillageGround"
		ground.texture = load(VILLAGE_GROUND)
		ground.centered = false
		ground.position = Vector2((World.VILLAGE_BOUNDS.x0 + 1) * 32, (World.VILLAGE_BOUNDS.y0 + 1) * 32)
		add_child(ground)
		move_child(ground, tilemap.get_index() + 1)
		# The altar prop lives in the YSort (sorted by its foot, the tile's
		# bottom edge) so Oliver walks behind it from the north and in front
		# from the south, like any other prop.
		var altar_sprite := Sprite2D.new()
		altar_sprite.name = "AltarSprite"
		altar_sprite.texture = load("res://assets/altar.png")
		altar_sprite.position = _tile_center(World.ALTAR_POS) + Vector2(0, 16.0)
		altar_sprite.offset = Vector2(0, -altar_sprite.texture.get_height() / 2.0)
		ysort.add_child(altar_sprite)
		# The altar's turn-in marker: the same gold "!" the NPCs wear, shown
		# while the crystals in hand would do something at the altar.
		_altar_marker = Label.new()
		_altar_marker.name = "AltarMarker"
		_altar_marker.text = "!"
		_altar_marker.size = Vector2(32, 34)
		_altar_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_altar_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_altar_marker.add_theme_font_size_override("font_size", 28)
		_altar_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_altar_marker.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.02))
		_altar_marker.add_theme_constant_override("outline_size", 6)
		_altar_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_altar_marker.position = Vector2(-16.0, -altar_sprite.texture.get_height() - 36.0)
		_altar_marker.visible = false
		altar_sprite.add_child(_altar_marker)
		_altar_marker_base_y = _altar_marker.position.y
		Inventory.changed.connect(_refresh_altar_marker)
		Altar.changed.connect(_refresh_altar_marker)
		_refresh_altar_marker()

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

# Random overworld encounters replaced by static, visible, farmable wild
# monsters (see wild_monster.gd/World.scatter_wild_monsters()) - random
# encounters felt sudden/jarring in the open world. The mechanism itself
# stays in the codebase untouched (Combat.check_random_encounter() still
# works exactly as before, still used by every dungeon/biome interior via
# maze_interior.gd, completely unaffected by this flag) - only this one
# overworld call site is gated off. verify_biome_revamp.gd's own dormant
# "Encounter fired once inside Frostpeak Ridge" check is expected to stay
# false while this is off; new wild-monster coverage lives in
# verify_wild_monsters.gd instead.
const OVERWORLD_ENCOUNTERS_ENABLED := false

# The biome revamp's random encounters - the open overworld had none at all
# before this (Combat.check_random_encounter() was only ever called from
# maze_interior.gd). Golden Plains (Zone.VALLEY, which includes the village)
# stays encounter-free by simply never calling it there - no special-casing
# needed beyond the guard below, and it's what keeps the existing "walk many
# steps across the village, confirm zero encounters" test passing unchanged.
func _process(_delta: float) -> void:
	if _altar_marker != null and _altar_marker.visible:
		_altar_marker.position.y = _altar_marker_base_y + sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 3.0
	var current_tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if current_tile != _last_tile:
		_last_tile = current_tile
		GameState.reveal_overworld(current_tile) # the Map tab's fog of war (2026-09-12)
		var zone: int = World.biome_at(current_tile.x, current_tile.y).zone
		if zone != World.Zone.VALLEY and OVERWORLD_ENCOUNTERS_ENABLED:
			Combat.check_random_encounter(zone)

	# Verdantwood overland maze's gated glade - once the guardian is
	# defeated, free its blocker so the glade's exit opens. Same one-shot
	# latch idiom badlands_interior.gd/frostpeak_interior.gd/
	# gloomfen_interior.gd already use for "once boss_defeated flips, mutate
	# the world", just targeting a prop instance instead of a tile repaint.
	if not _verdantwood_guardian_cleared and GameState.boss_defeated.get(World.VERDANTWOOD_MAZE_GUARDIAN_ID, false):
		_verdantwood_guardian_cleared = true
		if is_instance_valid(_verdantwood_maze_blocker):
			_verdantwood_maze_blocker.queue_free()
