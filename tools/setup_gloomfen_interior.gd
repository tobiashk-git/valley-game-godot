extends SceneTree
# Builds the Gloomfen terrain TileSet (wall/floor/platform/mud) and
# GloomfenInterior.tscn (using scripts/gloomfen_interior.gd, which extends
# the shared maze_interior.gd - see also tools/setup_frostpeak_interior.gd).
# Reuses fog_tileset.tres as-is.
#
# Needs two runs, same as tools/setup_frostpeak_interior.gd: the first
# generates placeholder textures, which aren't load()-able until Godot's
# import pipeline has seen them - run `godot --headless --import` between
# the two runs (this script tells you when that's needed and exits early).
# Run via: godot --headless --script res://tools/setup_gloomfen_interior.gd

const FULL_TILE_COLLISION: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]

const TEXTURES := {
	"res://assets/gloomfen_wall.png": Color(0.16, 0.2, 0.18),
	"res://assets/gloomfen_floor.png": Color(0.24, 0.28, 0.18),
	"res://assets/gloomfen_platform.png": Color(0.42, 0.32, 0.2),
	"res://assets/gloomfen_mud.png": Color(0.28, 0.2, 0.12),
}

func _make_placeholder(color: Color, path: String) -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(color)
	img.save_png(path)

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
	print("=== Gloomfen interior setup starting ===")

	var missing := false
	for path in TEXTURES:
		if not FileAccess.file_exists(path):
			_make_placeholder(TEXTURES[path], path)
			missing = true
	if missing:
		print("Placeholder textures generated.")
		print("Run: godot --headless --import")
		print("Then run this script again to build the tileset + scene.")
		quit()
		return

	var terrain_tileset := TileSet.new()
	terrain_tileset.tile_size = Vector2i(32, 32)
	terrain_tileset.add_physics_layer()
	_add_source(terrain_tileset, "res://assets/gloomfen_wall.png", 0, true)     # SRC_WALL
	_add_source(terrain_tileset, "res://assets/gloomfen_floor.png", 1, false)   # SRC_FLOOR
	_add_source(terrain_tileset, "res://assets/gloomfen_platform.png", 2, false) # SRC_PLATFORM
	_add_source(terrain_tileset, "res://assets/gloomfen_mud.png", 3, false)     # SRC_MUD
	ResourceSaver.save(terrain_tileset, "res://resources/gloomfen_terrain_tileset.tres")

	var fog_tileset: TileSet = load("res://resources/fog_tileset.tres")

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"

	var root := Node2D.new()
	root.name = "GloomfenInterior"
	root.set_script(load("res://scripts/gloomfen_interior.gd"))
	root.boss_id = "gloomfen_boss"
	root.entrance_tile = World.GLOOMFEN_INTERIOR_ENTRANCE
	root.poi_id = "gloomfen_interior"
	root.encounter_zone = World.Zone.GLOOMFEN

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
	var err := ResourceSaver.save(packed, "res://scenes/GloomfenInterior.tscn")
	print("GloomfenInterior.tscn saved: ", err)

	print("=== Gloomfen interior setup complete ===")
	quit()
