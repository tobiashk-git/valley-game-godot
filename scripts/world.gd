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
# Same reasoning as VERDANTWOOD_INTERIOR_ENTRANCE, mirrored onto the south
# axis for Badlands (dx=0, dy=30 -> abs(dy) >= abs(dx) and dy >= 0 -> Zone.BADLANDS).
const BADLANDS_INTERIOR_ENTRANCE := Vector2i(WORLD_CENTER_X, WORLD_CENTER_Y + 30)
# Same reasoning as DRUID_GLADE_POS - the Badlands Prospector stands near
# that ford's direct line, offset so it doesn't block the crossing.
const PROSPECTOR_CAMP_POS := Vector2i(WORLD_CENTER_X + 5, WORLD_CENTER_Y + VALLEY_RADIUS - 5)
# Same reasoning as BADLANDS_INTERIOR_ENTRANCE, mirrored onto the west axis
# for Gloomfen (dx=-30, dy=0 -> abs(dy) < abs(dx), dx < 0 -> Zone.GLOOMFEN).
const GLOOMFEN_INTERIOR_ENTRANCE := Vector2i(WORLD_CENTER_X - 30, WORLD_CENTER_Y)
# Same reasoning as PROSPECTOR_CAMP_POS - the Marsh Guide stands near that
# ford's direct line, offset so it doesn't block the crossing.
const MARSH_GUIDE_POS := Vector2i(WORLD_CENTER_X - VALLEY_RADIUS + 5, WORLD_CENTER_Y - 4)

# Golden Plains IS the central Zone.VALLEY (the safe starting zone) - there's
# no river ring around it, so unlike the 4 outer-biome interior entrances
# above, this one sits inside VALLEY_RADIUS rather than past it. sqrt(13²+13²)
# ~= 18.4 < VALLEY_RADIUS (22), clear of VILLAGE_BOUNDS and every other
# in-valley entrance/landmark.
const GOLDEN_PLAINS_INTERIOR_ENTRANCE := Vector2i(WORLD_CENTER_X - 13, WORLD_CENTER_Y - 13)

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
const SRC_RIVER := 9   # solid - blocks the 4 outer biomes until a ford opens
const SRC_FORD := 10   # walkable - what a river tile flips to via open_biome_path()
# 11 (SRC_RAVINE) is retired - the wedge-seam crossings it served no longer
# exist (see paint_outer_biome_mountains()). Its embedded TileSetAtlasSource/
# ravine.png are left in place in Overworld.tscn rather than surgically
# removed, but nothing references source 11 anymore.
const SRC_MOUNTAIN := 12 # solid - the permanent, impassable range along each of the 4 outer-biome wedge boundaries
const SRC_GLOOMFEN_WATER := 13 # solid - scattered swamp-lake blobs, see scatter_biome_lakes()

enum Zone { VALLEY, FROSTPEAK, VERDANTWOOD, BADLANDS, GLOOMFEN }

# One ford position per outer biome, at the midpoint of that biome's edge of
# the river ring (see _paint_river_ring()) - var, not const, since it's
# built from WORLD_CENTER_X/Y + VALLEY_RADIUS rather than being literal
# values, same reasoning as VILLAGE_GATES below. This is now the ONLY way
# into or out of any outer biome - the valley is the sole hub (see
# paint_outer_biome_mountains(), which replaced the old wedge-seam crossings
# between two outer biomes with a permanent, impassable divider).
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

# Purely cosmetic - biome_at()'s 4 outer wedges meet along 4 diagonals
# (abs(dx) == abs(dy)) with a hard cut today. Within a couple tiles of one of
# those diagonals (and only outside the valley - inside it's uniformly
# grass), dither in the adjacent wedge's own source instead of always using
# primary_source, on alternating tiles (deterministic on tile coords, not
# randf(), so it's stable across reloads/rebuilds). SEAM_BLEND_BAND (2) is
# narrower than paint_outer_biome_mountains()'s own MOUNTAIN_BAND (4), so
# that later pass fully overwrites every tile this dithers - dead weight for
# those specific tiles now, but harmless, and left in place rather than
# removed since it costs nothing to keep running.
const SEAM_BLEND_BAND := 2

func _blend_source(tx: int, ty: int, primary_source: int) -> int:
	var dx := tx - WORLD_CENTER_X
	var dy := ty - WORLD_CENTER_Y
	if abs(dx) < VALLEY_RADIUS and abs(dy) < VALLEY_RADIUS:
		return primary_source
	if absi(absi(dx) - absi(dy)) > SEAM_BLEND_BAND:
		return primary_source
	if (tx * 13 + ty * 7) % 2 != 0:
		return primary_source
	if abs(dy) >= abs(dx):
		return SRC_GLOOMFEN if dx < 0 else SRC_VERDANTWOOD
	return SRC_FROSTPEAK if dy < 0 else SRC_BADLANDS

# Just the biome fill, no village/altar - shared by World 1's full
# build_overworld_map() below and World 2 (overworld2.gd), which skips the
# village/fence/altar entirely (that onboarding tutorial is World-1-only).
# All tiles use atlas coord (0,0) except grass, which uses (0,5) to match
# the JS game's groundSpriteFor() crop (sy:160 / 32 = row 5); the 4 outer
# biomes (Frostpeak/Badlands/Verdantwood/Gloomfen) dither in a second
# "flecked" ground tile at (1,0) - see tools/integrate_terrain_variety.gd -
# on roughly a third of tiles for visual variety, deterministic on tile
# coords (not randf()) so it's stable across reloads/rebuilds, same
# dithering approach as _blend_source() but with a different salt so the
# two patterns don't visually line up.
const OUTER_BIOME_SOURCES := [SRC_FROSTPEAK, SRC_BADLANDS, SRC_VERDANTWOOD, SRC_GLOOMFEN]

func build_biome_layer(tilemap: TileMapLayer) -> void:
	for y in range(OVERWORLD_HEIGHT):
		for x in range(OVERWORLD_WIDTH):
			var biome := biome_at(x, y)
			var source := _blend_source(x, y, biome.source)
			var atlas_coords := Vector2i(0, 0)
			if source == SRC_GRASS:
				atlas_coords = Vector2i(0, 5)
			elif source in OUTER_BIOME_SOURCES and (x * 17 + y * 11) % 3 == 0:
				atlas_coords = Vector2i(1, 0)
			tilemap.set_cell(Vector2i(x, y), source, atlas_coords)

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
	paint_outer_biome_mountains(tilemap)

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

# Permanent, impassable divider between each pair of adjacent OUTER biomes -
# replaces the old wedge-seam river/ravine crossings (their quests/NPCs are
# gone; the valley is now the sole hub, the only way into or out of any
# outer biome is that biome's own BIOME_FORDS crossing above). Wide (not a
# 1-tile line, like the old seam was) so it actually reads as a mountain
# range, and reaches the map edge - not just some fixed distance like the old
# seam's SEAM_LENGTH stop - so there's no way to walk around it by going
# further out. The old version could stop partway because a crossing was
# always meant to exist somewhere; this one can't, since the entire point is
# "no crossing, ever." Distance-from-diagonal metric matches _blend_source()'s
# own (absi(absi(dx)-absi(dy))), just with a wider band and no dithering -
# solid stone the whole way across.
const MOUNTAIN_BAND := 4

func paint_outer_biome_mountains(tilemap: TileMapLayer) -> void:
	for y in range(OVERWORLD_HEIGHT):
		for x in range(OVERWORLD_WIDTH):
			var dx := x - WORLD_CENTER_X
			var dy := y - WORLD_CENTER_Y
			if abs(dx) < VALLEY_RADIUS and abs(dy) < VALLEY_RADIUS:
				continue
			if absi(absi(dx) - absi(dy)) > MOUNTAIN_BAND:
				continue
			var atlas_coords := Vector2i(1, 0) if (x * 17 + y * 11) % 3 == 0 else Vector2i(0, 0)
			tilemap.set_cell(Vector2i(x, y), SRC_MOUNTAIN, atlas_coords)

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
func _reserve_entrance_clearance(occupied: Dictionary, entrance: Vector2i, radius: int = 2) -> void:
	# A buffer around the entrance itself, not just its own tile - the
	# tests (and real players) approach these in a straight line, and with
	# the biome revamp's doubled scatter density plus entrances now sitting
	# inside VALLEY_RADIUS instead of past it, a tree could otherwise land
	# directly in that approach path. Default radius (2) matches every
	# existing valley-interior call; scatter_biome_obstacles() below passes a
	# slightly wider radius (3) for VERDANTWOOD_INTERIOR_ENTRANCE since a
	# MightyOak visually overhangs multiple tiles, unlike a single-tile
	# Tree/Rock. This alone isn't airtight for any one fixed test position
	# arbitrarily close to the boundary - verify_verdantwood_interior.gd
	# additionally clears its own fixed entrance-approach teleport points
	# directly (same "fix belongs in the test" reasoning as _clear_corridor_row).
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
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
	_reserve_entrance_clearance(occupied, PROSPECTOR_CAMP_POS)
	_reserve_entrance_clearance(occupied, MARSH_GUIDE_POS)
	_reserve_entrance_clearance(occupied, GOLDEN_PLAINS_INTERIOR_ENTRANCE)

	# Was 70/40 - scaled ~2.15x with the valley's new area (radius 15->22,
	# area grows with radius²) so the enlarged valley doesn't end up feeling
	# sparser than it did before the biome revamp's map-size increase.
	var result: Array = []
	var full_map := Rect2i(0, 0, OVERWORLD_WIDTH, OVERWORLD_HEIGHT)
	result.append_array(_scatter(tilemap, 150, "Tree", occupied, Zone.VALLEY, SRC_GRASS, full_map))
	result.append_array(_scatter(tilemap, 86, "Rock", occupied, Zone.VALLEY, SRC_GRASS, full_map))
	return result

# Outer-biome counterpart to scatter_trees_and_rocks() above - impassable
# navigate-around obstacles scattered into the 4 outer biomes (mighty oaks in
# Verdantwood, ice boulders in Frostpeak so far; lakes for the other 2 are a
# future pass). Called separately from scatter_trees_and_rocks() by
# overworld.gd/overworld2.gd, same pattern.
# Distance from center a scatter's bounding box reaches (see
# scatter_biome_obstacles() below) - comfortably past the interior
# entrances' own distance-30 placement, without wastefully sampling all the
# way out to the (otherwise-empty) map edges.
const OBSTACLE_SCATTER_REACH := 50

# Keeps every scattered obstacle a few tiles clear of the outer river ring -
# without this, a tall canopy (MightyOak) can visually overhang the water,
# and a flat/linear one (FallenLog) can read as a bridge/crossing that isn't
# actually there. Both reported directly by the user from real screenshots.
# The river ring is 1 tile wide at exactly VALLEY_RADIUS from center on the
# axis matching each zone's own BIOME_FORDS entry (see _paint_river_ring()) -
# FROSTPEAK/BADLANDS' ford only varies in Y, GLOOMFEN/VERDANTWOOD's only in
# X, so checking distance along that single axis is enough; the diagonal
# mountain ranges (paint_outer_biome_mountains()) are solid ground, not
# water, so they don't need the same clearance.
const OBSTACLE_RIVER_CLEARANCE := 3

func _far_enough_from_river(pos: Vector2i, zone: int) -> bool:
	if zone == Zone.VALLEY:
		return true
	var ford: Vector2i = BIOME_FORDS[zone]
	if zone == Zone.FROSTPEAK or zone == Zone.BADLANDS:
		return absi(pos.y - ford.y) >= OBSTACLE_RIVER_CLEARANCE
	return absi(pos.x - ford.x) >= OBSTACLE_RIVER_CLEARANCE

# Keeps a ground-flush obstacle (FallenLog, IcePool) from landing close
# enough to an elevated one (MightyOak, IceBoulder, IceCrystalShard,
# TangledBush) that their sprites appear to fuse at the base - e.g. a log
# whose end touches a tree's trunk reads as "growing out of the tree"
# instead of two separate objects - or close enough to ANOTHER flush
# obstacle that two circular shapes (e.g. two ice pools) merge into a single
# shared-edge blob. Both reported directly by the user from real
# screenshots. Elevated objects overlapping EACH OTHER (a tree's canopy over
# a rock, a bush against a tree) already reads fine via plain Y-sort and
# stays unrestricted - flat/hard-edged flush shapes are the ones that read
# wrong when they visibly fuse, soft/irregular canopy silhouettes don't.
const OBSTACLE_CATEGORY_BUFFER := 1

func scatter_biome_obstacles(tilemap: TileMapLayer) -> Array:
	var occupied := {}
	var elevated_buffer := {}
	var flush_buffer := {}
	_reserve_entrance_clearance(occupied, VERDANTWOOD_INTERIOR_ENTRANCE, 3)
	_reserve_entrance_clearance(occupied, BIOME_FORDS[Zone.VERDANTWOOD])
	_reserve_entrance_clearance(occupied, FROSTPEAK_INTERIOR_ENTRANCE, 3)
	_reserve_entrance_clearance(occupied, BIOME_FORDS[Zone.FROSTPEAK])
	_reserve_entrance_clearance(occupied, GLOOMFEN_INTERIOR_ENTRANCE, 3)
	_reserve_entrance_clearance(occupied, BIOME_FORDS[Zone.GLOOMFEN])
	_reserve_entrance_clearance(occupied, MARSH_GUIDE_POS, 3)

	# A tight box around the wedge instead of the full 200x200 map - outer
	# biomes are huge and mostly empty past this distance, so a full-map
	# bounds would waste most of _scatter()'s attempt budget on tiles nobody
	# ever visits.
	var bounds := Rect2i(WORLD_CENTER_X - OBSTACLE_SCATTER_REACH, WORLD_CENTER_Y - OBSTACLE_SCATTER_REACH, OBSTACLE_SCATTER_REACH * 2, OBSTACLE_SCATTER_REACH * 2)

	var result: Array = []
	result.append_array(_scatter(tilemap, 18, "MightyOak", occupied, Zone.VERDANTWOOD, SRC_VERDANTWOOD, bounds, false, elevated_buffer, flush_buffer))
	result.append_array(_scatter(tilemap, 18, "IceBoulder", occupied, Zone.FROSTPEAK, SRC_FROSTPEAK, bounds, false, elevated_buffer, flush_buffer))
	# Second, smaller Frostpeak obstacle for visual variety - occupied is
	# shared across every _scatter() call in this function, so this can't
	# land on an already-placed IceBoulder.
	result.append_array(_scatter(tilemap, 22, "IceCrystalShard", occupied, Zone.FROSTPEAK, SRC_FROSTPEAK, bounds, false, elevated_buffer, flush_buffer))
	# Third Frostpeak obstacle - a flat meltwater pool sitting in the snow,
	# unlike the two raised/elevated obstacles above.
	result.append_array(_scatter(tilemap, 16, "IcePool", occupied, Zone.FROSTPEAK, SRC_FROSTPEAK, bounds, true, elevated_buffer, flush_buffer))
	# Second, smaller Verdantwood obstacle for visual variety - same "one
	# elevated, one lower-profile" pairing as MightyOak/IceBoulder alongside
	# IceCrystalShard/IcePool.
	result.append_array(_scatter(tilemap, 20, "FallenLog", occupied, Zone.VERDANTWOOD, SRC_VERDANTWOOD, bounds, true, elevated_buffer, flush_buffer))
	# Third Verdantwood obstacle - a large tangled bush, same "third obstacle
	# for variety" role IcePool plays in Frostpeak.
	result.append_array(_scatter(tilemap, 18, "TangledBush", occupied, Zone.VERDANTWOOD, SRC_VERDANTWOOD, bounds, false, elevated_buffer, flush_buffer))
	# Gloomfen's first prop-scatter obstacle (it already has the lake blobs,
	# painted earlier in world-gen - see overworld.gd/overworld2.gd's call
	# order) - a gnarled swamp tree, same elevated role MightyOak plays in
	# Verdantwood. ground_source's SRC_GLOOMFEN check automatically excludes
	# any tile a lake already claimed, the same way it already excludes
	# mountain/river tiles, since lakes paint before this call runs.
	result.append_array(_scatter(tilemap, 18, "SwampTree", occupied, Zone.GLOOMFEN, SRC_GLOOMFEN, bounds, false, elevated_buffer, flush_buffer))
	return result

# Gloomfen's counterpart to scatter_biome_obstacles() above - unlike every
# other obstacle (a single-tile prop scene instanced at one point), a lake is
# a multi-tile organic blob painted directly onto the terrain, closer in kind
# to _paint_river_ring()/paint_outer_biome_mountains() than to _scatter()'s
# single-point placement - no prop scene, no StaticBody2D, the water tiles
# themselves carry solid collision via the TileSet source.
const GLOOMFEN_LAKE_COUNT := 4
const LAKE_CIRCLE_COUNT := 3        # circles unioned per lake, tuned visually after first screenshot
const LAKE_CIRCLE_RADIUS_MIN := 1
const LAKE_CIRCLE_RADIUS_MAX := 3   # radius 2-4 (an earlier tuning pass) read organic but dominated the
# screen at ~45 tiles/lake, more like a terrain feature than a scatterable
# obstacle - the two-pass erosion below does the real work of keeping the
# silhouette irregular, so radius can come back down without losing that
const LAKE_CIRCLE_JITTER := 2       # how far each extra circle's center can drift from the seed - kept close
# to the radius range so circles genuinely displace from each other (a
# jitter much smaller than the radius just stacks near-concentric circles,
# which reads as a symmetric geometric shape - a cross, in the first visual
# test - rather than an organic pond)
const LAKE_EDGE_KEEP_CHANCE := 0.7  # boundary tiles are randomly dropped to
# ragged-edge the silhouette - a pure circle union has a crisp geometric
# edge at this tile resolution (radius 2-4 is only a handful of tiles wide),
# which reads as artificial no matter how the circles are jittered

func scatter_biome_lakes(tilemap: TileMapLayer) -> void:
	var occupied := {}
	_reserve_entrance_clearance(occupied, GLOOMFEN_INTERIOR_ENTRANCE, 3)
	_reserve_entrance_clearance(occupied, BIOME_FORDS[Zone.GLOOMFEN])
	_reserve_entrance_clearance(occupied, MARSH_GUIDE_POS, 3)
	var bounds := Rect2i(WORLD_CENTER_X - OBSTACLE_SCATTER_REACH, WORLD_CENTER_Y - OBSTACLE_SCATTER_REACH, OBSTACLE_SCATTER_REACH * 2, OBSTACLE_SCATTER_REACH * 2)
	_paint_lakes(tilemap, GLOOMFEN_LAKE_COUNT, Zone.GLOOMFEN, SRC_GLOOMFEN, SRC_GLOOMFEN_WATER, occupied, bounds)

# Unions LAKE_CIRCLE_COUNT jittered circles into one organic blob - the
# simplest reliable way to get a non-circular pond shape without real
# flood-fill/random-walk complexity (no infinite-loop risk, predictable size
# range). Every tile within radius of ANY circle center is part of the lake,
# then a ragged-edge erosion pass randomly drops boundary tiles so the
# silhouette doesn't read as a crisp, geometric circle union.
func _lake_footprint(seed_pos: Vector2i) -> Array:
	var footprint := {}
	for i in range(LAKE_CIRCLE_COUNT):
		var center := seed_pos if i == 0 else seed_pos + Vector2i(randi_range(-LAKE_CIRCLE_JITTER, LAKE_CIRCLE_JITTER), randi_range(-LAKE_CIRCLE_JITTER, LAKE_CIRCLE_JITTER))
		var radius := randi_range(LAKE_CIRCLE_RADIUS_MIN, LAKE_CIRCLE_RADIUS_MAX)
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy <= radius * radius:
					footprint[center + Vector2i(dx, dy)] = true

	# Two erosion passes, not one - the first pass alone still left a few long
	# straight/blocky edges from the original circle union (confirmed via a
	# real screenshot); a second pass over the newly-exposed edge roughs the
	# coastline up further into something that reads as a natural pond.
	for pass_i in range(2):
		var eroded := {}
		for pos in footprint.keys():
			var is_edge := false
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not footprint.has(pos + offset):
					is_edge = true
					break
			if not is_edge or randf() < LAKE_EDGE_KEEP_CHANCE:
				eroded[pos] = true
		footprint = eroded
	return footprint.keys()

func _paint_lakes(tilemap: TileMapLayer, count: int, zone: int, ground_source: int, water_source: int, occupied: Dictionary, bounds: Rect2i) -> void:
	var placed := 0
	var attempts := 0
	var max_attempts := count * 300 # same budget convention as _scatter()
	while placed < count and attempts < max_attempts:
		attempts += 1
		var seed_pos := Vector2i(randi_range(bounds.position.x, bounds.end.x - 1), randi_range(bounds.position.y, bounds.end.y - 1))
		if not _far_enough_from_river(seed_pos, zone):
			continue
		var footprint := _lake_footprint(seed_pos)
		var valid := true
		for pos in footprint:
			if occupied.has(pos) or biome_at(pos.x, pos.y).zone != zone or tilemap.get_cell_source_id(pos) != ground_source or not _far_enough_from_river(pos, zone):
				valid = false
				break
		if not valid:
			continue
		for pos in footprint:
			var atlas_coords := Vector2i(1, 0) if (pos.x * 13 + pos.y * 7) % 3 == 0 else Vector2i(0, 0) # different salt than the mountain band's/ground textures' own hash
			tilemap.set_cell(pos, water_source, atlas_coords)
			occupied[pos] = true
		placed += 1

func _is_in_village(pos: Vector2i) -> bool:
	return pos.x >= VILLAGE_BOUNDS.x0 and pos.x <= VILLAGE_BOUNDS.x1 and pos.y >= VILLAGE_BOUNDS.y0 and pos.y <= VILLAGE_BOUNDS.y1

func _scatter(tilemap: TileMapLayer, count: int, scene_name: String, occupied: Dictionary, zone: int, ground_source: int, bounds: Rect2i, is_flush: bool = false, elevated_buffer: Dictionary = {}, flush_buffer: Dictionary = {}) -> Array:
	var placed: Array = []
	var attempts := 0
	var max_attempts := count * 300
	while placed.size() < count and attempts < max_attempts:
		attempts += 1
		var pos := Vector2i(randi_range(bounds.position.x, bounds.end.x - 1), randi_range(bounds.position.y, bounds.end.y - 1))
		if occupied.has(pos):
			continue
		if biome_at(pos.x, pos.y).zone != zone:
			continue
		# Village-square tiles are also SRC_GRASS (the JS game renders village
		# ground as plain grass too), so the source-id check below can't tell
		# them apart on its own — the village needs to stay resource-free.
		# Only relevant for the Zone.VALLEY caller; harmless no-op otherwise.
		if zone == Zone.VALLEY and _is_in_village(pos):
			continue
		if tilemap.get_cell_source_id(pos) != ground_source:
			continue
		if not _far_enough_from_river(pos, zone):
			continue
		# Flush obstacles avoid both elevated ones (the "growing out of the
		# tree" case) AND each other (two circular ice pools overlapping into
		# a shared-edge figure-8 reads just as wrong - flat, hard-edged
		# shapes visibly fuse where soft/irregular canopy silhouettes don't).
		# Elevated obstacles only avoid flush ones - elevated-vs-elevated
		# overlap (tree canopy over a rock, a bush against a tree) is
		# confirmed to look fine via plain Y-sort and stays unrestricted.
		if is_flush and (elevated_buffer.has(pos) or flush_buffer.has(pos)):
			continue
		if not is_flush and flush_buffer.has(pos):
			continue
		occupied[pos] = true
		var same_category_buffer := flush_buffer if is_flush else elevated_buffer
		for dy in range(-OBSTACLE_CATEGORY_BUFFER, OBSTACLE_CATEGORY_BUFFER + 1):
			for dx in range(-OBSTACLE_CATEGORY_BUFFER, OBSTACLE_CATEGORY_BUFFER + 1):
				same_category_buffer[pos + Vector2i(dx, dy)] = true
		placed.append({"pos": pos, "scene": scene_name})
	return placed
