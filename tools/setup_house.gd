extends SceneTree
# Builds the house TileSet (wall/floor/window) + House.tscn.
# Run via: godot --headless --script res://tools/setup_house.gd

const FULL_TILE_COLLISION: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]

func _add_source(tile_set: TileSet, path: String, id: int, solid: bool) -> void:
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
	print("=== House setup starting ===")

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_physics_layer()
	_add_source(tile_set, "res://assets/house_wall.png", 0, true)
	_add_source(tile_set, "res://assets/house_floor.png", 1, false)
	_add_source(tile_set, "res://assets/window.png", 2, true)
	ResourceSaver.save(tile_set, "res://resources/house_tileset.tres")

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"

	var root := Node2D.new()
	root.name = "House"
	root.set_script(load("res://scripts/house.gd"))

	var terrain := TileMapLayer.new()
	terrain.name = "TerrainLayer"
	terrain.tile_set = tile_set
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
	camera.zoom = Vector2(2.0, 2.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player_instance.add_child(camera)
	camera.owner = root

	var out_portal := Area2D.new()
	out_portal.name = "OutPortal"
	out_portal.set_script(load("res://scripts/portal.gd"))
	root.add_child(out_portal)
	out_portal.owner = root

	var portal_shape := CollisionShape2D.new()
	portal_shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	portal_shape.shape = rect
	out_portal.add_child(portal_shape)
	portal_shape.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/House.tscn")
	print("House.tscn saved: ", err)

	print("=== House setup complete ===")
	quit()
