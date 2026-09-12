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
	var dialogue_ui: Node = root.get_node("DialogueUI")
	var hud: Node = root.get_node("HUD")

	character.stats.max_hp = 2000 # the Warden hits ~27 a round under percentage mitigation; 500 fell in 19 rounds
	character.stats.hp = 2000
	character.stats.mp = 999

	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	# The HUD's "World N" indicator became a location/biome label.
	print("HUD shows the village biome: ", hud.location_label.text == "Golden Plains")

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# --- Altar with no crystals: progress message only. ---
	# The altar tile is solid (like any entrance), so - same technique as
	# every entrance test - start a few tiles off and walk in, letting
	# collision naturally stop the player right at its edge, rather than
	# guessing an exact "close enough" position by hand.
	var altar_tile: Vector2i = world.ALTAR_POS
	player.position = Vector2(altar_tile.x * 32 + 16, (altar_tile.y + 4) * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(player, "move_up", 60)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Altar with 0 crystals shows progress message: ", dialogue_ui.text_label.text.contains("0/2 Magic Crystal"))
	print("Final boss not yet revealed: ", not game_state.world_progress.final_boss_revealed)
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# --- Force-grant 2 crystals (simulating both Guardians already beaten -
	# the drop mechanic itself is checked separately below), interact again. ---
	inventory.add_item("magic_crystal", 2)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Crystals consumed on reveal: ", inventory.get_count("magic_crystal") == 0)
	print("(The Warden's crystal now ends the game - see verify_ending.gd - so this verify stops at the lair.)", "")
	print("Final boss now revealed: ", game_state.world_progress.final_boss_revealed)
	print("Reveal message shown: ", dialogue_ui.text_label.text.contains("hidden path"))
	root.get_texture().get_image().save_png("res://verify_altar_revealed.png")
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# --- Walk to the final boss entrance, confirm it's real and enterable. ---
	var approach: Vector2i = world.place("final_boss") + Vector2i(0, 2)
	player.position = Vector2(approach.x * 32 + 16, approach.y * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(player, "move_up", 40)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Entered the final boss maze: ", current_scene.name == "FinalBoss")

	# --- Fight and beat the final boss (boosted HP, same isolation as
	# every earlier boss test). ---
	var ysort: Node2D = current_scene.get_node("YSort")
	var boss: Node = null
	for child in ysort.get_children():
		if child.name == "Boss":
			boss = child
	print("Fighting the right boss: ", boss.boss_id == "final_boss")
	var fbplayer: CharacterBody2D = current_scene.get_node("YSort/Player")
	var spawn_pos: Vector2 = fbplayer.position
	fbplayer.position = boss.position + Vector2(0, 20)
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Boss fight started: ", combat.in_combat)

	var guard := 0
	while combat.in_combat and guard < 60:
		combat.cast_spell("fireball")
		await process_frame
		guard += 1
	print("Final boss defeated (", guard, " actions): ", not combat.in_combat)
	print("Checkpoint marked: ", game_state.boss_defeated.final_boss)
	print("Third crystal obtained: ", inventory.get_count("magic_crystal") == 1)

	# --- Exit via the door (shared blocker), confirm it works here too. ---
	fbplayer.position = spawn_pos
	for i in range(3):
		await process_frame
	await _walk(fbplayer, "move_down", 90)
	# Retry the press like a real player would - a single frame-perfect
	# press here flaked ~1 run in 3 on identical code (same lesson as the
	# interior/seam scripts' interact retries).
	var exit_tries := 0
	while current_scene.name == "FinalBoss" and exit_tries < 5:
		Input.action_press("interact")
		await process_frame
		await process_frame
		Input.action_release("interact")
		await process_frame
		await process_frame
		exit_tries += 1
	print("Left the final boss maze via the real portal: ", current_scene.name == "Overworld")

	# --- The Warden's crystal at the altar now ENDS THE GAME (2026-09-12):
	# the swirl and the completion screen are verify_ending.gd's; world 2 (the
	# portal, Overworld2) is a future version and is not walked here.
	print("World 2 stays a future version: nothing sets world2_unlocked any more: ", not game_state.world_progress.world2_unlocked)
	quit()
