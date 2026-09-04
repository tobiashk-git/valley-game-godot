extends Node
# Autoload — fast-travel destinations, port of worldmap.js's POI list +
# travelTo(). Fast travel always goes through GameState.next_spawn_position
# + a scene change to Overworld.tscn, whether the player is already there or
# in an interior - one code path instead of two, at the cost of the
# Overworld's trees/rocks re-scattering into new spots on a same-scene
# "travel" (harmless, just a quirk of reusing change_scene_to_file()
# unconditionally rather than a separate in-place-reposition path).

signal changed

const POI_NAMES := {
	"house": "Your House",
	"village": "Village",
	"dungeon": "Dungeon",
	"castle": "Castle",
	"frostpeak_interior": "Frostpeak Ice Caves",
	"verdantwood_interior": "Verdantwood Grove",
	"badlands_interior": "Emberfall Caldera",
	"gloomfen_interior": "Sunken Gloomfen Temple",
	"golden_plains_interior": "The Ancient Barrow",
}

# One line per place for the map's detail pane (UI redesign Phase 3b).
const POI_DESCRIPTIONS := {
	"house": "Home. A bed to rest in and a chest for whatever you'd rather not carry.",
	"village": "The valley's only village: the Elder, the Trader and the altar are here.",
	"dungeon": "A maze of stone under the northern hills. The Bone Lord waits at its heart.",
	"castle": "The old keep east of the village, haunted by the Royal Wraith.",
	"frostpeak_interior": "Ice caves beyond the northern ford, high on Frostpeak Ridge.",
	"verdantwood_interior": "A grove deep in Verdantwood Forest, past the eastern ford.",
	"badlands_interior": "The caldera at the heart of the Emberfall Badlands, south across the ford.",
	"gloomfen_interior": "A temple sunk in the Gloomfen Marsh, west beyond the ford.",
	"golden_plains_interior": "An ancient barrow opened in the plains north-west of the village.",
}

# Which place the player "is at" while inside a scene (for the map's you-
# are-here marker); the Overworld uses the player's own tile instead.
const SCENE_POIS := {
	"House": "house",
	"ElderHouse": "village",
	"TraderHouse": "village",
	"EmptyHouse": "village",
	"Dungeon": "dungeon",
	"Castle": "castle",
	"FrostpeakInterior": "frostpeak_interior",
	"VerdantwoodInterior": "verdantwood_interior",
	"BadlandsInterior": "badlands_interior",
	"GloomfenInterior": "gloomfen_interior",
	"GoldenPlainsInterior": "golden_plains_interior",
}

# Map colours per TileSet source id (World.SRC_*), the "pixel map" palette.
const MAP_COLOURS := {
	World.SRC_GRASS: Color(0.47, 0.66, 0.31),
	World.SRC_FROSTPEAK: Color(0.86, 0.9, 0.95),
	World.SRC_BADLANDS: Color(0.84, 0.66, 0.36),
	World.SRC_VERDANTWOOD: Color(0.2, 0.45, 0.22),
	World.SRC_GLOOMFEN: Color(0.36, 0.44, 0.32),
	World.SRC_PATH: Color(0.72, 0.62, 0.42),
	World.SRC_FENCE: Color(0.45, 0.3, 0.16),
	World.SRC_GATE: Color(0.62, 0.45, 0.24),
	World.SRC_ALTAR: Color(0.85, 0.85, 0.95),
	World.SRC_RIVER: Color(0.25, 0.47, 0.8),
	World.SRC_FORD: Color(0.55, 0.72, 0.86),
	World.SRC_MOUNTAIN: Color(0.5, 0.47, 0.44),
	World.SRC_GLOOMFEN_WATER: Color(0.3, 0.5, 0.65),
	World.SRC_FOREST_WALL: Color(0.12, 0.3, 0.13),
}

const LOCATION_NAMES := {
	"Overworld": "the Valley",
	"Dungeon": "the Dungeon",
	"Castle": "the Castle",
	"House": "your House",
	"ElderHouse": "the Elder's House",
	"TraderHouse": "the Trader's House",
	"EmptyHouse": "an empty house",
	"FrostpeakInterior": "the Ice Caves",
	"VerdantwoodInterior": "the Verdantwood Grove",
	"BadlandsInterior": "the Caldera",
	"GloomfenInterior": "the Sunken Temple",
	"GoldenPlainsInterior": "the Ancient Barrow",
}

# Computed lazily (not a const dict) since it reads World.VILLAGE_GATES,
# which is a `var` there, not a compile-time constant.
func poi_target(poi_id: String) -> Vector2:
	match poi_id:
		"house":
			return Vector2(World.HOUSE_ENTRANCE.x * 32 + 16, (World.HOUSE_ENTRANCE.y + 1) * 32 + 16)
		"village":
			var t: Vector2i = World.VILLAGE_GATES.south + Vector2i(0, -2)
			return Vector2(t.x * 32 + 16, t.y * 32 + 16)
		"dungeon":
			return Vector2(World.DUNGEON_ENTRANCE.x * 32 + 16, (World.DUNGEON_ENTRANCE.y + 1) * 32 + 16)
		"castle":
			return Vector2(World.CASTLE_ENTRANCE.x * 32 + 16, (World.CASTLE_ENTRANCE.y + 1) * 32 + 16)
		"frostpeak_interior":
			return Vector2(World.FROSTPEAK_INTERIOR_ENTRANCE.x * 32 + 16, (World.FROSTPEAK_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		"verdantwood_interior":
			return Vector2(World.VERDANTWOOD_INTERIOR_ENTRANCE.x * 32 + 16, (World.VERDANTWOOD_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		"badlands_interior":
			return Vector2(World.BADLANDS_INTERIOR_ENTRANCE.x * 32 + 16, (World.BADLANDS_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		"gloomfen_interior":
			return Vector2(World.GLOOMFEN_INTERIOR_ENTRANCE.x * 32 + 16, (World.GLOOMFEN_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		"golden_plains_interior":
			return Vector2(World.GOLDEN_PLAINS_INTERIOR_ENTRANCE.x * 32 + 16, (World.GOLDEN_PLAINS_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		_:
			return Vector2.ZERO

# The place's tile on the Overworld (where fast travel lands).
func poi_tile(poi_id: String) -> Vector2i:
	var target: Vector2 = poi_target(poi_id)
	return Vector2i(floori(target.x / 32.0), floori(target.y / 32.0))

# Player-facing "where" line for a place: the biome, with the village named
# when the tile is inside its fence.
func poi_where(poi_id: String) -> String:
	var tile: Vector2i = poi_tile(poi_id)
	var biome: String = World.ZONE_NAMES.get(World.biome_at(tile.x, tile.y).zone, "")
	var b: Dictionary = World.VILLAGE_BOUNDS
	if tile.x >= b.x0 and tile.x <= b.x1 and tile.y >= b.y0 and tile.y <= b.y1:
		return "Village, " + biome
	return biome

# The tile the player is at, for the map's marker: their own tile on the
# Overworld, the entrance of the place they're inside, or (-1,-1) when the
# map doesn't apply (World 2).
func here_tile() -> Vector2i:
	var current: Node = get_tree().current_scene
	if current == null:
		return Vector2i(-1, -1)
	if current.name == "Overworld":
		var player: Node2D = current.get_node_or_null("YSort/Player")
		if player != null:
			return Vector2i(floori(player.position.x / 32.0), floori(player.position.y / 32.0))
	if SCENE_POIS.has(current.name):
		return poi_tile(SCENE_POIS[current.name])
	return Vector2i(-1, -1)

func discovered_count() -> int:
	var n := 0
	for poi_id in POI_NAMES:
		if is_discovered(poi_id):
			n += 1
	return n

# Renders the Overworld as a one-pixel-per-tile image straight from the
# real world builder (World.build_overworld_map() into a detached
# TileMapLayer - it needs no TileSet to hold cells), plus the current
# state's open fords and gates. Random scatter (trees, lakes, the
# Verdantwood maze) is deliberately absent: the map is a chart, not a
# screenshot. Ground tiles get the same deterministic fleck the terrain
# uses so the biomes read as textured rather than flat.
func render_map(region: Rect2i) -> ImageTexture:
	var tilemap := TileMapLayer.new()
	World.build_overworld_map(tilemap)
	for zone in GameState.biome_paths_open.keys():
		if GameState.biome_paths_open[zone]:
			World.open_biome_path(tilemap, World.Zone[zone.to_upper()])
	if GameState.village_gates_open:
		World.open_gates(tilemap)
	var img := Image.create(region.size.x, region.size.y, false, Image.FORMAT_RGBA8)
	for y in range(region.size.y):
		for x in range(region.size.x):
			var tile := Vector2i(region.position.x + x, region.position.y + y)
			var source: int = tilemap.get_cell_source_id(tile)
			var colour: Color = MAP_COLOURS.get(source, Color(0.1, 0.1, 0.1))
			if (source in World.OUTER_BIOME_SOURCES or source == World.SRC_GRASS or source == World.SRC_MOUNTAIN) and (tile.x * 17 + tile.y * 11) % 3 == 0:
				colour = colour.darkened(0.07)
			img.set_pixel(x, y, colour)
	tilemap.free()
	return ImageTexture.create_from_image(img)

func is_discovered(poi_id: String) -> bool:
	return GameState.discovered_pois.get(poi_id, false)

func current_location_name() -> String:
	var current: Node = get_tree().current_scene
	var scene_name: String = current.name if current else ""
	return LOCATION_NAMES.get(scene_name, scene_name)

func travel_to(poi_id: String) -> void:
	if not is_discovered(poi_id):
		return
	GameState.set_next_spawn(poi_target(poi_id))
	get_tree().change_scene_to_file("res://scenes/Overworld.tscn")
