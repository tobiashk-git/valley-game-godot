extends "res://scripts/maze_interior.gd"
# Emberfall Badlands' roguelike lava-rim interior - the shared
# maze_interior.gd skeleton plus two hazard set-pieces layered on top of the
# same DungeonGen layout: a crumbling rim (identical mechanic to Frostpeak's
# brittle bridge, re-skinned) and a scatter of geyser vents that erupt on a
# timer, pushing the player back once per eruption. Both are movement-only -
# neither can strand the player (the rim repairs once the boss falls, same
# as Frostpeak; the geyser only ever displaces, never blocks a tile).

const SRC_RIM := 2
const SRC_GEYSER := 3

const RIM_BREAK_DELAY := 1.0 # seconds a rim tile survives after being stepped off
const GEYSER_CYCLE := 3.0 # seconds per eruption cycle
const GEYSER_ERUPT_DURATION := 0.6 # seconds the geyser is actively erupting
const GEYSER_PUSH := Vector2(0, 64) # 2 tiles - fixed direction, simplest and most testable

var hazard_map: Dictionary = {} # Vector2i -> "rim" | "geyser"
var _rim_timers: Dictionary = {} # Vector2i -> float (seconds remaining)
var _broken_rim_tiles: Array[Vector2i] = []
var _rim_repaired := false
var _last_tile := Vector2i(-9999, -9999)
var _geyser_cycle_time := 0.0
var _geyser_pushed_this_eruption := false

func _ready() -> void:
	super._ready()
	_place_hazards()

func _in_any_room(pos: Vector2i) -> bool:
	for room in _gen.rooms:
		if pos.x >= room.x and pos.x < room.x + room.w and pos.y >= room.y and pos.y < room.y + room.h:
			return true
	return false

func _place_hazards() -> void:
	var corridors: Array = _gen.corridors
	var final_corridor: Array = corridors[corridors.size() - 1] # leads directly into the boss room
	for pos in final_corridor:
		if _in_any_room(pos):
			continue # never make a room tile (including the boss room) breakable
		hazard_map[pos] = "rim"
		terrain.set_cell(pos, SRC_RIM, Vector2i(0, 0))

	# A handful of individual vent tiles, not a filled room - naturally
	# sparse (unlike Verdantwood's root room, no checkerboard needed here).
	var geyser_room = _gen.room_chain[1]
	var geyser_spots := [
		Vector2i(geyser_room.x + 1, geyser_room.y + 1),
		Vector2i(geyser_room.x + geyser_room.w - 2, geyser_room.y + 1),
	]
	for pos in geyser_spots:
		if pos.x < geyser_room.x + geyser_room.w and pos.y < geyser_room.y + geyser_room.h:
			hazard_map[pos] = "geyser"
			terrain.set_cell(pos, SRC_GEYSER, Vector2i(0, 0))

# Unlike ice/root, neither hazard here needs a _physics_process override -
# the crumbling rim's break/repair and the geyser's one-shot push are both
# handled entirely in _process() below, same timing as the rim/snare timers
# already use in frostpeak_interior.gd/verdantwood_interior.gd.
func _process(delta: float) -> void:
	super._process(delta)

	var tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if tile != _last_tile:
		var left_tile := _last_tile
		_last_tile = tile
		if hazard_map.get(left_tile, "") == "rim":
			_rim_timers[left_tile] = RIM_BREAK_DELAY
		if _rim_timers.has(tile):
			_rim_timers.erase(tile) # stepped back onto it in time - fresh countdown next time

	var expired: Array[Vector2i] = []
	for pos in _rim_timers:
		_rim_timers[pos] -= delta
		if _rim_timers[pos] <= 0.0 and pos != tile:
			expired.append(pos)
	for pos in expired:
		_rim_timers.erase(pos)
		hazard_map.erase(pos)
		terrain.set_cell(pos, SRC_WALL, Vector2i(0, 0))
		_broken_rim_tiles.append(pos)

	if not _rim_repaired and GameState.boss_defeated.get(boss_id, false):
		_rim_repaired = true
		for pos in _broken_rim_tiles:
			hazard_map[pos] = "rim"
			terrain.set_cell(pos, SRC_RIM, Vector2i(0, 0))
		_broken_rim_tiles.clear()

	_geyser_cycle_time += delta
	if _geyser_cycle_time >= GEYSER_CYCLE:
		_geyser_cycle_time -= GEYSER_CYCLE
	var erupting: bool = fmod(_geyser_cycle_time, GEYSER_CYCLE) < GEYSER_ERUPT_DURATION
	if erupting and not _geyser_pushed_this_eruption:
		if hazard_map.get(tile, "") == "geyser":
			player.position += GEYSER_PUSH
			_geyser_pushed_this_eruption = true
	elif not erupting:
		_geyser_pushed_this_eruption = false
