extends SceneTree
# Builds the overworld TileSet + Overworld.tscn (empty TileMapLayer — cells
# are painted at runtime by overworld.gd/world.gd, not baked in here).
# Run via: godot --headless --script res://tools/setup_phase1.gd

func _add_source(tile_set: TileSet, path: String, id: int) -> void:
	var tex: Texture2D = load(path)
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(32, 32)
	# grass.png is a multi-row sheet (96x192); every other asset here is a
	# single 32x32 tile, so only grass needs more than the (0,0) tile created.
	if path.ends_with("grass.png"):
		for row in range(int(tex.get_height() / 32)):
			source.create_tile(Vector2i(0, row))
	else:
		source.create_tile(Vector2i(0, 0))
	tile_set.add_source(source, id)

func _initialize() -> void:
	print("=== Phase 1 setup starting ===")

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	_add_source(tile_set, "res://assets/grass.png", 0)
	_add_source(tile_set, "res://assets/snow.png", 1)
	_add_source(tile_set, "res://assets/sand.png", 2)
	_add_source(tile_set, "res://assets/forest_ground.png", 3)
	_add_source(tile_set, "res://assets/hills_ground.png", 4)
	_add_source(tile_set, "res://assets/path.png", 5)
	_add_source(tile_set, "res://assets/fence.png", 6)
	_add_source(tile_set, "res://assets/gate.png", 7)
	_add_source(tile_set, "res://assets/altar.png", 8)
	var ts_err := ResourceSaver.save(tile_set, "res://resources/overworld_tileset.tres")
	print("overworld_tileset.tres saved: ", ts_err)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"

	var root := Node2D.new()
	root.name = "Overworld"
	root.set_script(load("res://scripts/overworld.gd"))

	var tilemap := TileMapLayer.new()
	tilemap.name = "TileMapLayer"
	tilemap.tile_set = tile_set
	root.add_child(tilemap)
	tilemap.owner = root

	# Player and every scattered prop (trees, rocks, entrance markers) are
	# direct children of this so Godot's y-sort can depth-sort them against
	# each other (walk in front of a tree from below, behind it from above) —
	# they need to be siblings under the SAME y-sorted node, not nested in a
	# further wrapper, or Godot sorts the wrapper as one unit instead.
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

	var packed := PackedScene.new()
	packed.pack(root)
	var scene_err := ResourceSaver.save(packed, "res://scenes/Overworld.tscn")
	print("Overworld.tscn saved: ", scene_err)

	print("=== Phase 1 setup complete ===")
	quit()
