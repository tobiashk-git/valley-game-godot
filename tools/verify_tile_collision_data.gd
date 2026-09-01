extends SceneTree

func _initialize() -> void:
	var tile_set: TileSet = load("res://resources/dungeon_terrain_tileset.tres")
	print("Loaded tileset, physics layers: ", tile_set.get_physics_layers_count())
	var source: TileSetAtlasSource = tile_set.get_source(0) # wall
	var tile_data: TileData = source.get_tile_data(Vector2i(0, 0), 0)
	print("Wall source tile collision polygon count: ", tile_data.get_collision_polygons_count(0))
	if tile_data.get_collision_polygons_count(0) > 0:
		print("Points: ", tile_data.get_collision_polygon_points(0, 0))

	var floor_source: TileSetAtlasSource = tile_set.get_source(1) # floor
	var floor_data: TileData = floor_source.get_tile_data(Vector2i(0, 0), 0)
	print("Floor source tile collision polygon count (should be 0): ", floor_data.get_collision_polygons_count(0))

	quit()
