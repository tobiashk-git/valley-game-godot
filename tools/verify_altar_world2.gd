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

	character.stats.max_hp = 500
	character.stats.hp = 500
	character.stats.mp = 999

	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	print("HUD shows World 1: ", hud.world_label.text == "World 1")

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
	print("Final boss now revealed: ", game_state.world_progress.final_boss_revealed)
	print("Reveal message shown: ", dialogue_ui.text_label.text.contains("hidden path"))
	root.get_texture().get_image().save_png("res://verify_altar_revealed.png")
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# --- Walk to the final boss entrance, confirm it's real and enterable. ---
	var approach: Vector2i = world.FINAL_BOSS_ENTRANCE + Vector2i(0, 2)
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
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Left the final boss maze via the real portal: ", current_scene.name == "Overworld")

	# --- Altar again: boss dead, crystal in hand - opens the portal. ---
	player = current_scene.get_node("YSort/Player")
	player.position = Vector2(altar_tile.x * 32 + 16, (altar_tile.y + 4) * 32 + 16)
	cam = player.get_node("Camera2D")
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(player, "move_up", 60)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Third crystal consumed: ", inventory.get_count("magic_crystal") == 0)
	print("World2 unlocked flag set: ", game_state.world_progress.world2_unlocked)
	print("Portal-opens message shown: ", dialogue_ui.text_label.text.contains("portal to a new world"))
	print("Still on Overworld (didn't auto-travel): ", current_scene.name == "Overworld")
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# --- Interact again: this time it actually travels to World 2. ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Traveled to World 2: ", current_scene.name == "Overworld2")
	await process_frame
	print("HUD shows World 2: ", hud.world_label.text == "World 2")
	root.get_texture().get_image().save_png("res://verify_world2.png")

	# --- World 2 boundary works too. ---
	var w2player: CharacterBody2D = current_scene.get_node("YSort/Player")
	var w2cam: Camera2D = w2player.get_node("Camera2D")
	w2player.position = Vector2(5 * 32 + 16, world.WORLD_CENTER_Y * 32 + 16)
	w2cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _walk(w2player, "move_left", 60)
	print("World 2 west boundary holds: ", w2player.position.x >= -32.0)

	# --- Return portal takes us back to World 1, at the altar plaza. ---
	# Unlike the altar/entrance props, the return portal has no separate
	# solid StaticBody2D blocking it (Area2D alone doesn't block
	# CharacterBody2D movement), so a small close offset works directly -
	# same convention as approaching an NPC/chest.
	w2player.position = Vector2(world.WORLD_CENTER_X * 32 + 16, world.WORLD_CENTER_Y * 32 + 16 + 15)
	w2cam.reset_smoothing()
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Returned to Overworld (World 1): ", current_scene.name == "Overworld")
	var back_player: CharacterBody2D = current_scene.get_node("YSort/Player")
	var back_tile := Vector2i(int(back_player.position.x / 32), int(back_player.position.y / 32))
	print("Landed at the village altar plaza: ", back_tile == world.ALTAR_POS + Vector2i(0, 2))

	quit()
