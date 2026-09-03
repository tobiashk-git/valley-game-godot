extends SceneTree
# Adds SRC_MOUNTAIN (12) - the permanent, impassable divider between
# adjacent outer biomes that replaced the old wedge-seam river/ravine
# crossings - to both Overworld.tscn and Overworld2.tscn's embedded
# TileSets. Same "instantiate the live scene, edit the real tilemap.tile_set,
# pack+save back over the .tscn" technique as tools/setup_wedge_seam_ravine.gd
# (SRC_RAVINE), but looped over BOTH scenes from the start - unlike that
# tool, which only ever touched Overworld.tscn, leaving Overworld2.tscn
# without it (a known, now-irrelevant inconsistency; see
# tools/setup_terrain_variety.gd for the established both-scenes pattern).
#
# Two-phase like every "generate placeholder -> import -> real run" tool
# here: if mountain_range.png doesn't exist yet, this generates a plain
# placeholder and exits with instructions - run `godot --headless --import`
# then run this again once the real 64x32 fill+flecked art is in place at
# res://assets/mountain_range.png.
# Run via: godot --headless --script res://tools/setup_mountain_range.gd

const SCENES := ["res://scenes/Overworld.tscn", "res://scenes/Overworld2.tscn"]
const SRC_MOUNTAIN := 12
const TEX_PATH := "res://assets/mountain_range.png"
const FULL_TILE_COLLISION: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]

func _make_placeholder() -> void:
	var img := Image.create(64, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(0.4, 0.38, 0.36)) # neutral gray-brown stone, solid
	img.save_png(TEX_PATH)

func _initialize() -> void:
	print("=== Mountain range TileSet setup starting ===")

	if not FileAccess.file_exists(TEX_PATH):
		_make_placeholder()
		print("Placeholder mountain_range.png generated.")
		print("Run: godot --headless --import")
		print("Then run this script again to add it to both scenes' TileSets.")
		quit()
		return

	for scene_path in SCENES:
		var world: Node2D = load(scene_path).instantiate()
		var tilemap: TileMapLayer = world.get_node("TileMapLayer")
		var tile_set: TileSet = tilemap.tile_set

		if tile_set.has_source(SRC_MOUNTAIN):
			print(scene_path, ": source ", SRC_MOUNTAIN, " already present, skipping")
		else:
			var source := TileSetAtlasSource.new()
			source.texture = load(TEX_PATH)
			source.texture_region_size = Vector2i(32, 32)
			source.create_tile(Vector2i(0, 0))
			source.create_tile(Vector2i(1, 0))
			tile_set.add_source(source, SRC_MOUNTAIN)
			for coord in [Vector2i(0, 0), Vector2i(1, 0)]:
				var tile_data: TileData = source.get_tile_data(coord, 0)
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, FULL_TILE_COLLISION)
			print(scene_path, ": added source ", SRC_MOUNTAIN, " (2 tiles, both solid)")

		var packed := PackedScene.new()
		packed.pack(world)
		var err := ResourceSaver.save(packed, scene_path)
		print(scene_path, " saved: ", err)

	print("=== Mountain range TileSet setup complete ===")
	quit()
