extends Node
# Autoload singleton — ports world.js/game.js's world-generation constants,
# biomeAt(), and (this increment) trees/rocks/entrance-marker placement.
# Still not ported: the biome-specific resources (ice/cactus/flower/jewel —
# these never got real sprites in the JS version either, so there's no art
# to port yet), dungeon/castle interiors, NPCs, and fog-of-war mazes.

const OVERWORLD_WIDTH := 200   # was 100 - the biome revamp needs room for
const OVERWORLD_HEIGHT := 200  # was 100 - multiple distinct landmarks per biome
const WORLD_CENTER_X := OVERWORLD_WIDTH / 2
const WORLD_CENTER_Y := OVERWORLD_HEIGHT / 2
const VALLEY_RADIUS := 22 # was 15 - grows too, so the safe zone doesn't shrink relative to the doubled biomes

const VILLAGE_BOUNDS := {
	"x0": WORLD_CENTER_X - 8,
	"x1": WORLD_CENTER_X + 8,
	"y0": WORLD_CENTER_Y - 6,
	"y1": WORLD_CENTER_Y + 6,
}

const ALTAR_POS := Vector2i(WORLD_CENTER_X, WORLD_CENTER_Y)

var VILLAGE_GATES := {
	"north": Vector2i(WORLD_CENTER_X, VILLAGE_BOUNDS.y0),
	"south": Vector2i(WORLD_CENTER_X, VILLAGE_BOUNDS.y1),
	"east": Vector2i(VILLAGE_BOUNDS.x1, WORLD_CENTER_Y),
	"west": Vector2i(VILLAGE_BOUNDS.x0, WORLD_CENTER_Y),
}

# Kept inside VALLEY_RADIUS (22) deliberately, not pushed out to use the
# doubled map - the new river ring (see _paint_river_ring()) sits right at
# VALLEY_RADIUS, and these 3 entrances predate the biome revamp with their
# own passing tests that walk straight to them with no quest-gating. Pushing
# them past the ring would silently lock already-working content behind an
# unbuilt river-crossing quest. Offset 19 (was 30/35) still uses noticeably
# more of the village's breathing room than before, just stays on the safe
# side of the ring - revisit once the river-crossing quests actually exist.
const DUNGEON_ENTRANCE := Vector2i(WORLD_CENTER_X, WORLD_CENTER_Y - 19)
const CASTLE_ENTRANCE := Vector2i(WORLD_CENTER_X + 19, WORLD_CENTER_Y)
const HOUSE_ENTRANCE := Vector2i(WORLD_CENTER_X - 5, WORLD_CENTER_Y - 3)
# Hidden until the altar reveals it (2 Magic Crystals) - an outer biome
# zone, well away from the village and the other two entrances.
const FINAL_BOSS_ENTRANCE := Vector2i(WORLD_CENTER_X, WORLD_CENTER_Y + 19)

# Elder (NE), Trader (SW), and the still-empty 3rd house (SE) — same corners
# as VILLAGE_HOUSE_POSITIONS in game.js.
const ELDER_HOUSE_ENTRANCE := Vector2i(WORLD_CENTER_X + 5, WORLD_CENTER_Y - 3)
const TRADER_HOUSE_ENTRANCE := Vector2i(WORLD_CENTER_X - 5, WORLD_CENTER_Y + 3)
const EMPTY_HOUSE_ENTRANCE := Vector2i(WORLD_CENTER_X + 5, WORLD_CENTER_Y + 3)

# Unlike DUNGEON/CASTLE/HOUSE/FINAL_BOSS_ENTRANCE above (all kept inside
# VALLEY_RADIUS), this one is deliberately past the river ring, in real
# Frostpeak territory - Phase 2's whole point is that reaching it requires
# the ford-crossing quest done first. dy=-30 satisfies biome_at()'s
# Frostpeak test (abs(dy) >= abs(dx) and dy < 0) with room to spare past
# VALLEY_RADIUS (22) and the river ring painted at exactly that offset.
const FROSTPEAK_INTERIOR_ENTRANCE := Vector2i(WORLD_CENTER_X, WORLD_CENTER_Y - 30)
# Same reasoning as FROSTPEAK_INTERIOR_ENTRANCE, mirrored onto the east axis
# for Verdantwood (dx=30, dy=0 -> abs(dy) < abs(dx) -> Zone.VERDANTWOOD).
const VERDANTWOOD_INTERIOR_ENTRANCE := Vector2i(WORLD_CENTER_X + 30, WORLD_CENTER_Y)

# The Forest Druid (Verdantwood's ford-crossing quest giver) stands in the
# valley itself, a few tiles off the ford's direct line so it doesn't block
# the crossing - see overworld.gd. Kept here (not a magic number there) so
# scatter_trees_and_rocks() can reserve clearance around it below.
const DRUID_GLADE_POS := Vector2i(WORLD_CENTER_X + VALLEY_RADIUS - 5, WORLD_CENTER_Y + 4)

# TileSet source ids — must match the order sources were added in
# tools/setup_phase1.gd when the TileSet resource was built (0-8), plus 2
# more added later by tools/setup_biome_revamp.gd (9-10, the river/ford).
const SRC_GRASS := 0
const SRC_FROSTPEAK := 1   # was SRC_SNOW - same texture, same compass position (north)
const SRC_BADLANDS := 2    # was SRC_SAND - same texture, same compass position (south)
const SRC_VERDANTWOOD := 3 # was SRC_FOREST - same texture, now placed EAST (was west)
const SRC_GLOOMFEN := 4    # was SRC_HILLS - hills_ground.png reused as a marsh placeholder, now placed WEST (was east)
const SRC_PATH := 5
const SRC_FENCE := 6
const SRC_GATE := 7
const SRC_ALTAR := 8
const SRC_RIVER := 9  # solid - blocks the 4 outer biomes until a ford opens
const SRC_FORD := 10  # walkable - what a river tile flips to via open_biome_path()

enum Zone { VALLEY, FROSTPEAK, VERDANTWOOD, BADLANDS, GLOOMFEN }

# One ford position per outer biome, at the midpoint of that biome's edge of
# the river ring (see _paint_river_ring()) - var, not const, since it's
# built from WORLD_CENTER_X/Y + VALLEY_RADIUS rather than being literal
# values, same reasoning as VILLAGE_GATES below.
var BIOME_FORDS := {
	Zone.FROSTPEAK: Vector2i(WORLD_CENTER_X, WORLD_CENTER_Y - VALLEY_RADIUS),
	Zone.BADLANDS: Vector2i(WORLD_CENTER_X, WORLD_CENTER_Y + VALLEY_RADIUS),
	Zone.GLOOMFEN: Vector2i(WORLD_CENTER_X - VALLEY_RADIUS, WORLD_CENTER_Y),
	Zone.VERDANTWOOD: Vector2i(WORLD_CENTER_X + VALLEY_RADIUS, WORLD_CENTER_Y),
}

# Direct port of biomeAt() in game.js — which cardinal zone a tile belongs
# to: a central valley, surrounded by four wedge-shaped biomes. North/south
# keep their original compass position (Frostpeak/Badlands); west/east are
# swapped from the original Forest/Hills split so Verdantwood Forest sits
# east and the new Gloomfen Marsh (replacing Hills entirely) sits west,
# matching the biome revamp's requested layout.
func biome_at(tx: int, ty: int) -> Dictionary:
	var dx := tx - WORLD_CENTER_X
	var dy := ty - WORLD_CENTER_Y

	if abs(dx) < VALLEY_RADIUS and abs(dy) < VALLEY_RADIUS:
		return {"zone": Zone.VALLEY, "source": SRC_GRASS}
	if abs(dy) >= abs(dx):
		return {"zone": Zone.FROSTPEAK, "source": SRC_FROSTPEAK} if dy < 0 else {"zone": Zone.BADLANDS, "source": SRC_BADLANDS}
	return {"zone": Zone.GLOOMFEN, "source": SRC_GLOOMFEN} if dx < 0 else {"zone": Zone.VERDANTWOOD, "source": SRC_VERDANTWOOD}

# Just the biome fill, no village/altar - shared by World 1's full
# build_overworld_map() below and World 2 (overworld2.gd), which skips the
# village/fence/altar entirely (that onboarding tutorial is World-1-only).
# All tiles use atlas coord (0,0) except grass, which uses (0,5) to match
# the JS game's groundSpriteFor() crop (sy:160 / 32 = row 5).
func build_biome_layer(tilemap: TileMapLayer) -> void:
	for y in range(OVERWORLD_HEIGHT):
		for x in range(OVERWORLD_WIDTH):
			var biome := biome_at(x, y)
			var atlas_coords := Vector2i(0, 5) if biome.source == SRC_GRASS else Vector2i(0, 0)
			tilemap.set_cell(Vector2i(x, y), biome.source, atlas_coords)

# Paints the overworld's terrain layer onto the given TileMapLayer — port of
# buildOverworld()'s biome fill + the World-1-only village fence/gate/path
# stamping from buildWorld() in world.js.
func build_overworld_map(tilemap: TileMapLayer) -> void:
	build_biome_layer(tilemap)

	# Village square: grass (village ground reuses the same grass tile the
	# JS game does), stamped over whatever biome fill is underneath.
	for y in range(VILLAGE_BOUNDS.y0, VILLAGE_BOUNDS.y1 + 1):
		for x in range(VILLAGE_BOUNDS.x0, VILLAGE_BOUNDS.x1 + 1):
			tilemap.set_cell(Vector2i(x, y), SRC_GRASS, Vector2i(0, 5))

	# Fence ring around the village border.
	for y in range(VILLAGE_BOUNDS.y0, VILLAGE_BOUNDS.y1 + 1):
		for x in range(VILLAGE_BOUNDS.x0, VILLAGE_BOUNDS.x1 + 1):
			var on_border: bool = x == VILLAGE_BOUNDS.x0 or x == VILLAGE_BOUNDS.x1 or y == VILLAGE_BOUNDS.y0 or y == VILLAGE_BOUNDS.y1
			if on_border:
				tilemap.set_cell(Vector2i(x, y), SRC_FENCE, Vector2i(0, 0))

	# Gates, cut into the fence.
	for gate_pos in VILLAGE_GATES.values():
		tilemap.set_cell(gate_pos, SRC_GATE, Vector2i(0, 0))

	# 2-tile-deep plaza around the altar.
	const ALTAR_PLAZA_RADIUS := 2
	for y in range(WORLD_CENTER_Y - ALTAR_PLAZA_RADIUS, WORLD_CENTER_Y + ALTAR_PLAZA_RADIUS + 1):
		for x in range(WORLD_CENTER_X - ALTAR_PLAZA_RADIUS, WORLD_CENTER_X + ALTAR_PLAZA_RADIUS + 1):
			if x == WORLD_CENTER_X and y == WORLD_CENTER_Y:
				continue
			tilemap.set_cell(Vector2i(x, y), SRC_PATH, Vector2i(0, 0))

	# Cross of paths from the plaza out to each gate.
	for y in range(VILLAGE_BOUNDS.y0 + 1, VILLAGE_BOUNDS.y1):
		if y == WORLD_CENTER_Y:
			continue
		tilemap.set_cell(Vector2i(WORLD_CENTER_X, y), SRC_PATH, Vector2i(0, 0))
	for x in range(VILLAGE_BOUNDS.x0 + 1, VILLAGE_BOUNDS.x1):
		if x == WORLD_CENTER_X:
			continue
		tilemap.set_cell(Vector2i(x, WORLD_CENTER_Y), SRC_PATH, Vector2i(0, 0))

	# The altar itself, dead center.
	tilemap.set_cell(ALTAR_POS, SRC_ALTAR, Vector2i(0, 0))

	_paint_river_ring(tilemap)

# A 1-tile-thick square outline of SRC_RIVER right at the valley/outer-biome
# seam (every tile where dx or dy == ±VALLEY_RADIUS), blocking all 4 outer
# biomes until their ford opens (see open_biome_path()). World-1-only for
# now, same as the village/fence/altar above - World 2 (overworld2.gd, which
# calls build_biome_layer() directly, skipping this function) doesn't get a
# river yet.
func _paint_river_ring(tilemap: TileMapLayer) -> void:
	for d in range(-VALLEY_RADIUS, VALLEY_RADIUS + 1):
		tilemap.set_cell(Vector2i(WORLD_CENTER_X + d, WORLD_CENTER_Y - VALLEY_RADIUS), SRC_RIVER, Vector2i(0, 0)) # north edge
		tilemap.set_cell(Vector2i(WORLD_CENTER_X + d, WORLD_CENTER_Y + VALLEY_RADIUS), SRC_RIVER, Vector2i(0, 0)) # south edge
		tilemap.set_cell(Vector2i(WORLD_CENTER_X - VALLEY_RADIUS, WORLD_CENTER_Y + d), SRC_RIVER, Vector2i(0, 0)) # west edge
		tilemap.set_cell(Vector2i(WORLD_CENTER_X + VALLEY_RADIUS, WORLD_CENTER_Y + d), SRC_RIVER, Vector2i(0, 0)) # east edge

# Called once per already-unlocked biome from overworld.gd's _ready() (the
# way open_gates() already is for the village) - flips that biome's ford
# from SRC_RIVER (blocked) to SRC_FORD (walkable). No quest sets
# GameState.biome_paths_open yet in this phase; this just needs to exist and
# be independently flippable/verifiable, same as village_gates_open did
# before meet_villagers was built.
func open_biome_path(tilemap: TileMapLayer, zone: int) -> void:
	tilemap.set_cell(BIOME_FORDS[zone], SRC_FORD, Vector2i(0, 0))

# Shared by overworld.gd and overworld2.gd: 4 long invisible colliders, one
# along each edge of the OVERWORLD_WIDTH x OVERWORLD_HEIGHT grid, since a
# fully-painted map otherwise has nothing at all stopping the player from
# walking straight off any edge into undefined tile space beyond it.
func add_world_boundary(node: Node2D) -> void:
	var w: float = OVERWORLD_WIDTH * 32.0
	var h: float = OVERWORLD_HEIGHT * 32.0
	var thickness := 32.0
	var margin := 64.0 # extends past the corners so the 4 walls overlap cleanly
	var edges := [
		{"pos": Vector2(w / 2.0, -thickness / 2.0), "size": Vector2(w + margin * 2.0, thickness)}, # north
		{"pos": Vector2(w / 2.0, h + thickness / 2.0), "size": Vector2(w + margin * 2.0, thickness)}, # south
		{"pos": Vector2(-thickness / 2.0, h / 2.0), "size": Vector2(thickness, h + margin * 2.0)}, # west
		{"pos": Vector2(w + thickness / 2.0, h / 2.0), "size": Vector2(thickness, h + margin * 2.0)}, # east
	]
	for edge in edges:
		var body := StaticBody2D.new()
		body.position = edge.pos
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = edge.size
		shape.shape = rect
		body.add_child(shape)
		node.add_child(body)

# Called by overworld.gd after build_overworld_map() when
# GameState.village_gates_open is true - repaints each gate as walkable
# village ground, same tile the square inside the fence already uses.
func open_gates(tilemap: TileMapLayer) -> void:
	for gate_pos in VILLAGE_GATES.values():
		tilemap.set_cell(gate_pos, SRC_GRASS, Vector2i(0, 5))

# Port of the two scatterResource() calls in buildOverworld() (game.js) that
# use isValleyGrass as their placement check — the 4 biome-specific resources
# (ice/cactus/flower/jewel) are deliberately not included, they never got
# real sprites in the JS version either. Returns an Array of
# {"pos": Vector2i, "scene": "Tree"|"Rock"} — the caller instances the actual
# prop scenes, this function only decides where.
func _reserve_entrance_clearance(occupied: Dictionary, entrance: Vector2i) -> void:
	# A 2-tile buffer around the entrance itself, not just its own tile - the
	# tests (and real players) approach these in a straight line, and with
	# the biome revamp's doubled scatter density plus entrances now sitting
	# inside VALLEY_RADIUS instead of past it, a tree could otherwise land
	# directly in that approach path.
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			occupied[entrance + Vector2i(dx, dy)] = true

func scatter_trees_and_rocks(tilemap: TileMapLayer) -> Array:
	var occupied := {}
	# entrance markers are placed separately (not painted onto the tilemap),
	# so they need to be reserved here the same way the JS version deletes
	# any resource that landed on a POI after the fact.
	_reserve_entrance_clearance(occupied, DUNGEON_ENTRANCE)
	_reserve_entrance_clearance(occupied, CASTLE_ENTRANCE)
	_reserve_entrance_clearance(occupied, HOUSE_ENTRANCE)
	_reserve_entrance_clearance(occupied, FINAL_BOSS_ENTRANCE)
	_reserve_entrance_clearance(occupied, DRUID_GLADE_POS)

	# Was 70/40 - scaled ~2.15x with the valley's new area (radius 15->22,
	# area grows with radius²) so the enlarged valley doesn't end up feeling
	# sparser than it did before the biome revamp's map-size increase.
	var result: Array = []
	result.append_array(_scatter(tilemap, 150, "Tree", occupied))
	result.append_array(_scatter(tilemap, 86, "Rock", occupied))
	return result

func _is_in_village(pos: Vector2i) -> bool:
	return pos.x >= VILLAGE_BOUNDS.x0 and pos.x <= VILLAGE_BOUNDS.x1 and pos.y >= VILLAGE_BOUNDS.y0 and pos.y <= VILLAGE_BOUNDS.y1

func _scatter(tilemap: TileMapLayer, count: int, scene_name: String, occupied: Dictionary) -> Array:
	var placed: Array = []
	var attempts := 0
	var max_attempts := count * 300
	while placed.size() < count and attempts < max_attempts:
		attempts += 1
		var pos := Vector2i(randi_range(0, OVERWORLD_WIDTH - 1), randi_range(0, OVERWORLD_HEIGHT - 1))
		if occupied.has(pos):
			continue
		if biome_at(pos.x, pos.y).zone != Zone.VALLEY:
			continue
		# Village-square tiles are also SRC_GRASS (the JS game renders village
		# ground as plain grass too), so the source-id check below can't tell
		# them apart on its own — the village needs to stay resource-free.
		if _is_in_village(pos):
			continue
		if tilemap.get_cell_source_id(pos) != SRC_GRASS:
			continue
		occupied[pos] = true
		placed.append({"pos": pos, "scene": scene_name})
	return placed
