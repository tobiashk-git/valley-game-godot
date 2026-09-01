extends Node
# Autoload singleton — ports world.js/game.js's world-generation constants and
# biomeAt(). This increment covers overworld TERRAIN only (biome fill +
# village square/fence/gates/path/altar) — resource scattering (trees, rocks,
# ice/cactus/flower/jewel), dungeon/castle/house entrance markers, and
# interiors are deliberately not ported yet (next increment).

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
