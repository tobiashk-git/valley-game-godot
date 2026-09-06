extends SceneTree
# Builds ElderHouse.tscn, TraderHouse.tscn, BlacksmithHouse.tscn — all sharing
# village_house.gd, configured per-house (matching world.js's villageHouses
# loop, where the same buildInterior() call is branched by index).
# Run via: godot --headless --script res://tools/setup_village_houses.gd

func _build(scene_name: String, has_npc: bool, sprite_path: String, npc_name: String, dialogue: String, furniture: Array[Dictionary], windows: Array[Vector2i], return_tile: Vector2i, quest_id: String = "", is_shop: bool = false, npc_id: String = "", intro: String = "", tint: Color = Color(1, 1, 1, 1), shell: String = "", shell_wall_rows: int = 2) -> void:
	var house_tileset: TileSet = load("res://resources/house_tileset.tres")
	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	var player_instance: CharacterBody2D = player_scene.instantiate()
	player_instance.name = "Player"

	var root := Node2D.new()
	root.name = scene_name
	root.set_script(load("res://scripts/village_house.gd"))
	root.has_npc = has_npc
	root.npc_sprite_path = sprite_path
	root.npc_name_text = npc_name
	root.npc_dialogue = dialogue
	root.npc_quest_id = quest_id
	root.npc_is_shop = is_shop
	root.npc_id_text = npc_id
	root.npc_intro = intro
	root.npc_sprite_tint = tint
	# A painted shell's wall band is two (or three, for the Trader's tall
	# shelves) tiles deep, all solid; furniture then starts on the row below.
	root.room_shell = shell
	root.wall_rows = shell_wall_rows if shell != "" else 1
	root.furniture_layout = furniture
	root.window_tiles = windows
	root.overworld_return_tile = return_tile

	var terrain := TileMapLayer.new()
	terrain.name = "TerrainLayer"
	terrain.tile_set = house_tileset
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
	var err := ResourceSaver.save(packed, "res://scenes/%s.tscn" % scene_name)
	print(scene_name, ".tscn saved: ", err)

func _initialize() -> void:
	print("=== Village houses setup starting ===")

	# The Elder himself stands OUTSIDE on the village square now (see
	# overworld.gd) so the tutorial quest is collected in person; his house
	# is just his house.
	_build(
		"ElderHouse", false, "", "",
		"",
		[
			{"kind": "Bed", "x": 2, "y": 4}, # three tiles tall: head meets the painted wall base
			{"kind": "Bookshelf", "x": 6, "y": 2},
		],
		[Vector2i(0, 3), Vector2i(0, 4)],
		World.ELDER_HOUSE_ENTRANCE,
		"", false, "", "", Color(1, 1, 1, 1),
		"res://assets/interiors/elder_shell.png"
	)

	_build(
		"TraderHouse", true, "res://assets/trader.png", "Village Trader",
		"", # superseded by is_shop - E opens ShopPanel directly, no dialogue step
		[
			{"kind": "Table", "x": 2, "y": 3}, # first floor row under the painted shelves
			{"kind": "Barrel", "x": 2, "y": 5},
			{"kind": "Barrel", "x": 7, "y": 4}, # by the right wall (the cabinet looked odd there)
		],
		[Vector2i(8, 1), Vector2i(8, 2)],
		World.TRADER_HOUSE_ENTRANCE,
		"open_ancient_barrow", true, "village_trader", # quest first, shop once it's done (npc.gd)
		"Welcome, welcome! I'm the Village Trader - come back anytime you want to buy or sell.",
		Color(1, 1, 1, 1), "res://assets/interiors/trader_shell.png", 3
	)

	# The Blacksmith's: the village's crafting station. The Workbench prop
	# (workbench.gd) is the only place crafting, enhancing and salvaging
	# work; the forge stands against the back wall.
	_build(
		"BlacksmithHouse", true, "res://assets/trader.png", "Village Blacksmith",
		"Need something made? The bench in the corner is yours - bring the makings and I'll keep the forge hot. Old gear you don't want, I'll break down for parts.",
		[
			{"kind": "Workbench", "x": 2, "y": 3}, # first floor row under the painted stone wall
			{"kind": "Forge", "x": 6, "y": 3}, # its chimney runs up the painted wall
			{"kind": "Barrel", "x": 7, "y": 5},
		],
		[Vector2i(8, 1), Vector2i(8, 2)],
		World.BLACKSMITH_HOUSE_ENTRANCE,
		"", false, "village_blacksmith",
		"Hah, the new arrival. I'm the Blacksmith - anything that needs hammering, forging or breaking down, that's my bench in the corner. Walk up to it and press E.",
		Color(0.62, 0.6, 0.68, 1.0), "res://assets/interiors/smithy_shell.png", 3
	)

	print("=== Village houses setup complete ===")
	quit()
