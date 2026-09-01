extends SceneTree
# Builds FinalBoss.tscn — same shared scripts/maze_interior.gd as Dungeon/
# Castle, reusing the already-built dungeon_terrain_tileset.tres and
# fog_tileset.tres as-is ("a hidden path" reads fine as a rugged cave, no
# new art needed).
# Run via: godot --headless --script res://tools/setup_final_boss.gd

func _initialize() -> void:
	print("=== FinalBoss setup starting ===")

	var terrain_tileset: TileSet = load("res://resources/dungeon_terrain_tileset.tres")
	var fog_tileset: TileSet = load("res://resources/fog_tileset.tres")

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"

	var root := Node2D.new()
	root.name = "FinalBoss"
	root.set_script(load("res://scripts/maze_interior.gd"))
	root.boss_id = "final_boss"
	root.entrance_tile = World.FINAL_BOSS_ENTRANCE
	root.poi_id = "final_boss"

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

	var fog := TileMapLayer.new()
	fog.name = "FogLayer"
	fog.tile_set = fog_tileset
	root.add_child(fog)
	fog.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/FinalBoss.tscn")
	print("FinalBoss.tscn saved: ", err)

	print("=== FinalBoss setup complete ===")
	quit()
