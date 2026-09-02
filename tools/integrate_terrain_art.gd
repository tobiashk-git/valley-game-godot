extends SceneTree
# Phase 7a: replaces every placeholder ground/wall/floor/hazard/divider
# texture with a real crop from the staged LPC packs (assets_source/lpc/).
# Every target is a plain 32x32 single-tile TileSetAtlasSource - overwriting
# the PNG at its existing path is the entire integration step, no scene/
# TileSet changes needed (see the approved plan). Uses Image.load_from_file()
# (raw file read, not res:// resource loading) since assets_source/ is
# deliberately kept outside Godot's import pipeline.
# Run via: godot --headless --script res://tools/integrate_terrain_art.gd

const TERRAIN_V7 := "res://assets_source/lpc/terrains/lpc-terrains/terrain-v7.png"
const BRIDGES := "res://assets_source/lpc/base_assets/LPC Base Assets/tiles/bridges.png"
const LAVAROCK := "res://assets_source/lpc/base_assets/LPC Base Assets/tiles/lavarock.png"
const LAVA := "res://assets_source/lpc/base_assets/LPC Base Assets/tiles/lava.png"
const BRACKISH := "res://assets_source/lpc/base_assets/LPC Base Assets/tiles/brackish.png"
const CAVERN_RUINS := "res://assets_source/lpc/cavern_ruins/LPC_cavern_ruins/cavern_ruins.png"

const TILE := 32
const COLS := 32 # terrain-v7.png's column count, for tile-index -> pixel math

# Each entry: target asset path -> [source const, rect]. terrain-v7.png
# entries give a labeled tile INDEX (converted to a rect below); the other
# sheets give an already-confirmed pixel rect directly (visually verified -
# see the approved plan).
const TERRAIN_INDEX_MAP := {
	"res://assets/snow.png": 339,               # Snow_1 (Frostpeak ground)
	"res://assets/frostpeak_wall.png": 787,      # Stone_White
	"res://assets/frostpeak_floor.png": 342,     # Snow_2
	"res://assets/frostpeak_ice.png": 838,       # Ice
	"res://assets/forest_ground.png": 327,       # Grass_Dark (Verdantwood ground)
	"res://assets/verdantwood_floor.png": 333,   # Soil
	"res://assets/verdantwood_canopy.png": 327,  # Grass_Dark, reused
	"res://assets/verdantwood_root.png": 348,    # Dirt_Roots
	"res://assets/sand.png": 336,                # Sand (Badlands ground)
	"res://assets/badlands_floor.png": 784,      # Earth_Cracked
	"res://assets/badlands_rim.png": 784,        # Earth_Cracked, reused
	"res://assets/hills_ground.png": 124,        # Mud_Brown (Gloomfen ground)
	"res://assets/gloomfen_wall.png": 793,       # Mudstone_Gray
	"res://assets/gloomfen_floor.png": 796,      # Mudstone_Brown
	"res://assets/golden_plains_wall.png": 790,  # Stone_Tan
	"res://assets/golden_plains_floor.png": 97,  # Dirt_Tan
	"res://assets/river.png": 548,               # Water
	"res://assets/ford.png": 545,                # Water_Shallows_Dirt
	"res://assets/ravine.png": 121,              # Hole_Black
}

const RECT_MAP := {
	"res://assets/frostpeak_bridge.png": {"src": "bridges", "rect": Rect2i(96, 128, 32, 32)},
	"res://assets/gloomfen_platform.png": {"src": "bridges", "rect": Rect2i(96, 128, 32, 32)},
	"res://assets/badlands_wall.png": {"src": "lavarock", "rect": Rect2i(32, 96, 32, 32)},
	"res://assets/badlands_geyser.png": {"src": "lava", "rect": Rect2i(32, 96, 32, 32)},
	"res://assets/gloomfen_mud.png": {"src": "brackish", "rect": Rect2i(32, 96, 32, 32)},
	"res://assets/verdantwood_wall.png": {"src": "cavern_ruins", "rect": Rect2i(416, 0, 32, 32)},
}

func _crop(img: Image, rect: Rect2i) -> Image:
	var out := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, rect, Vector2i(0, 0))
	return out

func _initialize() -> void:
	print("=== Terrain art integration starting ===")

	var terrain_img: Image = Image.load_from_file(TERRAIN_V7)
	for target in TERRAIN_INDEX_MAP:
		var idx: int = TERRAIN_INDEX_MAP[target]
		var tx: int = idx % COLS
		var ty: int = idx / COLS
		var crop := _crop(terrain_img, Rect2i(tx * TILE, ty * TILE, TILE, TILE))
		var err := crop.save_png(target)
		print(target, " <- terrain-v7 idx ", idx, ": ", err)

	var sources := {
		"bridges": Image.load_from_file(BRIDGES),
		"lavarock": Image.load_from_file(LAVAROCK),
		"lava": Image.load_from_file(LAVA),
		"brackish": Image.load_from_file(BRACKISH),
		"cavern_ruins": Image.load_from_file(CAVERN_RUINS),
	}
	for target in RECT_MAP:
		var entry: Dictionary = RECT_MAP[target]
		var src_img: Image = sources[entry.src]
		var crop := _crop(src_img, entry.rect)
		var err := crop.save_png(target)
		print(target, " <- ", entry.src, " ", entry.rect, ": ", err)

	print("=== Terrain art integration complete ===")
	quit()
