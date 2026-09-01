extends SceneTree
# Builds Overworld2.tscn — reuses the exact same TileSet resource already
# embedded in Overworld.tscn (grass/snow/sand/forest/hills sources are all
# World 2 needs; it never touches the fence/gate/altar sources) rather than
# rebuilding a duplicate one from scratch.
# Run via: godot --headless --script res://tools/setup_overworld2.gd

func _initialize() -> void:
	print("=== Overworld2 setup starting ===")

	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld_instance: Node2D = overworld_scene.instantiate()
	var shared_tileset: TileSet = overworld_instance.get_node("TileMapLayer").tile_set
	overworld_instance.free()

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"

	var root := Node2D.new()
	root.name = "Overworld2"
	root.set_script(load("res://scripts/overworld2.gd"))

	var tilemap := TileMapLayer.new()
	tilemap.name = "TileMapLayer"
	tilemap.tile_set = shared_tileset
	root.add_child(tilemap)
	tilemap.owner = root

	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	root.add_child(ysort)
	ysort.owner = root

	ysort.add_child(player_instance)
	player_instance.owner = root

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.5, 1.5) # matches Overworld.tscn's own zoom
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player_instance.add_child(camera)
	camera.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/Overworld2.tscn")
	print("Overworld2.tscn saved: ", err)

	print("=== Overworld2 setup complete ===")
	quit()
