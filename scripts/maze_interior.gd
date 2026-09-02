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

const SRC_WALL := 0
const SRC_FLOOR := 1
const SRC_FOG := 0 # fog layer has its own single-source TileSet, id 0

const BOSS_SCENE := preload("res://scenes/props/Boss.tscn")
const PORTAL_SCENE := preload("res://scenes/Portal.tscn")

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

	for y in range(HEIGHT):
		for x in range(WIDTH):
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

	# The door tile back to the Overworld.
	var out_portal: Area2D = PORTAL_SCENE.instantiate()
	out_portal.position = _tile_center(Vector2i(gen.door_x, gen.door_y))
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

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = WIDTH * 32
	cam.limit_bottom = HEIGHT * 32
	cam.reset_smoothing()

	_reveal_around(spawn_tile)
	_last_revealed_tile = spawn_tile

func _process(_delta: float) -> void:
	var current_tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if current_tile != _last_revealed_tile:
		_last_revealed_tile = current_tile
		_reveal_around(current_tile)
		Combat.check_random_encounter(encounter_zone)

# radius defaults to FOG_REVEAL_RADIUS - a subclass can override this method
# (e.g. Verdantwood's canopy-fog hazard) to pass a smaller radius for
# specific tiles; _process()'s own call below is unaffected either way.
func _reveal_around(center: Vector2i, radius: int = FOG_REVEAL_RADIUS) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			fog.erase_cell(center + Vector2i(dx, dy))
