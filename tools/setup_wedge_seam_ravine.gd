extends SceneTree
# Adds SRC_RAVINE (11) directly to Overworld.tscn's embedded TileSet - see
# the "embedded TileSet vs external .tres" gotcha (project_godot_port.md):
# Overworld.tscn's TileMapLayer.tile_set is a SubResource baked into the
# .tscn itself, NOT a reference to res://resources/overworld_tileset.tres,
# so editing that external file (the way tools/setup_biome_revamp.gd's own
# comment implies) would silently do nothing to what the scene actually uses
# at runtime. Fix: instantiate the real scene, read tilemap.tile_set off the
# live node, edit *that*, then pack + save the instance back over the .tscn.
#
# The Verdantwood-Badlands wedge seam gets its own distinct canyon/chasm
# texture (the roadmap names it apart from the other 3 plain "wedge-seam
# rivers"); those 3 just reuse the existing SRC_RIVER.
# Needs two runs, same two-phase placeholder pattern as setup_biome_revamp.gd:
# the first generates ravine.png, which isn't load()-able until Godot's
# import pipeline has seen it - run `godot --headless --import` between the
# two runs (this script tells you when that's needed and exits early).
# Run via: godot --headless --script res://tools/setup_wedge_seam_ravine.gd

const FULL_TILE_COLLISION: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]

func _make_placeholder(color: Color, path: String) -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(color)
	img.save_png(path)

func _initialize() -> void:
	print("=== Wedge-seam ravine TileSet setup starting ===")

	if not FileAccess.file_exists("res://assets/ravine.png"):
		_make_placeholder(Color(0.28, 0.18, 0.12), "res://assets/ravine.png") # dark canyon rock, solid
		print("Placeholder ravine texture generated.")
		print("Run: godot --headless --import")
		print("Then run this script again to add it to the scene's TileSet.")
		quit()
		return

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	var tilemap: TileMapLayer = overworld.get_node("TileMapLayer")
	var tile_set: TileSet = tilemap.tile_set

	if tile_set.has_source(11):
		print("Source 11 already present - nothing to do.")
		quit()
		return

	var source := TileSetAtlasSource.new()
	source.texture = load("res://assets/ravine.png")
	source.texture_region_size = Vector2i(32, 32)
	source.create_tile(Vector2i(0, 0))
	tile_set.add_source(source, 11)
	var tile_data: TileData = source.get_tile_data(Vector2i(0, 0), 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, FULL_TILE_COLLISION)

	var packed := PackedScene.new()
	packed.pack(overworld)
	var err := ResourceSaver.save(packed, "res://scenes/Overworld.tscn")
	print("Overworld.tscn updated with ravine source: ", err)
	print("=== Wedge-seam ravine TileSet setup complete ===")
	quit()
