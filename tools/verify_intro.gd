extends SceneTree
# In-world opening verification. Run via:
# godot --script res://tools/verify_intro.gd --log-file res://verify_log.txt (NOT --headless).
#
# New Game wakes Oliver beside his bed under black with the intro pending;
# the black fades up on him dozing (z z Z); the pages run through the
# dialogue box - Next button and E both turn them - with the player frozen;
# the last page frees him and clears the flag (saved); a save carrying the
# flag replays the intro on load, an old save without it does not; leaving
# the scene cancels a running intro; the phone box fits.

func _initialize() -> void:
	var save: Node = root.get_node("SaveSystem")
	var game_state: Node = root.get_node("GameState")
	var intro: CanvasLayer = root.get_node("Intro")
	var dialogue: CanvasLayer = root.get_node("DialogueUI")
	await process_frame
	await process_frame

	# --- New Game -> the house, black, dozing. ---
	save.new_game()
	await process_frame
	await process_frame
	await process_frame
	var player: CharacterBody2D = current_scene.get_node("YSort/Player")
	print("New Game opens in Oliver's house beside the bed, intro pending: ", current_scene.name == "House" and player.position == Vector2(current_scene.NAP_SPAWN_TILE.x * 32 + 16, current_scene.NAP_SPAWN_TILE.y * 32 + 16) and game_state.intro_pending and intro.is_playing())
	print("Screen is black, Oliver faces the bed with a z z Z, no dialogue yet: ", intro._black.visible and intro._black.modulate.a == 1.0 and player.facing == "left" and player.has_node("SleepMarker") and player.get_node("SleepMarker").visible and not dialogue.is_open())
	var before: Vector2 = player.position
	Input.action_press("move_right")
	for i in range(8):
		await process_frame
	Input.action_release("move_right")
	await process_frame
	print("Player is frozen: ", player.position == before)
	await create_timer(1.6).timeout
	print("The black has faded up on the house: ", intro._black.modulate.a < 0.2 and player.get_node("SleepMarker").visible)
	root.get_texture().get_image().save_png("res://verify_intro_wake.png")
	print("Saved verify_intro_wake.png")
	await create_timer(1.4).timeout
	print("Page 1 in the dialogue box, spoken by Oliver, with a Next button, marker gone: ", dialogue.is_open() and dialogue.name_label.text == "Oliver" and dialogue.text_label.text == intro.PAGES[0] and dialogue.actions_row.get_child_count() == 1 and dialogue.actions_row.get_child(0).text == "Next" and not player.has_node("SleepMarker"))
	root.get_texture().get_image().save_png("res://verify_intro_page1.png")
	print("Saved verify_intro_page1.png")

	# --- Next button and E both turn the page. (A timer resume lands after
	# the frame's callbacks; step to a frame start first so the button emit
	# behaves like a real click, which is handled before them.) ---
	await process_frame
	dialogue.actions_row.get_child(0).pressed.emit()
	await process_frame
	print("Next shows page 2: ", dialogue.is_open() and dialogue.text_label.text == intro.PAGES[1] and intro.page_index() == 1)
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("E turns to page 3 (closing is never a dead end): ", dialogue.is_open() and dialogue.text_label.text == intro.PAGES[2] and intro.page_index() == 2)
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("Last page offers 'Off we go': ", dialogue.is_open() and dialogue.text_label.text == intro.PAGES[3] and dialogue.actions_row.get_child(0).text == "Off we go")
	root.get_texture().get_image().save_png("res://verify_intro_last.png")
	print("Saved verify_intro_last.png")
	dialogue.actions_row.get_child(0).pressed.emit()
	await process_frame
	await process_frame
	print("Off we go ends the intro: flag cleared, box closed: ", not intro.is_playing() and not game_state.intro_pending and not dialogue.is_open())
	Input.action_press("move_right")
	for i in range(8):
		await process_frame
	Input.action_release("move_right")
	await process_frame
	print("...and Oliver can walk: ", player.position.x > before.x)

	# --- Saves: the flag rides along; an old save without it skips the intro. ---
	var snap: Dictionary = save.snapshot()
	print("Snapshot records intro_pending = false: ", snap.game_state.has("intro_pending") and snap.game_state.intro_pending == false)
	snap.game_state.intro_pending = true
	save.apply(snap)
	change_scene_to_packed(load("res://scenes/House.tscn"))
	await process_frame
	await process_frame
	await process_frame
	print("A save taken mid-intro replays it on load: ", intro.is_playing() and intro._black.visible)
	var old: Dictionary = save.snapshot()
	old.game_state.erase("intro_pending")
	# Leaving the scene cancels the running intro.
	change_scene_to_packed(load("res://scenes/Overworld.tscn"))
	await process_frame
	await process_frame
	await process_frame
	print("Changing scene cancels a running intro (black gone): ", not intro.is_playing() and not intro._black.visible)
	save.apply(old)
	change_scene_to_packed(load("res://scenes/House.tscn"))
	await process_frame
	await process_frame
	await process_frame
	print("An older save without the flag does not replay the intro: ", not game_state.intro_pending and not intro.is_playing() and not dialogue.is_open())

	# --- Phone: the page box fits the narrow screen. ---
	root.size = Vector2i(400, 660)
	for i in range(6):
		await process_frame
	save.new_game()
	await process_frame
	await process_frame
	await create_timer(3.2).timeout
	var rect: Rect2 = dialogue.panel.get_global_rect()
	print("Phone: page 1 box fits inside 400x660 with the text and button inside: ", dialogue.is_open() and dialogue.text_label.text == intro.PAGES[0] and rect.size.x <= 400.0 and rect.end.y <= 660.0 and dialogue.actions_row.get_global_rect().end.y <= rect.end.y + 0.5 and dialogue.text_label.get_global_rect().end.y <= dialogue.actions_row.get_global_rect().position.y + 0.5)
	root.get_texture().get_image().save_png("res://verify_intro_phone.png")
	print("Saved verify_intro_phone.png")
	intro.cancel()
	dialogue.hide_dialogue()
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()
