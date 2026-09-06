extends Node2D
# Generic fog-of-war maze interior — Dungeon.tscn and Castle.tscn both use
# this script (configured per-scene via these exports, same shared-script-
# via-exports pattern as village_house.gd) rather than duplicating it, since
# the only real differences between them are the wall/floor art (set on the
# TileMapLayer's TileSet resource in each scene, not here), which boss
# stands in the maze, and which Overworld entrance tile leads back out.
# Port of buildDungeonMaze()'s layout generation (see dungeon_gen.gd) plus
# the JS game's revealTilesAround()/isRevealed() fog system, using a second
# TileMapLayer filled with an opaque tile that gets erase_cell()'d as the
# player explores, instead of gating a hand-rolled render loop like the JS
# canvas version does. The boss stands in gen.boss_room (the deliberately-far
# 5th room DungeonGen already computes). Entered/left via a Portal pair with
# the Overworld's entrance tile.

const WIDTH := 40
const HEIGHT := 28
const FOG_REVEAL_RADIUS := 2
const FOG_MARGIN := 24 # fogged tiles beyond every map edge (see _ready)

const SRC_WALL := 0
const SRC_FLOOR := 1
const SRC_FOG := 0 # fog layer has its own single-source TileSet, id 0

const BOSS_SCENE := preload("res://scenes/props/Boss.tscn")
const PORTAL_SCENE := preload("res://scenes/Portal.tscn")
const CHEST_SCENE := preload("res://scenes/props/Chest.tscn")

# Dungeon refinement (2026-09-06):
# - the camera is glued to the player (no edge clamping - on a phone the
#   map is barely taller than the view, so clamping parked Oliver at the
#   bottom of the screen at the door and slid the boss under the HUD);
# - first step into the boss room plays the JS game's dramatic reveal: the
#   fog sweeps off the room column by column from the entry side, then the
#   boss blinks a few times (movement frozen meanwhile via GameState.cutscene);
# - random encounters only roll when a step uncovers new fog, so walking back
#   over explored ground is safe and a cleared dungeon feels cleared;
# - two treasure chests per maze in the side rooms (CHESTS by poi_id), filled
#   once per save through Storage - an emptied chest stays empty.
const ROOM_REVEAL_STEP := 0.06
const BOSS_FLASH_COUNT := 3
const BOSS_FLASH_DURATION := 0.15
const CHESTS := {
	"dungeon": [{"gold": 15}, {"gold": 20, "item": "healing_potion", "amount": 1}],
	"castle": [{"gold": 40}, {"gold": 60}],
	"frostpeak_interior": [{"gold": 25}, {"gold": 35, "item": "frost_shard", "amount": 2}],
	"verdantwood_interior": [{"gold": 35}, {"gold": 50, "item": "ironwood", "amount": 2}],
	"badlands_interior": [{"gold": 50}, {"gold": 70, "item": "ember_core", "amount": 1}],
	"gloomfen_interior": [{"gold": 70}, {"gold": 90, "item": "bog_iron", "amount": 2}],
	"golden_plains_interior": [{"gold": 20}, {"gold": 30, "item": "healing_potion", "amount": 1}],
}

@export var boss_id := "dungeon_boss"
@export var entrance_tile := Vector2i.ZERO # World.DUNGEON_ENTRANCE / World.CASTLE_ENTRANCE
@export var poi_id := "dungeon" # GameState.discovered_pois key
# -1 (default) preserves every existing interior's behavior byte-for-byte -
# Combat.check_random_encounter(-1) routes to Enemies.pick_random_id(), the
# same empty-zones 5-enemy pool as before this export existed. A biome
# interior subclass (e.g. frostpeak_interior.gd) sets this to a World.Zone
# value instead, to pull from that biome's own outdoor monster pool.
@export var encounter_zone: int = -1

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var fog: TileMapLayer = $FogLayer
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Player

var _last_revealed_tile: Vector2i = Vector2i(-9999, -9999)
var _boss: StaticBody2D
var _boss_reveal_pending := true
# Steps that uncovered new fog (the only ones that can roll an encounter).
var explore_steps := 0
var chests: Array = [] # the placed Chest nodes, in CHESTS order
# The generated layout, kept around (not just a local in _ready()) so a
# subclass can read gen.room_chain/corridors/rooms after super._ready() to
# place its own hazard tiles, without generating a second, different maze.
var _gen: Dictionary

func _tile_center(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * 32 + 16, pos.y * 32 + 16)

func _ready() -> void:
	_gen = DungeonGen.generate(WIDTH, HEIGHT)
	var gen: Dictionary = _gen
	var map: Array = gen.map

	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell: int = map[y][x]
			if cell == DungeonGen.WALL:
				terrain.set_cell(Vector2i(x, y), SRC_WALL, Vector2i(0, 0))
			else:
				terrain.set_cell(Vector2i(x, y), SRC_FLOOR, Vector2i(0, 0))

	# Fog over the map plus a margin all round: the camera is no longer
	# clamped to the map, so the view can look past its edge (a phone shows
	# ~18 tiles of height at the 1.5x zoom) - the margin keeps that black.
	for y in range(-FOG_MARGIN, HEIGHT + FOG_MARGIN):
		for x in range(-FOG_MARGIN, WIDTH + FOG_MARGIN):
			fog.set_cell(Vector2i(x, y), SRC_FOG, Vector2i(0, 0))

	# Every other scene consumes GameState's pending spawn override to place
	# the player; this one can't use it (the maze regenerates fresh on every
	# _ready(), so any position an entrance portal set ahead of time can't
	# possibly line up with THIS run's layout - gen.spawn_tile below is
	# always authoritative). But leaving it unconsumed left it stuck pending
	# indefinitely, and a later scene with no override of its own (e.g.
	# House.tscn on combat defeat) would wrongly pick up this stale,
	# maze-scale position instead of using its own default - reported as
	# "respawns outside the house" after dying in a dungeon/castle fight.
	# Consume it here purely to clear it; the result is immediately
	# overwritten by the real spawn point below.
	GameState.consume_next_spawn(player)

	var spawn_tile: Vector2i = gen.spawn_tile
	player.position = _tile_center(spawn_tile)

	var boss: StaticBody2D = BOSS_SCENE.instantiate()
	boss.position = _tile_center(gen.boss_room.center())
	boss.boss_id = boss_id
	ysort.add_child(boss)
	_boss = boss
	_place_chests(gen)

	# The door tile back to the Overworld. Resized to 56x56, matching every
	# overworld entrance's own _add_entrance() sizing (Portal.tscn's default
	# 28x28 is too tight for move_and_slide()'s stopping position after a
	# long approach walk to reliably land inside - confirmed directly via
	# tools/verify_boundaries.gd's dungeon-exit check, which failed this way
	# on 2 separate occasions before this fix).
	var out_portal: Area2D = PORTAL_SCENE.instantiate()
	out_portal.position = _tile_center(Vector2i(gen.door_x, gen.door_y))
	out_portal.get_node("CollisionShape2D").shape.size = Vector2(56, 56)
	out_portal.target_scene = "res://scenes/Overworld.tscn"
	out_portal.target_spawn = Vector2(entrance_tile.x * 32 + 16, (entrance_tile.y + 1) * 32 + 16)
	add_child(out_portal)

	# The door sits on the very last painted row (HEIGHT-1) with nothing at
	# all beyond it, so without a blocker the player could walk straight
	# through and off into undefined space past the map's edge.
	var door_blocker := StaticBody2D.new()
	door_blocker.position = _tile_center(Vector2i(gen.door_x, gen.door_y + 1))
	var blocker_shape := CollisionShape2D.new()
	var blocker_rect := RectangleShape2D.new()
	blocker_rect.size = Vector2(32, 32)
	blocker_shape.shape = blocker_rect
	door_blocker.add_child(blocker_shape)
	add_child(door_blocker)

	# Reaching this scene at all in real play means walking through the
	# entrance portal on the Overworld first, so this is already "discovered".
	GameState.discovered_pois[poi_id] = true

	# Glued to the player: the default (effectively unbounded) limits. The
	# fog and the void beyond the map are both black, so nothing shows.
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = -10000000
	cam.limit_top = -10000000
	cam.limit_right = 10000000
	cam.limit_bottom = 10000000
	cam.reset_smoothing()

	_reveal_around(spawn_tile)
	_last_revealed_tile = spawn_tile

func _process(_delta: float) -> void:
	_step(true)

# The per-tile step: reveal fog around the player's tile, play the boss room
# reveal the first time the player stands in that room, and (encounters =
# true) roll an encounter only when the step uncovered new fog. Golden
# Plains calls this with encounters = false.
func _step(encounters: bool) -> void:
	var current_tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if current_tile == _last_revealed_tile:
		return
	_last_revealed_tile = current_tile
	var uncovered: int = _reveal_around(current_tile)
	if _boss_reveal_pending and _in_room(_gen.boss_room, current_tile):
		_reveal_boss_room(current_tile.x)
		return
	if uncovered > 0:
		explore_steps += 1
		if encounters:
			Combat.check_random_encounter(encounter_zone)

func _in_room(room: DungeonGen.Room, tile: Vector2i) -> bool:
	return tile.x >= room.x and tile.x < room.x + room.w and tile.y >= room.y and tile.y < room.y + room.h

# radius defaults to FOG_REVEAL_RADIUS - a subclass can override this method
# (e.g. Verdantwood's canopy-fog hazard) to pass a smaller radius for
# specific tiles; _step()'s own call is unaffected either way. Returns how
# many fogged cells this call uncovered.
func _reveal_around(center: Vector2i, radius: int = FOG_REVEAL_RADIUS) -> int:
	var uncovered := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var pos: Vector2i = center + Vector2i(dx, dy)
			# Never past the map: the margin fog stays (the void is black).
			if pos.x < 0 or pos.y < 0 or pos.x >= WIDTH or pos.y >= HEIGHT:
				continue
			if fog.get_cell_source_id(pos) != -1:
				fog.erase_cell(pos)
				uncovered += 1
	return uncovered

# The dramatic reveal: fog sweeps off the boss room (plus one ring of wall,
# so it reads as a bounded chamber) one column at a time starting nearest
# the column the player entered on, then the boss blinks. Movement is
# frozen until the blinks end; E is not blocked (the boss stands mid-room,
# out of reach from the doorway anyway). Instant under Combat.fast.
func _reveal_boss_room(entry_x: int) -> void:
	_boss_reveal_pending = false
	var room: DungeonGen.Room = _gen.boss_room
	var columns: Array = []
	for x in range(room.x - 1, room.x + room.w + 1):
		columns.append(x)
	columns.sort_custom(func(a: int, b: int) -> bool: return absi(a - entry_x) < absi(b - entry_x))
	GameState.cutscene = true
	for x in columns:
		for y in range(room.y - 1, room.y + room.h + 1):
			fog.erase_cell(Vector2i(x, y))
		if not Combat.fast:
			await get_tree().create_timer(ROOM_REVEAL_STEP).timeout
			if not is_inside_tree():
				GameState.cutscene = false
				return
	if is_instance_valid(_boss):
		await _boss.flash(BOSS_FLASH_COUNT, BOSS_FLASH_DURATION)
	GameState.cutscene = false

# Two chests in the side rooms (never the entrance or boss room), on a room
# tile no corridor runs through, searched from the room's bottom-right
# corner (the hazard scripts and their verifies work from the top-left, so
# a chest never sits on the first hazard tile). Storage is keyed
# "<poi_id>_chest_N" and filled only when the save has never seen it, so
# loot is once per game even though the maze is laid out fresh each visit.
func _place_chests(gen: Dictionary) -> void:
	var specs: Array = CHESTS.get(poi_id, [])
	var side_rooms: Array = gen.room_chain.slice(1, gen.room_chain.size() - 1)
	if specs.is_empty() or side_rooms.is_empty():
		return
	var corridor_tiles := {}
	for corridor in gen.corridors:
		for t in corridor:
			corridor_tiles[t] = true
	for i in range(specs.size()):
		var spec: Dictionary = specs[i]
		var room: DungeonGen.Room = side_rooms[(i * 2) % side_rooms.size()]
		var spot: Vector2i = room.center()
		var found := false
		for y in range(room.y + room.h - 1, room.y - 1, -1):
			for x in range(room.x + room.w - 1, room.x - 1, -1):
				var t := Vector2i(x, y)
				if not corridor_tiles.has(t) and t != room.center():
					spot = t
					found = true
					break
			if found:
				break
		var storage_id := "%s_chest_%d" % [poi_id, i + 1]
		if not Storage.storages.has(storage_id):
			Storage.get_storage(storage_id)
			Storage.add_item(storage_id, "gold", int(spec.gold))
			if spec.has("item"):
				Storage.add_item(storage_id, spec.item, int(spec.get("amount", 1)))
		var chest: StaticBody2D = CHEST_SCENE.instantiate()
		chest.storage_id = storage_id
		chest.position = _tile_center(spot)
		ysort.add_child(chest)
		chests.append(chest)
