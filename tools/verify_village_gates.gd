extends SceneTree

func _walk(player: CharacterBody2D, direction: String, frames: int) -> void:
	Input.action_press(direction)
	for i in range(frames):
		await process_frame
	Input.action_release(direction)
	await process_frame

# scatter_trees_and_rocks()/scatter_biome_obstacles() have no fixed seed, so
# a Tree/Rock can occasionally land just outside the village fence, right on
# this fixed straight-line approach to the south gate (the village square
# itself is protected via _is_in_village(), but the tile immediately south
# of the gate isn't) - same "fix belongs in the test" reasoning as
# verify_frostpeak_interior.gd's _clear_point()/_clear_corridor(), just
# applied here for the first time now that this exact path has been hit.
func _clear_point(overworld: Node2D, player: CharacterBody2D, pos: Vector2, radius: float) -> void:
	var ysort: Node2D = overworld.get_node("YSort")
	for child in ysort.get_children():
		if child != player and child is Node2D and child.position.distance_to(pos) < radius:
			child.queue_free()
	await process_frame
	await process_frame

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var quests: Node = root.get_node("Quests")

	# --- Fresh Overworld load: spawn must be INSIDE the village (the bug). ---
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var spawn_tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	print("Spawn tile: ", spawn_tile)
	print("Spawn is inside VILLAGE_BOUNDS: ", spawn_tile.x >= world.VILLAGE_BOUNDS.x0 and spawn_tile.x <= world.VILLAGE_BOUNDS.x1 and spawn_tile.y >= world.VILLAGE_BOUNDS.y0 and spawn_tile.y <= world.VILLAGE_BOUNDS.y1)

	print("Nothing accepted or tracked at boot (the Elder hands out the tutorial): ", not quests.quest_state.has("meet_villagers") and quests.tracked_quests.is_empty())
	var dialogue_ui: Node = root.get_node("DialogueUI")

	# --- The Elder stands outside his house with a "!" over his head. ---
	var elder: Node = null
	for child in overworld.get_node("YSort").get_children():
		if child.get("npc_id") == "village_elder":
			elder = child
	var elder_tile := Vector2i(int(elder.position.x / 32), int(elder.position.y / 32))
	print("Elder NPC stands on the village square at World.ELDER_POS, outside his house: ", elder != null and elder_tile == world.ELDER_POS and elder_tile != world.ELDER_HOUSE_ENTRANCE and world.ELDER_POS.x >= world.VILLAGE_BOUNDS.x0 and world.ELDER_POS.x <= world.VILLAGE_BOUNDS.x1)
	var marker: Label = elder.get_node("QuestMarker")
	print("Elder shows a gold '!' (quest available) above his sprite: ", marker.visible and marker.text == "!" and elder.marker_kind() == "!" and marker.position.y < elder.get_node("Sprite2D").get_rect().position.y)
	print("Elder's house has no NPC inside any more: ", not load("res://scenes/ElderHouse.tscn").instantiate().has_npc)

	# --- Gates start closed: walking at the south gate should be blocked. ---
	var south_gate: Vector2i = world.VILLAGE_GATES.south
	player.position = Vector2((south_gate.x) * 32 + 16, (south_gate.y - 2) * 32 + 16)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(player, "move_down", 40)
	print("South gate blocks movement while closed: ", player.position.y < (south_gate.y + 1) * 32.0)
	root.get_texture().get_image().save_png("res://verify_gates_closed.png")

	# --- Elder: first talk is the intro, second the tutorial quest offer. ---
	player.position = elder.position + Vector2(0, 20)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_gates_elder_marker.png")
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("First Elder talk shows intro (not quest offer): ", dialogue_ui.text_label.text.begins_with("Ah, a new face"))
	print("npcs_met.village_elder true, tutorial still not accepted, marker still '!': ", quests.npcs_met.get("village_elder", false) and not quests.quest_state.has("meet_villagers") and marker.visible)
	print("Gates still closed: ", not game_state.village_gates_open)
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Second Elder talk offers Meet the Village: ", dialogue_ui.text_label.text.begins_with("Welcome to the valley") and dialogue_ui.actions_row.get_child_count() == 2)
	(dialogue_ui.actions_row.get_child(0) as Button).pressed.emit() # Accept
	await process_frame
	print("Accepted and tracked; not completed yet (Trader not met): ", quests.quest_state.get("meet_villagers", "") == "accepted" and quests.tracked_quests == ["meet_villagers"] and not game_state.village_gates_open)
	print("Marker gone while the quest is in progress: ", not marker.visible and elder.marker_kind() == "")
	print("Journal progress: ", quests.objective_progress_text("meet_villagers"))
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Talking again while in progress reminds you of the Trader: ", dialogue_ui.text_label.text.begins_with("The Trader's in the south-west house"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	root.remove_child(overworld)
	overworld.queue_free()
	await process_frame

	# --- Trader: first talk shows intro + gates-opened line, completes meet_villagers. ---
	var trader_scene: PackedScene = load("res://scenes/TraderHouse.tscn")
	var trader_house: Node2D = trader_scene.instantiate()
	root.add_child(trader_house)
	current_scene = trader_house
	await process_frame
	await process_frame

	var trader_player: CharacterBody2D = trader_house.get_node("YSort/Player")
	var trader_ysort: Node2D = trader_house.get_node("YSort")
	var trader: Node = null
	for child in trader_ysort.get_children():
		if child.name.begins_with("NPC"):
			trader = child
	print("Trader shows a '!' too (the barrow quest is on offer): ", trader.get_node("QuestMarker").visible and trader.marker_kind() == "!")
	trader_player.position = trader.position + Vector2(0, 20)
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("First Trader talk shows intro: ", dialogue_ui.text_label.text.begins_with("Welcome, welcome"))
	print("Combined gates-opened line present: ", dialogue_ui.text_label.text.contains("gates have opened"))
	print("meet_villagers completed: ", quests.quest_state.get("meet_villagers", "") == "completed")
	print("GameState.village_gates_open: ", game_state.village_gates_open)
	root.get_texture().get_image().save_png("res://verify_gates_intro_combined.png")
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# --- Second Trader talk: the barrow quest offer (an active quest beats
	# the shop, see npc.gd). ---
	var shop_panel: Node = root.get_node("ShopPanel")
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Second Trader talk shows the barrow quest offer (not the shop): ", dialogue_ui.text_label.text.begins_with("There's an old barrow") and not shop_panel.is_open())
	(dialogue_ui.actions_row.get_child(0) as Button).pressed.emit() # Accept the barrow quest
	await process_frame
	root.get_node("Inventory").add_item("stone", 6)
	await process_frame
	print("Trader's marker turns to '?' once the barrow quest is ready to turn in: ", trader.get_node("QuestMarker").text == "?" and trader.get_node("QuestMarker").visible)
	root.get_texture().get_image().save_png("res://verify_gates_trader_ready.png")

	root.remove_child(trader_house)
	trader_house.queue_free()
	await process_frame

	# --- Met-the-Trader-first path: accepting the tutorial completes it on
	# the spot and opens the gates. ---
	quests.quest_state.erase("meet_villagers")
	game_state.village_gates_open = false
	quests._accept_quest("meet_villagers")
	await process_frame
	print("Accepting after already meeting the Trader completes it at once and opens the gates: ", quests.quest_state.get("meet_villagers", "") == "completed" and game_state.village_gates_open and dialogue_ui.is_open() and dialogue_ui.text_label.text.begins_with("You've already met the Trader"))
	dialogue_ui.hide_dialogue()

	# --- Fresh Overworld reload: gates should paint open from the start. ---
	var overworld2_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld2: Node2D = overworld2_scene.instantiate()
	root.add_child(overworld2)
	current_scene = overworld2
	await process_frame
	await process_frame

	var player2: CharacterBody2D = overworld2.get_node("YSort/Player")
	player2.position = Vector2(south_gate.x * 32 + 16, (south_gate.y - 2) * 32 + 16)
	var cam2: Camera2D = player2.get_node("Camera2D")
	cam2.reset_smoothing()
	for i in range(3):
		await process_frame
	var gate_world: Vector2 = Vector2(south_gate.x * 32 + 16, south_gate.y * 32 + 16)
	await _clear_point(overworld2, player2, gate_world, 100.0)
	await _walk(player2, "move_down", 60)
	print("South gate now walkable after reload: ", player2.position.y > (south_gate.y + 1) * 32.0)
	root.get_texture().get_image().save_png("res://verify_gates_open.png")
	var elder2: Node = null
	for child in overworld2.get_node("YSort").get_children():
		if child.get("npc_id") == "village_elder":
			elder2 = child
	print("After the tutorial the Elder offers the wood quest next ('!' is back): ", elder2 != null and elder2.active_quest() == "gather_wood" and elder2.get_node("QuestMarker").visible and elder2.get_node("QuestMarker").text == "!")

	quit()
