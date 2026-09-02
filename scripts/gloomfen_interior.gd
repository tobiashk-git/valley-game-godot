extends "res://scripts/maze_interior.gd"
# Gloomfen Marsh's roguelike sinking-platform interior - the shared
# maze_interior.gd skeleton plus two hazard set-pieces layered on top of the
# same DungeonGen layout: a sinking platform (lingering too long marks it to
# sink once you step off - the inverse trigger direction from Frostpeak's
# brittle bridge/Badlands' crumbling rim, but the same "never affect the
# currently-occupied tile" safety rule) and sticky mud (a partial version of
# Verdantwood's root-snare position-correction technique - slows instead of
# stopping).

const SRC_PLATFORM := 2
const SRC_MUD := 3

const PLATFORM_SINK_TIME := 2.0 # seconds standing on a platform before it's marked ready to sink
const MUD_SPEED_MULTIPLIER := 0.4 # ~60% slower while on mud

var hazard_map: Dictionary = {} # Vector2i -> "platform" | "mud"
var _platform_timers: Dictionary = {} # Vector2i -> float (seconds remaining until ready-to-sink)
var _platform_ready_to_sink: Dictionary = {} # Vector2i -> true once its timer has expired
var _broken_platform_tiles: Array[Vector2i] = []
var _platform_repaired := false
var _last_tile := Vector2i(-9999, -9999)
var _pos_before_tick := Vector2.ZERO
var _mud_last_tile := Vector2i(-9999, -9999)

func _ready() -> void:
	super._ready()
	# Runs after Player's own _physics_process (default priority 0) in the
	# same tick, so the mud slow below isn't immediately stomped by
	# player.gd setting velocity from input every frame.
	process_physics_priority = 10
	_place_hazards()
	_pos_before_tick = player.position

func _place_hazards() -> void:
	var platform_room = _gen.room_chain[1]
	# Two distinct scattered platform tiles, not a filled room (same "sparse,
	# not a checkerboard-needing full room" convention as Badlands' geyser
	# vents). DungeonGen's ROOM_MIN is 3, so a room this small only has a
	# single tile if inset by 1 from every edge - the horizontal offset used
	# for wider rooms would collapse onto the same tile as the first spot.
	# Fall back to a vertical offset, then to the room's near corner, so two
	# distinct tiles are always guaranteed regardless of room size.
	var spot1 := Vector2i(platform_room.x + 1, platform_room.y + 1)
	var spot2: Vector2i
	if platform_room.w > 3:
		spot2 = Vector2i(platform_room.x + platform_room.w - 2, platform_room.y + 1)
	elif platform_room.h > 3:
		spot2 = Vector2i(platform_room.x + 1, platform_room.y + platform_room.h - 2)
	else:
		spot2 = Vector2i(platform_room.x, platform_room.y)
	for pos in [spot1, spot2]:
		hazard_map[pos] = "platform"
		terrain.set_cell(pos, SRC_PLATFORM, Vector2i(0, 0))

	var mud_room = _gen.room_chain[3]
	for y in range(mud_room.y, mud_room.y + mud_room.h):
		for x in range(mud_room.x, mud_room.x + mud_room.w):
			var pos := Vector2i(x, y)
			hazard_map[pos] = "mud"
			terrain.set_cell(pos, SRC_MUD, Vector2i(0, 0))

func _physics_process(_delta: float) -> void:
	var tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	# Only correct once this tile matches last physics tick's tile - an
	# instantaneous position change (teleport, scene entry, a previous
	# hazard's own correction) between ticks would otherwise leave
	# _pos_before_tick stale, turning this tick's "displacement" into the
	# distance from wherever the player was before that jump and snapping
	# them back toward it instead of applying a gentle partial slow.
	if hazard_map.get(tile, "") == "mud" and tile == _mud_last_tile:
		var displacement: Vector2 = player.position - _pos_before_tick
		player.position = _pos_before_tick + displacement * MUD_SPEED_MULTIPLIER
	_pos_before_tick = player.position
	_mud_last_tile = tile

func _process(delta: float) -> void:
	super._process(delta)

	var tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if tile != _last_tile:
		var left_tile := _last_tile
		_last_tile = tile
		if hazard_map.get(left_tile, "") == "platform":
			if _platform_ready_to_sink.get(left_tile, false):
				_platform_ready_to_sink.erase(left_tile)
				_platform_timers.erase(left_tile)
				hazard_map.erase(left_tile)
				terrain.set_cell(left_tile, SRC_WALL, Vector2i(0, 0))
				_broken_platform_tiles.append(left_tile)
			else:
				_platform_timers.erase(left_tile) # stepped off in time - fresh countdown next time

	if hazard_map.get(tile, "") == "platform" and not _platform_ready_to_sink.get(tile, false):
		var remaining: float = _platform_timers.get(tile, PLATFORM_SINK_TIME) - delta
		if remaining <= 0.0:
			_platform_ready_to_sink[tile] = true
			_platform_timers.erase(tile)
		else:
			_platform_timers[tile] = remaining

	if not _platform_repaired and GameState.boss_defeated.get(boss_id, false):
		_platform_repaired = true
		for pos in _broken_platform_tiles:
			hazard_map[pos] = "platform"
			terrain.set_cell(pos, SRC_PLATFORM, Vector2i(0, 0))
		_broken_platform_tiles.clear()
