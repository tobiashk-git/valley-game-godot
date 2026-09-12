extends SceneTree
# Ending verification. Run via:
# godot --script res://tools/verify_ending.gd (NOT --headless).
#
# The Warden's crystal at the altar ends the game (2026-09-12): a swirl
# rises from the altar and fills the screen (instant under a script), the
# completion screen shows Oliver with Luigi and Eden, the headline, a
# scrolling strip of every boss put to sleep, and Play again / Quit. The
# state is saved as completed; the altar afterwards only says the valley
# is at peace.

func _initialize() -> void:
	var game_state: Node = root.get_node("GameState")
	var inventory: Node = root.get_node("Inventory")
	var quests: Node = root.get_node("Quests")
	var altar: Node = root.get_node("Altar")
	var swirl: CanvasLayer = root.get_node("EndingSwirl")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	var save: Node = root.get_node("SaveSystem")
	await process_frame
	game_state.reset()
	quests.reset()
	inventory.reset()
	root.get_node("Character").reset()
	print("A fresh game is not completed: ", not game_state.world_progress.get("game_completed", false))
	# Everything done: every boss asleep, the lair revealed, the Warden's crystal in hand.
	for boss_id in game_state.boss_defeated.keys():
		game_state.boss_defeated[boss_id] = true
	game_state.world_progress.final_boss_revealed = true
	game_state.village_gates_open = true
	inventory.add_item("magic_crystal", 1)
	MapRecipe.active_path = "res://tools/no_such_recipe.json"
	root.get_node("World").reload_places()
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	for i in range(3):
		await process_frame
	altar.interact()
	await process_frame
	await process_frame
	await process_frame
	print("The crystal at the altar ends the game: the state is completed (and saved), the crystal spent, no world-2 portal: ", game_state.world_progress.game_completed and inventory.get_count("magic_crystal") == 0 and not game_state.world_progress.world2_unlocked and save.has_save() and bool(save.read_save().game_state.world_progress.get("game_completed", false)))
	print("...and the swirl (instant under a script) hands over to the completion screen: ", current_scene != null and current_scene.name == "Ending" and not swirl.playing)
	var ending: Control = current_scene
	for i in range(3):
		await process_frame
	print("Oliver's illustration at the top, Luigi's bust left of him, Eden's right: ", ending.oliver.texture != null and ending.luigi.texture != null and ending.eden.texture != null and ending.luigi.position.x + ending.luigi.size.x <= ending.oliver.position.x and ending.eden.position.x >= ending.oliver.position.x + ending.oliver.size.x)
	print("The headline: ", ending.headline.text == "Oliver has conquered the Valley of Adventure")
	var names: Array = ending.strip_row.get_children().map(func(c): return c.get_node("Name").text)
	print("The boss strip lists all nine sleepers in story order, portrait over name: ", ending.beaten.size() == 9 and names[0] == "The Barrow Warden" and names[1] == "Bone Lord" and names[-1] == "The Ancient Warden" and ending.strip_row.get_child(0).get_node("Art").texture != null and ending.sub.text.begins_with("9 bosses"))
	var x0: float = ending.strip_row.position.x
	for i in range(20):
		await process_frame
	print("...and it scrolls: ", ending.strip_row.position.x < x0 and ending.strip_row2.position.x > ending.strip_row.position.x)
	var h: float = root.get_visible_rect().size.y
	print("Play again and Quit sit under the strip, inside the screen: ", ending.play_btn.position.y > ending.strip_clip.position.y + ending.strip_clip.size.y and ending.quit_btn.position.y + ending.quit_btn.size.y <= h and not root.get_node("HUD").visible)
	print("The ending has its own music (the title theme): ", root.get_node("Audio").SCENE_MUSIC.get("Ending", "") == "title")
	root.get_texture().get_image().save_png("res://verify_ending.png")
	print("Saved verify_ending.png")

	# Afterwards the altar is at peace; Quit goes to the title; Play again starts over.
	game_state.world_progress.game_completed = true
	var over2: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(over2)
	current_scene = over2
	for i in range(3):
		await process_frame
	altar.interact()
	await process_frame
	print("With the game completed the altar only says the valley is at peace: ", dialogue_ui.is_open() and dialogue_ui.text_label.text.contains("at peace") and not swirl.playing)
	dialogue_ui.hide_dialogue()
	await process_frame
	ending = load("res://scenes/Ending.tscn").instantiate()
	root.add_child(ending)
	current_scene = ending
	for i in range(3):
		await process_frame
	ending.quit_btn.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	print("Quit to title lands on the title screen: ", current_scene != null and current_scene.name == "Title")
	ending = load("res://scenes/Ending.tscn").instantiate()
	root.add_child(ending)
	current_scene = ending
	for i in range(3):
		await process_frame
	ending.play_btn.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	print("Play again starts a fresh game (no bosses asleep, not completed, at home): ", not game_state.boss_defeated.final_boss and not game_state.world_progress.get("game_completed", false) and current_scene != null and current_scene.name == "House")
	root.get_node("Intro").cancel()
	quit()
