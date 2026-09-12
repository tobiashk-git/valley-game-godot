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
	"BlacksmithHouse": "village",
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

# Fog of war (2026-09-12): the Map tab shows only the ground Oliver has
# walked near (GameState.overworld_revealed) plus a small circle around any
# lair a hunt quest has named - so the hunt text's directions and the chart
# agree. A named-but-unvisited place is "rumoured": a hollow marker, no
# fast travel, until its portal is walked through (discovered_pois).
const LAIR_OF_BOSS := {
	"golden_plains_boss": "golden_plains_interior", "dungeon_boss": "dungeon",
	"frostpeak_boss": "frostpeak_interior", "verdantwood_boss": "verdantwood_interior",
	"badlands_boss": "badlands_interior", "gloomfen_boss": "gloomfen_interior",
	"castle_boss": "castle", "final_boss": "final_boss",
}
const LAIR_REVEAL_RADIUS := 4
const FOG_COLOUR := Color(0.2, 0.17, 0.13)
const FOG_EDGE_BLEND := 0.6

const LOCATION_NAMES := {
	"Overworld": "the Valley",
	"Dungeon": "the Dungeon",
	"Castle": "the Castle",
	"House": "your House",
	"ElderHouse": "the Elder's House",
	"TraderHouse": "the Trader's House",
	"BlacksmithHouse": "the Blacksmith's",
	"FrostpeakInterior": "the Ice Caves",
	"VerdantwoodInterior": "the Verdantwood Grove",
	"BadlandsInterior": "the Caldera",
	"GloomfenInterior": "the Sunken Temple",
	"GoldenPlainsInterior": "the Ancient Barrow",
}

# Computed lazily (not a const dict) since it reads World.VILLAGE_GATES,
# which is a `var` there, not a compile-time constant.
func poi_target(poi_id: String) -> Vector2:
	# Movable places (dungeons, interiors, the barrow): wherever the recipe put them.
	if World.PLACE_DEFAULTS.has(poi_id):
		var t: Vector2i = World.place(poi_id)
		return Vector2(t.x * 32 + 16, (t.y + 1) * 32 + 16)
	match poi_id:
		"house":
			return Vector2(World.HOUSE_ENTRANCE.x * 32 + 16, (World.HOUSE_ENTRANCE.y + 1) * 32 + 16)
		"village":
			var t: Vector2i = World.VILLAGE_GATES.south + Vector2i(0, -2)
			return Vector2(t.x * 32 + 16, t.y * 32 + 16)
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
# `fog`: true for the Map tab (unrevealed tiles in FOG_COLOUR, the rim one
# tile out blended so the edge reads soft); false for the title backdrop
# and the designer, which want the whole chart.
func render_map(region: Rect2i, fog: bool = false) -> ImageTexture:
	var tilemap := TileMapLayer.new()
	World.build_overworld_map(tilemap)
	MapRecipe.apply_tiles(tilemap, MapRecipe.load_active()) # the chart shows designed tiles too
	for zone in GameState.biome_paths_open.keys():
		if GameState.biome_paths_open[zone]:
			World.open_biome_path(tilemap, World.Zone[zone.to_upper()])
	if GameState.village_gates_open:
		World.open_gates(tilemap)
	var w: int = region.size.x
	var h: int = region.size.y
	var revealed := PackedByteArray()
	if fog:
		var named: Dictionary = named_places()
		revealed.resize(w * h)
		for y in range(h):
			for x in range(w):
				revealed[y * w + x] = 1 if is_tile_revealed(region.position + Vector2i(x, y), named) else 0
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var tile := Vector2i(region.position.x + x, region.position.y + y)
			var source: int = tilemap.get_cell_source_id(tile)
			var colour: Color = MAP_COLOURS.get(source, Color(0.1, 0.1, 0.1))
			var fleck: bool = (tile.x * 17 + tile.y * 11) % 3 == 0
			if (source in World.OUTER_BIOME_SOURCES or source == World.SRC_GRASS or source == World.SRC_MOUNTAIN) and fleck:
				colour = colour.darkened(0.07)
			if fog and revealed[y * w + x] == 0:
				var edge := false
				for ny in range(maxi(0, y - 1), mini(h, y + 2)):
					for nx in range(maxi(0, x - 1), mini(w, x + 2)):
						if revealed[ny * w + nx] == 1:
							edge = true
				if edge:
					colour = colour.lerp(FOG_COLOUR, FOG_EDGE_BLEND)
				else:
					colour = FOG_COLOUR.darkened(0.06) if fleck else FOG_COLOUR
			img.set_pixel(x, y, colour)
	tilemap.free()
	return ImageTexture.create_from_image(img)

func is_discovered(poi_id: String) -> bool:
	return GameState.discovered_pois.get(poi_id, false)

# Places a hunt quest has named (accepted or done) -> true. Derived from the
# quest state each time, so a Story jump or a load needs no extra step.
func named_places() -> Dictionary:
	var out: Dictionary = {}
	var quests: Node = get_node("/root/Quests")
	for quest_id in quests.QUEST_DEFS:
		var state: String = str(quests.quest_state.get(quest_id, ""))
		if state != "accepted" and state != "completed":
			continue
		var objective: Dictionary = quests.QUEST_DEFS[quest_id].get("objective", {})
		if objective.get("type", "") != "defeat_bosses":
			continue
		for boss_id in objective.get("boss_ids", []):
			if LAIR_OF_BOSS.has(boss_id):
				out[LAIR_OF_BOSS[boss_id]] = true
	return out

func is_named(poi_id: String) -> bool:
	return named_places().has(poi_id)

# Walked past its door (the entrance tile is inside the walked-near fog
# record) - the user found the barred dungeon and expected it on the map
# (2026-09-12). Found places get a marker and their description; Fast
# Travel still needs a real visit (discovered). The barrow only counts
# once it has actually appeared.
func is_seen(poi_id: String) -> bool:
	if poi_id == "golden_plains_interior" and not GameState.world_progress.get("golden_plains_revealed", false):
		return false
	return GameState.is_overworld_revealed(poi_tile(poi_id))

# On the map at all: walked through (discovered), walked past (seen) or
# named by a hunt (rumoured).
func is_shown(poi_id: String) -> bool:
	return is_discovered(poi_id) or is_seen(poi_id) or is_named(poi_id)

# The tile a named place stands on (movable places from the recipe, the
# house / village from their fixed spots).
func place_tile(place_id: String) -> Vector2i:
	if World.PLACE_DEFAULTS.has(place_id):
		return World.place(place_id)
	return poi_tile(place_id)

# Walked near, or inside a named lair's circle. `named` = named_places().
func is_tile_revealed(tile: Vector2i, named: Dictionary) -> bool:
	if GameState.is_overworld_revealed(tile):
		return true
	var r2: int = LAIR_REVEAL_RADIUS * LAIR_REVEAL_RADIUS
	for place_id in named:
		var d: Vector2i = tile - place_tile(place_id)
		if d.x * d.x + d.y * d.y <= r2:
			return true
	return false

# Whole percent of a region Oliver has walked near (the subtitle's nudge).
func explored_percent(region: Rect2i) -> int:
	var area: int = region.size.x * region.size.y
	if area <= 0:
		return 0
	return int(round(100.0 * GameState.overworld_revealed_count(region) / area))

func current_location_name() -> String:
	var current: Node = get_tree().current_scene
	var scene_name: String = current.name if current else ""
	return LOCATION_NAMES.get(scene_name, scene_name)

func travel_to(poi_id: String) -> void:
	if not is_discovered(poi_id):
		return
	GameState.set_next_spawn(poi_target(poi_id))
	get_tree().change_scene_to_file("res://scenes/Overworld.tscn")
