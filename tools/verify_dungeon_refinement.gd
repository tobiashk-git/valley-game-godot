extends SceneTree
# Dungeon refinement verification. Run via:
# godot --script res://tools/verify_dungeon_refinement.gd (NOT --headless).
#
# The maze camera is glued to the player (spawn centred on desktop and on
# a phone-shaped view); two treasure chests stand in the side rooms with
# their gold and item, open with E, and an emptied chest stays empty on the
# next visit; a step only counts as exploring (and can only roll an
# encounter) when it uncovers new fog, so walking back is safe; the first
# step into the boss room freezes Oliver, sweeps the fog off the room and
# blinks the boss three times.

func _initialize() -> void:
	var combat: Node = root.get_node("Combat")
	var game_state: Node = root.get_node("GameState")
	var storage: Node = root.get_node("Storage")
	var storage_panel: Node = root.get_node("StoragePanel")
	var inventory: Node = root.get_node("Inventory")
	await process_frame
	game_state.reset()
	inventory.reset()
	storage.reset()
	combat._steps_since_encounter = -1000000 # no random fights during the walk
	combat.fast = false

	var dungeon: Node2D = load("res://scenes/Dungeon.tscn").instantiate()
	root.add_child(dungeon)
	current_scene = dungeon
	for i in range(4):
		await process_frame
	var player: CharacterBody2D = dungeon.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# --- camera ---
	var centre: Vector2 = root.get_visible_rect().size / 2.0
	var on_screen: Vector2 = player.get_global_transform_with_canvas().origin
	print("No edge clamping: camera limits are the defaults: ", cam.limit_top == -10000000 and cam.limit_bottom == 10000000 and cam.limit_left == -10000000 and cam.limit_right == 10000000)
	print("Oliver spawns at the door and sits at the centre of the screen (", on_screen, " vs ", centre, "): ", on_screen.distance_to(centre) < 3.0)
	root.size = Vector2i(400, 860)
	for i in range(6):
		await process_frame
	cam.reset_smoothing()
	await process_frame
	await process_frame
	centre = root.get_visible_rect().size / 2.0
	on_screen = player.get_global_transform_with_canvas().origin
	print("Phone view: still centred (", on_screen, " vs ", centre, "): ", on_screen.distance_to(centre) < 3.0)
	root.get_texture().get_image().save_png("res://verify_dungeon_refinement_phone.png")
	print("Saved verify_dungeon_refinement_phone.png")
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	cam.reset_smoothing()

	# --- chests ---
	var gen: Dictionary = dungeon._gen
	var chests: Array = dungeon.chests
	print("Two chests placed with storages dungeon_chest_1 / dungeon_chest_2: ", chests.size() == 2 and chests[0].storage_id == "dungeon_chest_1" and chests[1].storage_id == "dungeon_chest_2")
	print("Old Chest holds 15 gold; Iron Chest 20 gold and a healing potion: ", storage.get_count("dungeon_chest_1", "gold") == 15 and storage.get_count("dungeon_chest_2", "gold") == 20 and storage.get_count("dungeon_chest_2", "healing_potion") == 1)
	var placed_ok := true
	for chest in chests:
		var tile := Vector2i(int(chest.position.x / 32), int(chest.position.y / 32))
		if dungeon.terrain.get_cell_source_id(tile) != dungeon.SRC_FLOOR:
			placed_ok = false
		if dungeon._in_room(gen.room_chain[0], tile) or dungeon._in_room(gen.boss_room, tile):
			placed_ok = false
		var in_side := false
		for r in gen.room_chain.slice(1, gen.room_chain.size() - 1):
			if dungeon._in_room(r, tile):
				in_side = true
		if not in_side:
			placed_ok = false
	print("Both chests stand on floor tiles inside side rooms (not the entrance or boss room): ", placed_ok)
	player.position = chests[0].position + Vector2(0, 20)
	for i in range(3):
		await physics_frame
	await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("E beside the Old Chest opens the chest window: ", storage_panel.is_open() and storage_panel.storage_id == "dungeon_chest_1")
	storage_panel.close()
	await process_frame
	storage.remove_item("dungeon_chest_1", "gold", 15)

	# --- explored ground ---
	var corridor: Array = gen.corridors[0]
	var path: Array = corridor.slice(0, mini(10, corridor.size()))
	dungeon.explore_steps = 0
	for t in path:
		player.position = dungeon._tile_center(t)
		await process_frame
		await process_frame
	var forward: int = dungeon.explore_steps
	path.reverse()
	for t in path:
		player.position = dungeon._tile_center(t)
		await process_frame
		await process_frame
	print("Walking a corridor forward uncovers fog (", forward, " exploring steps); walking back over it adds none: ", forward >= 3 and dungeon.explore_steps == forward)

	# --- boss room reveal ---
	var room: DungeonGen.Room = gen.boss_room
	var boss: Node = dungeon._boss
	var fogged_before := 0
	for y in range(room.y, room.y + room.h):
		for x in range(room.x, room.x + room.w):
			if dungeon.fog.get_cell_source_id(Vector2i(x, y)) != -1:
				fogged_before += 1
	var entry := Vector2i(room.x, room.center().y)
	player.position = dungeon._tile_center(entry)
	await process_frame
	await process_frame
	var frozen: bool = game_state.cutscene
	var before: Vector2 = player.position
	Input.action_press("move_right")
	for i in range(10):
		await physics_frame
	Input.action_release("move_right")
	var held: bool = player.position.distance_to(before) < 1.0
	var waited := 0.0
	while game_state.cutscene and waited < 5.0:
		await create_timer(0.05).timeout
		waited += 0.05
	var cleared := true
	for y in range(room.y - 1, room.y + room.h + 1):
		for x in range(room.x - 1, room.x + room.w + 1):
			if dungeon.fog.get_cell_source_id(Vector2i(x, y)) != -1:
				cleared = false
	print("Stepping into the fogged boss room (", fogged_before, " cells) starts the cutscene and holds Oliver still: ", fogged_before > 10 and frozen and held)
	print("The sweep clears the whole room plus its wall ring, the boss blinks three times, control returns (%.1fs): " % waited, cleared and boss.flashes == 3 and not game_state.cutscene and waited < 5.0)
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_dungeon_refinement_boss.png")
	print("Saved verify_dungeon_refinement_boss.png")

	# --- chest persistence across a fresh maze ---
	dungeon.queue_free()
	await process_frame
	await process_frame
	var again: Node2D = load("res://scenes/Dungeon.tscn").instantiate()
	root.add_child(again)
	current_scene = again
	for i in range(3):
		await process_frame
	print("A new visit lays out a fresh maze but the emptied Old Chest stays empty and the Iron Chest keeps its 20 gold: ", again.chests.size() == 2 and storage.get_count("dungeon_chest_1", "gold") == 0 and storage.get_count("dungeon_chest_2", "gold") == 20)
	again.queue_free()
	await process_frame

	# --- every maze has its chests; Golden Plains keeps its no-encounter step ---
	var counts: Array = []
	for path_scene in ["res://scenes/Castle.tscn", "res://scenes/FrostpeakInterior.tscn", "res://scenes/VerdantwoodInterior.tscn", "res://scenes/BadlandsInterior.tscn", "res://scenes/GloomfenInterior.tscn", "res://scenes/GoldenPlainsInterior.tscn"]:
		var scene: Node2D = load(path_scene).instantiate()
		root.add_child(scene)
		current_scene = scene
		for i in range(3):
			await process_frame
		counts.append(scene.chests.size())
		scene.queue_free()
		await process_frame
	print("Castle and the five biome mazes each place two chests: ", counts == [2, 2, 2, 2, 2, 2])
	print("Castle chests hold 40 and 60 gold; Gloomfen's second holds bog iron: ", storage.get_count("castle_chest_1", "gold") == 40 and storage.get_count("castle_chest_2", "gold") == 60 and storage.get_count("gloomfen_interior_chest_2", "bog_iron") == 2)
	game_state.cutscene = false
	quit()
