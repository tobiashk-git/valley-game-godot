class_name DungeonGen
extends RefCounted
# Port of buildDungeonMaze() in game.js — rooms + randomized-walk corridors.
# Chest/boss/locked-door placement is deliberately not included yet (no
# inventory/combat systems ported); this generates the walkable layout only.

const WALL := 0
const FLOOR := 1
const DOOR := 2

const ROOM_COUNT := 5
const ROOM_MIN := 3
const ROOM_MAX := 5
const FAR_ROOM_MIN := 6 # the 5th room is deliberately bigger and far from the entrance
const FAR_ROOM_MAX := 8
const ROOM_PADDING := 1

class Room:
	var x: int
	var y: int
	var w: int
	var h: int
	func _init(_x: int, _y: int, _w: int, _h: int) -> void:
		x = _x
		y = _y
		w = _w
		h = _h
	func center() -> Vector2i:
		return Vector2i(x + w / 2, y + h / 2)

static func _overlaps(a: Room, b: Room, padding: int) -> bool:
	return a.x - padding < b.x + b.w and a.x + a.w + padding > b.x and a.y - padding < b.y + b.h and a.y + a.h + padding > b.y

static func _try_place_room(width: int, height: int, y_min: int, y_max: int, existing: Array, min_size: int = ROOM_MIN, max_size: int = ROOM_MAX) -> Room:
	for attempt in range(200):
		var w := randi_range(min_size, max_size)
		var h := randi_range(min_size, max_size)
		var x := randi_range(1, width - 1 - w)
		var y := randi_range(y_min, max(y_min, min(y_max, height - 1 - h)))
		var candidate := Room.new(x, y, w, h)
		var ok := true
		for r in existing:
			if _overlaps(candidate, r, ROOM_PADDING):
				ok = false
				break
		if ok:
			return candidate
	return Room.new(randi_range(1, width - 1 - min_size), randi_range(y_min, y_max), min_size, min_size)

static func _try_place_far_room(width: int, height: int, y_min: int, y_max: int, existing: Array, anchor: Vector2i, min_size: int, max_size: int) -> Room:
	var best: Room = null
	var best_dist := -1.0
	for attempt in range(60):
		var w := randi_range(min_size, max_size)
		var h := randi_range(min_size, max_size)
		var x := randi_range(1, width - 1 - w)
		var y := randi_range(y_min, max(y_min, min(y_max, height - 1 - h)))
		var candidate := Room.new(x, y, w, h)
		var ok := true
		for r in existing:
			if _overlaps(candidate, r, ROOM_PADDING):
				ok = false
				break
		if not ok:
			continue
		var c: Vector2i = candidate.center()
		var dist: float = Vector2(c).distance_to(Vector2(anchor))
		if dist > best_dist:
			best_dist = dist
			best = candidate
	if best:
		return best
	return _try_place_room(width, height, y_min, y_max, existing, min_size, max_size)

static func _carve_room(map: Array, room: Room) -> void:
	for y in range(room.y, room.y + room.h):
		for x in range(room.x, room.x + room.w):
			map[y][x] = FLOOR

static func _carve_corridor(map: Array, width: int, height: int, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x := from.x
	var y := from.y
	var steps := 0
	var max_steps := width + height + 40
	while (x != to.x or y != to.y) and steps < max_steps:
		map[y][x] = FLOOR
		cells.append(Vector2i(x, y))
		var move_x: bool = x != to.x and (y == to.y or randf() < 0.5)
		if move_x:
			x += signi(to.x - x)
		else:
			y += signi(to.y - y)
		map[y][x] = FLOOR
		cells.append(Vector2i(x, y))
		if randf() < 0.15:
			x = clampi(x + (-1 if randf() < 0.5 else 1), 1, width - 2)
		steps += 1
	map[to.y][to.x] = FLOOR
	cells.append(Vector2i(to.x, to.y))
	return cells

# Returns a Dictionary: map (Array of Array of int), width, height, door_x,
# door_y, spawn_tile (Vector2i), rooms (Array of Room), boss_room (Room —
# the 5th/far room; not yet used for an actual boss, just the layout).
static func generate(width: int, height: int) -> Dictionary:
	var map: Array = []
	for y in range(height):
		var row: Array = []
		row.resize(width)
		row.fill(WALL)
		map.append(row)

	var entrance_room := _try_place_room(width, height, int(height * 0.65), height - 1 - ROOM_MIN, [])
	var rooms: Array = [entrance_room]
	var entrance_center: Vector2i = entrance_room.center()

	var intermediate_rooms: Array = []
	for i in range(ROOM_COUNT - 2):
		var r := _try_place_room(width, height, 1, height - 1 - ROOM_MIN, rooms)
		rooms.append(r)
		intermediate_rooms.append(r)

	var boss_room := _try_place_far_room(width, height, 1, height - 1 - FAR_ROOM_MIN, rooms, entrance_center, FAR_ROOM_MIN, FAR_ROOM_MAX)
	rooms.append(boss_room)

	for r in rooms:
		_carve_room(map, r)

	var door_x: int = clampi(entrance_center.x, 1, width - 2)
	var door_y := height - 1
	_carve_corridor(map, width, height, entrance_center, Vector2i(door_x, door_y - 1))
	map[door_y][door_x] = DOOR

	intermediate_rooms.sort_custom(func(a: Room, b: Room) -> bool:
		var da: float = Vector2(a.center()).distance_to(Vector2(entrance_center))
		var db: float = Vector2(b.center()).distance_to(Vector2(entrance_center))
		return da < db
	)
	# The actual entrance->intermediates->boss traversal order, surfaced for
	# consumers (e.g. a biome interior's hazard-tile placement) that need to
	# know which room is "the middle one" or "the corridor right before the
	# boss" - previously computed here and thrown away.
	var room_chain: Array = [entrance_room]
	room_chain.append_array(intermediate_rooms)
	room_chain.append(boss_room)
	var corridors: Array = []
	var prev_center := entrance_center
	for room in intermediate_rooms:
		var c: Vector2i = room.center()
		corridors.append(_carve_corridor(map, width, height, prev_center, c))
		prev_center = c
	corridors.append(_carve_corridor(map, width, height, prev_center, boss_room.center()))

	return {
		"map": map,
		"width": width,
		"height": height,
		"door_x": door_x,
		"door_y": door_y,
		"spawn_tile": Vector2i(door_x, door_y - 1),
		"rooms": rooms,
		"boss_room": boss_room,
		"room_chain": room_chain,
		"corridors": corridors,
	}
