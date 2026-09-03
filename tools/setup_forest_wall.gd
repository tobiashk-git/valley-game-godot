extends SceneTree
# Adds SRC_FOREST_WALL (14) - the solid-collision tile underlying the
# Verdantwood overland maze's walls (Phase 1 prototype, see
# World.carve_verdantwood_maze()) - to both Overworld.tscn and
# Overworld2.tscn's embedded TileSets, same "instantiate the live scene, edit
# the real tilemap.tile_set, pack+save back over the .tscn" technique as
# tools/setup_mountain_range.gd. Added to BOTH scenes even though Phase 1
# only calls carve_verdantwood_maze() from Overworld.tscn, so bringing the
# maze to Overworld2.tscn later is a pure GDScript change with no
# art/tooling work left.
#
# No new art needed, unlike every other terrain source added this project -
# reuses forest_ground.png (SRC_VERDANTWOOD's own already-integrated
# dithered ground texture) directly, just with full-tile collision added.
# The actual "this is a thick forest" visual comes from real MightyOak props
# densely instanced along the wall mass's visible boundary (see
# carve_verdantwood_maze()'s boundary_positions / overworld.gd's wiring) - their
# canopies do the visual work, so the tile underneath just needs to read as
# plain forest floor for the slivers that peek through, exactly like the
# ground everywhere else in this biome already does.
# Run via: godot --headless --script res://tools/setup_forest_wall.gd

const SCENES := ["res://scenes/Overworld.tscn", "res://scenes/Overworld2.tscn"]
const SRC_FOREST_WALL := 14
const TEX_PATH := "res://assets/forest_ground.png"
const FULL_TILE_COLLISION: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]

func _initialize() -> void:
	print("=== Forest wall TileSet setup starting ===")

	for scene_path in SCENES:
		var world: Node2D = load(scene_path).instantiate()
		var tilemap: TileMapLayer = world.get_node("TileMapLayer")
		var tile_set: TileSet = tilemap.tile_set

		if tile_set.has_source(SRC_FOREST_WALL):
			print(scene_path, ": source ", SRC_FOREST_WALL, " already present, skipping")
		else:
			var source := TileSetAtlasSource.new()
			source.texture = load(TEX_PATH)
			source.texture_region_size = Vector2i(32, 32)
			source.create_tile(Vector2i(0, 0))
			source.create_tile(Vector2i(1, 0))
			tile_set.add_source(source, SRC_FOREST_WALL)
			for coord in [Vector2i(0, 0), Vector2i(1, 0)]:
				var tile_data: TileData = source.get_tile_data(coord, 0)
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, FULL_TILE_COLLISION)
			print(scene_path, ": added source ", SRC_FOREST_WALL, " (2 tiles, both solid)")

		var packed := PackedScene.new()
		packed.pack(world)
		var err := ResourceSaver.save(packed, scene_path)
		print(scene_path, " saved: ", err)

	print("=== Forest wall TileSet setup complete ===")
	quit()
