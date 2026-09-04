extends SceneTree

func _walk(player: CharacterBody2D, direction: String, frames: int) -> void:
	Input.action_press(direction)
	for i in range(frames):
		await process_frame
	Input.action_release(direction)
	await process_frame

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var combat: Node = root.get_node("Combat")
	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var items: Node = root.get_node("Items")
	var world_map_panel: Node = root.get_node("WorldMapPanel")

	print("Castle undiscovered at boot: ", not game_state.discovered_pois.castle)

	# --- Real portal path: walk to the castle entrance and press E. ---
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var approach: Vector2i = world.CASTLE_ENTRANCE + Vector2i(0, 2)
	player.position = Vector2(approach.x * 32 + 16, approach.y * 32 + 16)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(player, "move_up", 40)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Entered the Castle via the real portal: ", current_scene.name == "Castle")
	print("Castle marked discovered: ", game_state.discovered_pois.castle)
	root.get_texture().get_image().save_png("res://verify_castle_interior.png")

	# The maze's own spawn tile sits directly adjacent to the door (by
	# DungeonGen's design) - remember it now, before moving to the boss room
	# for the fight, since a straight walk from deep in the maze afterward
	# can't be assumed to reach the door (walls are in the way).
	var castle_spawn_player: CharacterBody2D = current_scene.get_node("YSort/Player")
	var spawn_pos: Vector2 = castle_spawn_player.position

	# --- Boss present, correctly configured. ---
	var castle: Node2D = current_scene
	var ysort: Node2D = castle.get_node("YSort")
	var boss: Node = null
	for child in ysort.get_children():
		if child.name == "Boss":
			boss = child
	print("Boss node found: ", boss != null)
	print("Boss id is castle_boss: ", boss.boss_id == "castle_boss")

	# --- Boosted-HP guaranteed win (same isolation as verify_combat_phase6.gd). ---
	var cplayer: CharacterBody2D = castle.get_node("YSort/Player")
	cplayer.position = boss.position + Vector2(0, 20)
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Boss fight started: ", combat.in_combat)
	print("Fighting the right boss: ", combat.current_enemies[0].name == "Royal Wraith")

	character.stats.max_hp = 500
	character.stats.hp = 500
	character.stats.mp = 999
	var gold_before: int = inventory.get_count("gold")
	var guard := 0
	while combat.in_combat and guard < 40:
		combat.cast_spell("fireball")
		await process_frame
		guard += 1
	print("Boss defeated (", guard, " actions): ", not combat.in_combat)
	print("Castle boss checkpoint marked defeated: ", game_state.boss_defeated.castle_boss)
	print("Gold granted: ", inventory.get_count("gold") > gold_before)
	print("Royal Plate obtained: ", inventory.get_count("royal_plate") == 1)
	print("Royal Plate stat suffix: ", items.describe_stats("royal_plate"))

	# --- Walk to the door and back out - confirm the shared door blocker
	# (from maze_interior.gd) applies here too. Reposition to the
	# door-adjacent spawn tile first (see above - the boss room is deep in
	# the maze, with walls between it and the door). ---
	cplayer.position = spawn_pos
	for i in range(3):
		await process_frame
	await _walk(cplayer, "move_down", 90)
	var door_tile := Vector2i(int(cplayer.position.x / 32), int(cplayer.position.y / 32))
	print("Stopped at the door, not wandering past it: ", door_tile.y <= 27)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Left the Castle via the real portal: ", current_scene.name == "Overworld")
	var back_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed just outside the castle entrance: ", back_tile == world.CASTLE_ENTRANCE + Vector2i(0, 1))

	# --- World Map now lists Castle; fast travel works. ---
	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame
	# The map is the character sheet's Map tab now: a row per known place
	# in its "Known places" list, then Fast Travel in the pane.
	var map_view: Control = root.get_node("CharacterSheet").map_view
	var castle_row: Button = null
	for row in map_view.places_list.get_children():
		if row is Button and row.visible and row.text.strip_edges() == "Castle":
			castle_row = row
	print("World Map lists Castle: ", castle_row != null)
	castle_row.pressed.emit()
	await process_frame
	map_view.travel_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel to Castle lands on Overworld: ", current_scene.name == "Overworld")
	var travel_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Fast travel landed at the castle entrance: ", travel_tile == world.CASTLE_ENTRANCE + Vector2i(0, 1))

	quit()
