extends SceneTree
# One-off headless build script for Phase 0 of the Godot migration.
# Run via: godot --headless --script res://tools/setup_phase0.gd
# Builds test_tileset.tres, Player.tscn, and Main.tscn entirely in code,
# since there's no interactive editor access in this environment.

func _initialize() -> void:
	print("=== Phase 0 setup starting ===")

	# --- TileSet: grass (source 0), house_wall (source 1), house_floor (source 2) ---
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)

	var grass_tex: Texture2D = load("res://assets/grass.png")
	var grass_source := TileSetAtlasSource.new()
	grass_source.texture = grass_tex
	grass_source.texture_region_size = Vector2i(32, 32)
	grass_source.create_tile(Vector2i(0, 5)) # matches the JS game's sx:0,sy:160 crop (160/32=row5)
	tile_set.add_source(grass_source, 0)

	var wall_tex: Texture2D = load("res://assets/house_wall.png")
	var wall_source := TileSetAtlasSource.new()
	wall_source.texture = wall_tex
	wall_source.texture_region_size = Vector2i(32, 32)
	wall_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(wall_source, 1)

	var floor_tex: Texture2D = load("res://assets/house_floor.png")
	var floor_source := TileSetAtlasSource.new()
	floor_source.texture = floor_tex
	floor_source.texture_region_size = Vector2i(32, 32)
	floor_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(floor_source, 2)

	var tileset_err := ResourceSaver.save(tile_set, "res://resources/test_tileset.tres")
	print("TileSet saved: ", tileset_err)

	# --- Player scene: CharacterBody2D + AnimatedSprite2D + CollisionShape2D ---
	var player_tex: Texture2D = load("res://assets/player_base.png")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var rows := {"up": 0, "left": 1, "down": 2, "right": 3}
	for dir_key in rows.keys():
		var row: int = rows[dir_key]

		frames.add_animation(dir_key + "_idle")
		frames.set_animation_loop(dir_key + "_idle", true)
		var idle_atlas := AtlasTexture.new()
		idle_atlas.atlas = player_tex
		idle_atlas.region = Rect2(0, row * 64, 64, 64)
		frames.add_frame(dir_key + "_idle", idle_atlas)

		frames.add_animation(dir_key)
		frames.set_animation_loop(dir_key, true)
		frames.set_animation_speed(dir_key, 8.0)
		for col in range(1, 9):
			var walk_atlas := AtlasTexture.new()
			walk_atlas.atlas = player_tex
			walk_atlas.region = Rect2(col * 64, row * 64, 64, 64)
			frames.add_frame(dir_key, walk_atlas)

	var player_root := CharacterBody2D.new()
	player_root.name = "Player"
	player_root.set_script(load("res://scripts/player.gd"))

	var anim_sprite := AnimatedSprite2D.new()
	anim_sprite.name = "AnimatedSprite2D"
	anim_sprite.sprite_frames = frames
	anim_sprite.animation = "down_idle"
	player_root.add_child(anim_sprite)
	anim_sprite.owner = player_root

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	collision.shape = shape
	player_root.add_child(collision)
	collision.owner = player_root

	var player_packed := PackedScene.new()
	player_packed.pack(player_root)
	var player_err := ResourceSaver.save(player_packed, "res://scenes/Player.tscn")
	print("Player.tscn saved: ", player_err)

	# --- Main scene: TileMapLayer (grass field + a small wall/floor room) + Player + Camera2D ---
	var main_root := Node2D.new()
	main_root.name = "Main"

	var tilemap := TileMapLayer.new()
	tilemap.name = "TileMapLayer"
	tilemap.tile_set = tile_set
	main_root.add_child(tilemap)
	tilemap.owner = main_root

	for x in range(-5, 6):
		for y in range(-5, 6):
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 5))

	for x in range(10, 15):
		for y in range(0, 5):
			var is_border: bool = x == 10 or x == 14 or y == 0 or y == 4
			if is_border:
				tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
			else:
				tilemap.set_cell(Vector2i(x, y), 2, Vector2i(0, 0))

	# Reload from disk (not the in-memory player_packed) so the instantiated
	# root's scene_file_path is unambiguously set — otherwise pack() below may
	# flatten the player into plain nodes instead of a proper scene instance.
	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"
	player_instance.position = Vector2(80, 80)
	main_root.add_child(player_instance)
	player_instance.owner = main_root

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(2, 2)
	player_instance.add_child(camera)
	camera.owner = main_root

	var main_packed := PackedScene.new()
	main_packed.pack(main_root)
	var main_err := ResourceSaver.save(main_packed, "res://scenes/Main.tscn")
	print("Main.tscn saved: ", main_err)

	print("=== Phase 0 setup complete ===")
	quit()
