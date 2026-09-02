extends SceneTree
# Adds SRC_RIVER (9) and SRC_FORD (10) to the shared overworld TileSet - see
# tools/setup_phase1.gd for how the other 9 sources were originally built.
# Needs two runs: the first generates river.png/ford.png placeholder
# textures (flat-color squares, same idea as tools/setup_item_icons.gd)
# which aren't load()-able until Godot's import pipeline has seen them - run
# `godot --headless --import` between the two runs (this script tells you
# when that's needed and exits early rather than erroring).
# Run via: godot --headless --script res://tools/setup_biome_revamp.gd

const FULL_TILE_COLLISION: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]

func _make_placeholder(color: Color, path: String) -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(color)
	img.save_png(path)

func _add_source(tile_set: TileSet, path: String, id: int, solid: bool = false) -> void:
	var tex: Texture2D = load(path)
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(32, 32)
	source.create_tile(Vector2i(0, 0))
	tile_set.add_source(source, id)
	if solid:
		var tile_data: TileData = source.get_tile_data(Vector2i(0, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, FULL_TILE_COLLISION)

func _initialize() -> void:
	print("=== Biome revamp TileSet setup starting ===")

	if not FileAccess.file_exists("res://assets/river.png"):
		_make_placeholder(Color(0.15, 0.35, 0.75), "res://assets/river.png") # blue, solid
		_make_placeholder(Color(0.55, 0.45, 0.25), "res://assets/ford.png")  # muddy tan, walkable
		print("Placeholder river/ford textures generated.")
		print("Run: godot --headless --import")
		print("Then run this script again to add them to the TileSet.")
		quit()
		return

	var tile_set: TileSet = load("res://resources/overworld_tileset.tres")
	if tile_set.has_source(9):
		print("Sources 9/10 already present - nothing to do.")
		quit()
		return

	_add_source(tile_set, "res://assets/river.png", 9, true)  # solid - blocks movement
	_add_source(tile_set, "res://assets/ford.png", 10, false) # walkable

	var err := ResourceSaver.save(tile_set, "res://resources/overworld_tileset.tres")
	print("overworld_tileset.tres updated with river/ford sources: ", err)
	print("=== Biome revamp TileSet setup complete ===")
	quit()
