extends SceneTree
# Builds the Verdantwood terrain TileSet (wall/floor/root/canopy) and
# VerdantwoodInterior.tscn (using scripts/verdantwood_interior.gd, which
# extends the shared maze_interior.gd - see also
# tools/setup_frostpeak_interior.gd). Reuses fog_tileset.tres as-is.
#
# Needs two runs, same as tools/setup_frostpeak_interior.gd: the first
# generates placeholder textures, which aren't load()-able until Godot's
# import pipeline has seen them - run `godot --headless --import` between
# the two runs (this script tells you when that's needed and exits early).
# Run via: godot --headless --script res://tools/setup_verdantwood_interior.gd

const FULL_TILE_COLLISION: PackedVector2Array = [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]

const TEXTURES := {
	"res://assets/verdantwood_wall.png": Color(0.28, 0.18, 0.1),
	"res://assets/verdantwood_floor.png": Color(0.32, 0.42, 0.24),
	"res://assets/verdantwood_root.png": Color(0.42, 0.3, 0.18),
	"res://assets/verdantwood_canopy.png": Color(0.12, 0.22, 0.14),
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
	print("=== Verdantwood interior setup starting ===")

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
	_add_source(terrain_tileset, "res://assets/verdantwood_wall.png", 0, true)    # SRC_WALL
	_add_source(terrain_tileset, "res://assets/verdantwood_floor.png", 1, false)  # SRC_FLOOR
	_add_source(terrain_tileset, "res://assets/verdantwood_root.png", 2, false)   # SRC_ROOT
	_add_source(terrain_tileset, "res://assets/verdantwood_canopy.png", 3, false) # SRC_CANOPY
	ResourceSaver.save(terrain_tileset, "res://resources/verdantwood_terrain_tileset.tres")

	var fog_tileset: TileSet = load("res://resources/fog_tileset.tres")

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"

	var root := Node2D.new()
	root.name = "VerdantwoodInterior"
	root.set_script(load("res://scripts/verdantwood_interior.gd"))
	root.boss_id = "verdantwood_boss"
	root.entrance_tile = World.VERDANTWOOD_INTERIOR_ENTRANCE
	root.poi_id = "verdantwood_interior"
	root.encounter_zone = World.Zone.VERDANTWOOD

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
	var err := ResourceSaver.save(packed, "res://scenes/VerdantwoodInterior.tscn")
	print("VerdantwoodInterior.tscn saved: ", err)

	print("=== Verdantwood interior setup complete ===")
	quit()
