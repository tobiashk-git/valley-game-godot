extends SceneTree
# Builds the castle terrain TileSet and Castle.tscn — same shape as
# tools/setup_dungeon.gd (both scenes share scripts/maze_interior.gd),
# just pointed at castle wall/floor art and the castle boss/entrance,
# reusing the already-built fog_tileset.tres as-is (fog needs no
# location-specific look).
# Run via: godot --headless --script res://tools/setup_castle.gd

const FULL_TILE_COLLISION: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]

func _add_source(tile_set: TileSet, path: String, id: int, solid: bool = false) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(path)
	source.texture_region_size = Vector2i(32, 32)
	source.create_tile(Vector2i(0, 0))
	tile_set.add_source(source, id)
	if solid:
		var tile_data: TileData = source.get_tile_data(Vector2i(0, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, FULL_TILE_COLLISION)

func _initialize() -> void:
	print("=== Castle setup starting ===")

	var terrain_tileset := TileSet.new()
	terrain_tileset.tile_size = Vector2i(32, 32)
	terrain_tileset.add_physics_layer()
	_add_source(terrain_tileset, "res://assets/castle_wall.png", 0, true)
	_add_source(terrain_tileset, "res://assets/castle_floor.png", 1, false)
	ResourceSaver.save(terrain_tileset, "res://resources/castle_terrain_tileset.tres")

	var fog_tileset: TileSet = load("res://resources/fog_tileset.tres")

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"

	var root := Node2D.new()
	root.name = "Castle"
	root.set_script(load("res://scripts/maze_interior.gd"))
	root.boss_id = "castle_boss"
	root.entrance_tile = World.CASTLE_ENTRANCE
	root.poi_id = "castle"

	var terrain := TileMapLayer.new()
	terrain.name = "TerrainLayer"
	terrain.tile_set = terrain_tileset
	root.add_child(terrain)
	terrain.owner = root

	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	root.add_child(ysort)
	ysort.owner = root

	ysort.add_child(player_instance)
	player_instance.owner = root

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.5, 1.5)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player_instance.add_child(camera)
	camera.owner = root

	# Added last so it draws on top of the terrain and the player/props,
	# which is what lets it actually occlude them.
	var fog := TileMapLayer.new()
	fog.name = "FogLayer"
	fog.tile_set = fog_tileset
	root.add_child(fog)
	fog.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/Castle.tscn")
	print("Castle.tscn saved: ", err)

	print("=== Castle setup complete ===")
	quit()
