extends SceneTree
# Phase 7c: widens the 4 outdoor-biome ground textures from a single 32x32
# tile to a 64x32 strip (fill tile + a "flecked/textured" sibling variant a
# couple of rows below it in the same terrain-v7.png block), so
# build_biome_layer() can dither between two real tiles instead of repeating
# one. Overwrites the existing Phase 7a PNGs in place.
# Run via: godot --headless --script res://tools/integrate_terrain_variety.gd

const TERRAIN_V7 := "res://assets_source/lpc/terrains/lpc-terrains/terrain-v7.png"
const TILE := 32

# target asset path -> [fill tile index, flecked-variant tile index]
const VARIETY_MAP := {
	"res://assets/snow.png": [339, 403],          # Snow_1 fill / flecked (Frostpeak)
	"res://assets/sand.png": [336, 400],          # Sand fill / flecked (Badlands)
	"res://assets/forest_ground.png": [327, 391], # Grass_Dark fill / flecked (Verdantwood)
	"res://assets/hills_ground.png": [124, 188],  # Mud_Brown fill / flecked (Gloomfen)
}
const COLS := 32

func _tile_rect(idx: int) -> Rect2i:
	var tx := idx % COLS
	var ty := idx / COLS
	return Rect2i(tx * TILE, ty * TILE, TILE, TILE)

func _initialize() -> void:
	print("=== Terrain variety integration starting ===")

	var terrain_img: Image = Image.load_from_file(TERRAIN_V7)
	for target in VARIETY_MAP:
		var indices: Array = VARIETY_MAP[target]
		var strip := Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)
		strip.blit_rect(terrain_img, _tile_rect(indices[0]), Vector2i(0, 0))
		strip.blit_rect(terrain_img, _tile_rect(indices[1]), Vector2i(TILE, 0))
		var err := strip.save_png(target)
		print(target, " <- terrain-v7 idx ", indices[0], "+", indices[1], ": ", err)

	print("=== Terrain variety integration complete ===")
	quit()
