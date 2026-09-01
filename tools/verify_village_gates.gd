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

	print("meet_villagers pre-accepted at boot: ", quests.quest_state.get("meet_villagers", "") == "accepted")
	print("Journal progress at boot: ", quests.objective_progress_text("meet_villagers"))

	# --- Gates start closed: walking at the south gate should be blocked. ---
	var south_gate: Vector2i = world.VILLAGE_GATES.south
	player.position = Vector2((south_gate.x) * 32 + 16, (south_gate.y - 2) * 32 + 16)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	var y_before_closed: float = player.position.y
	await _walk(player, "move_down", 40)
	print("South gate blocks movement while closed: ", player.position.y < (south_gate.y + 1) * 32.0)
	root.get_texture().get_image().save_png("res://verify_gates_closed.png")

	# Fully remove this scene before loading the next - change_scene_to_file()
	# does this automatically in the real game, but manually add_child'ing
	# multiple top-level scenes side by side (as this script does, to jump
	# straight to each NPC without walking the whole route) leaves the old
	# scene's own Player/NPC nodes alive and still processing otherwise,
	# which double-handles the next scene's "interact" press.
	root.remove_child(overworld)
	overworld.queue_free()
	await process_frame

	# --- Elder: first talk shows intro, not the quest offer. ---
	var elder_scene: PackedScene = load("res://scenes/ElderHouse.tscn")
	var elder_house: Node2D = elder_scene.instantiate()
	root.add_child(elder_house)
	current_scene = elder_house
	await process_frame
	await process_frame

	var dialogue_ui: Node = root.get_node("DialogueUI")
	var elder_player: CharacterBody2D = elder_house.get_node("YSort/Player")
	var elder_ysort: Node2D = elder_house.get_node("YSort")
	var elder: Node = null
	for child in elder_ysort.get_children():
		if child.name.begins_with("NPC"):
			elder = child
	elder_player.position = elder.position + Vector2(0, 20)
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("First Elder talk shows intro (not quest offer): ", dialogue_ui.text_label.text.begins_with("Ah, a new face"))
	print("npcs_met.village_elder true: ", quests.npcs_met.get("village_elder", false))
	print("Journal after 1 NPC: ", quests.objective_progress_text("meet_villagers"))
	print("Gates still closed after only 1 NPC: ", not game_state.village_gates_open)
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# --- Second Elder talk: normal quest offer now, not the intro again. ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Second Elder talk shows quest offer (regression check): ", dialogue_ui.text_label.text.begins_with("Traveler!"))
	# close via "Not now"
	var actions: Array = dialogue_ui.actions_row.get_children()
	actions[1].pressed.emit()
	await process_frame

	root.remove_child(elder_house)
	elder_house.queue_free()
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

	# --- Second Trader talk: shop opens normally (regression check). ---
	var shop_panel: Node = root.get_node("ShopPanel")
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Second Trader talk opens shop (regression check): ", shop_panel.is_open())
	shop_panel.close()

	root.remove_child(trader_house)
	trader_house.queue_free()
	await process_frame

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
	await _walk(player2, "move_down", 60)
	print("South gate now walkable after reload: ", player2.position.y > (south_gate.y + 1) * 32.0)
	root.get_texture().get_image().save_png("res://verify_gates_open.png")

	quit()
