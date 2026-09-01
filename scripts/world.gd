extends Node
# Autoload singleton — ports world.js/game.js's world-generation constants,
# biomeAt(), and (this increment) trees/rocks/entrance-marker placement.
# Still not ported: the biome-specific resources (ice/cactus/flower/jewel —
# these never got real sprites in the JS version either, so there's no art
# to port yet), dungeon/castle interiors, NPCs, and fog-of-war mazes.

const OVERWORLD_WIDTH := 100
const OVERWORLD_HEIGHT := 100
const WORLD_CENTER_X := OVERWORLD_WIDTH / 2
const WORLD_CENTER_Y := OVERWORLD_HEIGHT / 2
const VALLEY_RADIUS := 15

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

const DUNGEON_ENTRANCE := Vector2i(WORLD_CENTER_X, WORLD_CENTER_Y - 30)
const CASTLE_ENTRANCE := Vector2i(WORLD_CENTER_X + 35, WORLD_CENTER_Y)
const HOUSE_ENTRANCE := Vector2i(WORLD_CENTER_X - 5, WORLD_CENTER_Y - 3)

# TileSet source ids — must match the order sources were added in
# tools/setup_phase1.gd when the TileSet resource was built.
const SRC_GRASS := 0
const SRC_SNOW := 1
const SRC_SAND := 2
const SRC_FOREST := 3
const SRC_HILLS := 4
const SRC_PATH := 5
const SRC_FENCE := 6
const SRC_GATE := 7
const SRC_ALTAR := 8

enum Zone { VALLEY, SNOW, DESERT, FOREST, HILLS }

# Direct port of biomeAt() in game.js — which cardinal zone a tile belongs
# to: a central valley, surrounded by four wedge-shaped biomes.
func biome_at(tx: int, ty: int) -> Dictionary:
	var dx := tx - WORLD_CENTER_X
	var dy := ty - WORLD_CENTER_Y

	if abs(dx) < VALLEY_RADIUS and abs(dy) < VALLEY_RADIUS:
		return {"zone": Zone.VALLEY, "source": SRC_GRASS}
	if abs(dy) >= abs(dx):
		return {"zone": Zone.SNOW, "source": SRC_SNOW} if dy < 0 else {"zone": Zone.DESERT, "source": SRC_SAND}
	return {"zone": Zone.FOREST, "source": SRC_FOREST} if dx < 0 else {"zone": Zone.HILLS, "source": SRC_HILLS}

# Paints the overworld's terrain layer onto the given TileMapLayer — port of
# buildOverworld()'s biome fill + the World-1-only village fence/gate/path
# stamping from buildWorld() in world.js. All tiles use atlas coord (0,0)
# except grass, which uses (0,5) to match the JS game's groundSpriteFor()
# crop (sy:160 / 32 = row 5).
func build_overworld_map(tilemap: TileMapLayer) -> void:
	for y in range(OVERWORLD_HEIGHT):
		for x in range(OVERWORLD_WIDTH):
			var biome := biome_at(x, y)
			var atlas_coords := Vector2i(0, 5) if biome.source == SRC_GRASS else Vector2i(0, 0)
			tilemap.set_cell(Vector2i(x, y), biome.source, atlas_coords)

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

# Port of the two scatterResource() calls in buildOverworld() (game.js) that
# use isValleyGrass as their placement check — the 4 biome-specific resources
# (ice/cactus/flower/jewel) are deliberately not included, they never got
# real sprites in the JS version either. Returns an Array of
# {"pos": Vector2i, "scene": "Tree"|"Rock"} — the caller instances the actual
# prop scenes, this function only decides where.
func scatter_trees_and_rocks(tilemap: TileMapLayer) -> Array:
	var occupied := {}
	# entrance markers are placed separately (not painted onto the tilemap),
	# so they need to be reserved here the same way the JS version deletes
	# any resource that landed on a POI after the fact.
	occupied[DUNGEON_ENTRANCE] = true
	occupied[CASTLE_ENTRANCE] = true
	occupied[HOUSE_ENTRANCE] = true

	var result: Array = []
	result.append_array(_scatter(tilemap, 70, "Tree", occupied))
	result.append_array(_scatter(tilemap, 40, "Rock", occupied))
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
