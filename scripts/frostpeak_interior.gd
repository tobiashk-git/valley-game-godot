extends "res://scripts/maze_interior.gd"
# Frostpeak Ridge's roguelike ice-cave interior — the shared maze_interior.gd
# skeleton (terrain/fog painting, spawn, boss, portal, discovered_pois) plus
# two hazard set-pieces layered on top of the same DungeonGen layout: one
# whole room of sliding ice, and one brittle corridor right before the boss
# room. Kept deliberately readable (2 discrete pieces, not speckled tiles).

const SRC_ICE := 2
const SRC_BRIDGE := 3

const BRIDGE_BREAK_DELAY := 1.0 # seconds a bridge tile survives after being stepped off

var hazard_map: Dictionary = {} # Vector2i -> "ice" | "bridge"
var _bridge_timers: Dictionary = {} # Vector2i -> float (seconds remaining)
var _broken_bridge_tiles: Array[Vector2i] = []
var _bridge_repaired := false
var _ice_velocity := Vector2.ZERO
var _last_tile := Vector2i(-9999, -9999)

func _ready() -> void:
	super._ready()
	# Runs later than Player's own _physics_process (default priority 0) in
	# the same tick, so the ice-slide override below isn't immediately
	# stomped by player.gd setting velocity from input every frame.
	process_physics_priority = 10
	_place_hazards()

func _in_any_room(pos: Vector2i) -> bool:
	for room in _gen.rooms:
		if pos.x >= room.x and pos.x < room.x + room.w and pos.y >= room.y and pos.y < room.y + room.h:
			return true
	return false

func _place_hazards() -> void:
	var room_chain: Array = _gen.room_chain
	var ice_room = room_chain[2] # the middle of the 3 intermediate rooms
	for y in range(ice_room.y, ice_room.y + ice_room.h):
		for x in range(ice_room.x, ice_room.x + ice_room.w):
			var pos := Vector2i(x, y)
			hazard_map[pos] = "ice"
			terrain.set_cell(pos, SRC_ICE, Vector2i(0, 0))

	var corridors: Array = _gen.corridors
	var final_corridor: Array = corridors[corridors.size() - 1] # leads directly into the boss room
	for pos in final_corridor:
		if _in_any_room(pos):
			continue # never make a room tile (including the boss room) breakable
		hazard_map[pos] = "bridge"
		terrain.set_cell(pos, SRC_BRIDGE, Vector2i(0, 0))

func _physics_process(_delta: float) -> void:
	var tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if hazard_map.get(tile, "") == "ice":
		var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_vector.length() > 0.01:
			_ice_velocity = input_vector.normalized() * 160.0 # player.gd's SPEED - keep in sync
		elif _ice_velocity != Vector2.ZERO:
			player.velocity = _ice_velocity
			player.move_and_slide()
	else:
		_ice_velocity = Vector2.ZERO

func _process(delta: float) -> void:
	super._process(delta)

	var tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if tile != _last_tile:
		var left_tile := _last_tile
		_last_tile = tile
		if hazard_map.get(left_tile, "") == "bridge":
			_bridge_timers[left_tile] = BRIDGE_BREAK_DELAY
		if _bridge_timers.has(tile):
			_bridge_timers.erase(tile) # stepped back onto it in time - fresh countdown next time

	var expired: Array[Vector2i] = []
	for pos in _bridge_timers:
		_bridge_timers[pos] -= delta
		if _bridge_timers[pos] <= 0.0 and pos != tile:
			expired.append(pos)
	for pos in expired:
		_bridge_timers.erase(pos)
		hazard_map.erase(pos)
		terrain.set_cell(pos, SRC_WALL, Vector2i(0, 0))
		_broken_bridge_tiles.append(pos)

	if not _bridge_repaired and GameState.boss_defeated.get(boss_id, false):
		_bridge_repaired = true
		for pos in _broken_bridge_tiles:
			hazard_map[pos] = "bridge"
			terrain.set_cell(pos, SRC_BRIDGE, Vector2i(0, 0))
		_broken_bridge_tiles.clear()
