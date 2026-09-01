extends SceneTree
# Builds the dungeon terrain TileSet, the fog TileSet, and Dungeon.tscn.
# Run via: godot --headless --script res://tools/setup_dungeon.gd

const FULL_TILE_COLLISION: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]

func _add_source(tile_set: TileSet, path: String, id: int, solid: bool = false) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(path)
	source.texture_region_size = Vector2i(32, 32)
	source.create_tile(Vector2i(0, 0))
	# The source must be attached to the TileSet (which already has its
	# physics layer added) *before* writing collision data into its TileData —
	# a standalone, not-yet-attached source has no physics-layer context for
	# add_collision_polygon() to write into, so it silently no-ops.
	tile_set.add_source(source, id)
	if solid:
		var tile_data: TileData = source.get_tile_data(Vector2i(0, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, FULL_TILE_COLLISION)

func _initialize() -> void:
	print("=== Dungeon setup starting ===")

	var terrain_tileset := TileSet.new()
	terrain_tileset.tile_size = Vector2i(32, 32)
	terrain_tileset.add_physics_layer()
	_add_source(terrain_tileset, "res://assets/dungeon_wall.png", 0, true)
	_add_source(terrain_tileset, "res://assets/dungeon_floor.png", 1, false)
	ResourceSaver.save(terrain_tileset, "res://resources/dungeon_terrain_tileset.tres")

	var fog_tileset := TileSet.new()
	fog_tileset.tile_size = Vector2i(32, 32)
	_add_source(fog_tileset, "res://assets/fog_black.png", 0)
	ResourceSaver.save(fog_tileset, "res://resources/fog_tileset.tres")

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"

	var root := Node2D.new()
	root.name = "Dungeon"
	root.set_script(load("res://scripts/dungeon.gd"))

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
	var err := ResourceSaver.save(packed, "res://scenes/Dungeon.tscn")
	print("Dungeon.tscn saved: ", err)

	print("=== Dungeon setup complete ===")
	quit()
