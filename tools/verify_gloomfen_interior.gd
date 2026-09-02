extends SceneTree
# Phase 5 (Gloomfen Marsh deep pass) verification. Run via:
# godot --script res://tools/verify_gloomfen_interior.gd (NOT --headless -
# this takes real screenshots via get_texture()).
#
# Applies every lesson from Phases 2-4's verify scripts from the start:
# physics_frame for movement waits, a combat.in_combat clear after every
# teleport/walk in a live-encounter zone, positioning with real margin
# inside a portal's trigger, actually walking the last tile onto an exit
# door, alternating movement direction for the encounter-pool check, polling
# for a timer/cycle state transition rather than assuming a fixed tick
# count, and matching the Marsh Guide (the 3rd standalone NPC now) by
# npc_id rather than a name/node prefix.

func _walk(player: CharacterBody2D, action: String, frames: int) -> void:
	Input.action_press(action)
	for i in range(frames):
		await physics_frame
	Input.action_release(action)
	await physics_frame

func _clear_combat(combat: Node) -> void:
	if combat.in_combat:
		combat.player_run()
		await physics_frame

# Gloomfen's ford crossing is a horizontal (east-west) walk along
# y=WORLD_CENTER_Y - same row as CASTLE_ENTRANCE, matching Verdantwood's
# case (not Frostpeak's/Badlands' vertical one) - use the row-proximity
# variant.
func _clear_corridor_row(overworld: Node2D, player: CharacterBody2D, y: float) -> void:
	var ysort: Node2D = overworld.get_node("YSort")
	for child in ysort.get_children():
		if child != player and child is Node2D and absf(child.position.y - y) < 56.0:
			child.queue_free()
	await process_frame
	await process_frame

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var quests: Node = root.get_node("Quests")
	var inventory: Node = root.get_node("Inventory")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var world_map_panel: Node = root.get_node("WorldMapPanel")

	# --- 1. Quest flow via the standalone Marsh Guide NPC. ---
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var guide: Node = null
	for child in overworld.get_node("YSort").get_children():
		if child.get("npc_id") == "marsh_guide":
			guide = child
	print("Marsh Guide NPC found: ", guide != null)

	player.position = guide.position + Vector2(0, 20)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Intro shown first: ", dialogue_ui.text_label.text.begins_with("Gloomfen's past that ford"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Offer text shown: ", dialogue_ui.text_label.text.begins_with("The old boardwalk into Gloomfen"))
	var offer_actions: Array = dialogue_ui.actions_row.get_children()
	offer_actions[0].pressed.emit()
	await process_frame
	print("Quest accepted: ", quests.quest_state.get("cross_gloomfen", "") == "accepted")

	inventory.add_item("wood", 4)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("In-progress shows partial Wood: ", dialogue_ui.text_label.text.contains("4/12"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	inventory.add_item("wood", 8)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Ready text shown: ", dialogue_ui.text_label.text.begins_with("That'll do it"))
	var ready_actions: Array = dialogue_ui.actions_row.get_children()
	var gold_before: int = inventory.get_count("gold")
	var potions_before: int = inventory.get_count("healing_potion")
	ready_actions[0].pressed.emit()
	await process_frame
	print("Wood deducted: ", inventory.get_count("wood") == 0)
	print("Gold granted: ", inventory.get_count("gold") == gold_before + 35)
	print("Potions granted: ", inventory.get_count("healing_potion") == potions_before + 2)
	print("Quest marked completed: ", quests.quest_state.get("cross_gloomfen", "") == "completed")
	print("Gloomfen ford flag opened: ", game_state.biome_paths_open.gloomfen == true)

	root.remove_child(overworld)
	overworld.queue_free()
	await process_frame

	# --- 2/3. Ford now walkable, entrance reachable in Gloomfen territory. ---
	game_state.village_gates_open = true
	var overworld2: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld2)
	current_scene = overworld2
	await process_frame
	await process_frame

	var player2: CharacterBody2D = overworld2.get_node("YSort/Player")
	var cam2: Camera2D = player2.get_node("Camera2D")
	var center_y: float = world.WORLD_CENTER_Y * 32 + 16
	await _clear_corridor_row(overworld2, player2, center_y)
	player2.position = Vector2((world.WORLD_CENTER_X - 3) * 32 + 16, center_y)
	cam2.reset_smoothing()
	# village edge (-3) to just past the ring (-25): 22 tiles = 704px, ~264
	# ticks minimum at ~2.67px/tick - generous margin.
	await _walk(player2, "move_left", 350)
	var river_x: float = float(world.WORLD_CENTER_X - world.VALLEY_RADIUS) * 32.0
	print("Crossed the now-open ford into Gloomfen territory: ", player2.position.x < river_x)
	await _clear_combat(combat)

	var entrance_center: Vector2 = Vector2(world.GLOOMFEN_INTERIOR_ENTRANCE.x * 32 + 16, world.GLOOMFEN_INTERIOR_ENTRANCE.y * 32 + 16)
	player2.position = entrance_center + Vector2(20, 0) # real margin inside the 56x56 trigger, not right at its edge
	cam2.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	await _walk(player2, "move_left", 20) # short approach, proves movement isn't broken near the entrance
	await _clear_combat(combat)
	player2.position = entrance_center + Vector2(20, 0)
	await process_frame
	await _clear_combat(combat)

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Entered GloomfenInterior via the real portal: ", current_scene.name == "GloomfenInterior")
	print("Gloomfen interior marked discovered: ", game_state.discovered_pois.gloomfen_interior == true)
	root.get_texture().get_image().save_png("res://verify_gloomfen_entrance.png")

	# --- 4. Interior loaded with the expected shared skeleton. ---
	var interior: Node2D = current_scene
	var terrain: TileMapLayer = interior.get_node("TerrainLayer")
	var fog: TileMapLayer = interior.get_node("FogLayer")
	print("Interior has TerrainLayer + FogLayer: ", terrain != null and fog != null)
	player = interior.get_node("YSort/Player") # the scene change freed the Overworld's Player

	# --- 5. Sinking platform - full sink after lingering past the timer. ---
	var platform_tiles: Array = []
	for pos in interior.hazard_map:
		if interior.hazard_map[pos] == "platform":
			platform_tiles.append(pos)
	print("Platform hazard cells found (expect 2): ", platform_tiles.size() == 2)
	var platform_tile: Vector2i = platform_tiles[0]
	player.position = interior._tile_center(platform_tile)
	await process_frame
	await process_frame
	await _clear_combat(combat)
	var sank_ready := false
	for i in range(240): # generous cap, well past PLATFORM_SINK_TIME (2.0s)
		await physics_frame
		if interior._platform_ready_to_sink.get(platform_tile, false):
			sank_ready = true
			break
	print("Platform marked ready-to-sink after lingering: ", sank_ready)
	print("Occupied platform tile stays walkable (still SRC_PLATFORM): ", terrain.get_cell_source_id(platform_tile) == interior.SRC_PLATFORM)
	player.position = interior._tile_center(interior._gen.spawn_tile) # step off, vacating the platform
	await process_frame
	await process_frame
	await _clear_combat(combat)
	print("Vacated ready platform becomes SRC_WALL: ", terrain.get_cell_source_id(platform_tile) == interior.SRC_WALL)

	# --- 5b. Sinking platform - early exit resets the countdown (no sink). ---
	var platform_tile2: Vector2i = platform_tiles[1]
	player.position = interior._tile_center(platform_tile2)
	await process_frame
	await process_frame
	await _clear_combat(combat)
	for i in range(30): # well under PLATFORM_SINK_TIME - leaves before it's ready
		await physics_frame
	print("Early-exit tile not yet ready: ", not interior._platform_ready_to_sink.get(platform_tile2, false))
	player.position = interior._tile_center(interior._gen.spawn_tile)
	await process_frame
	await process_frame
	await _clear_combat(combat)
	print("Early-exit platform does NOT sink: ", terrain.get_cell_source_id(platform_tile2) == interior.SRC_PLATFORM)

	# --- 6. Sticky mud - partial slow, not a full stop. ---
	var mud_tiles: Array = []
	for pos in interior.hazard_map:
		if interior.hazard_map[pos] == "mud":
			mud_tiles.append(pos)
	print("Mud hazard cells found: ", mud_tiles.size() > 0)
	var mud_min_x := 999999
	var mud_row := 0
	for pos in mud_tiles:
		if pos.x < mud_min_x:
			mud_min_x = pos.x
			mud_row = pos.y
	var mud_start := Vector2i(mud_min_x + 1, mud_row) # inset from the room's west wall
	player.position = interior._tile_center(mud_start)
	await process_frame
	await process_frame
	await _clear_combat(combat)
	var mud_pos_before: Vector2 = player.position
	var mud_walk_ticks := 15
	await _walk(player, "move_right", mud_walk_ticks)
	await _clear_combat(combat)
	var mud_displacement: float = mud_pos_before.distance_to(player.position)

	# Compared against the theoretical unobstructed full-speed displacement
	# (player.gd's SPEED is a constant velocity, no acceleration ramp) rather
	# than a second measured walk on some other floor tile - the entrance
	# room's actual open space near spawn_tile varies with each random maze
	# layout, and a walk that clips a nearby wall mid-burst produces a
	# floor_displacement far below true full speed, which previously made
	# this check flake independent of whether the mud mechanic itself was
	# working correctly.
	var full_speed_displacement: float = float(mud_walk_ticks) * (player.SPEED / 60.0)
	var mud_ratio: float = mud_displacement / full_speed_displacement
	print("Mud slows movement to roughly 40% of floor speed: ", mud_ratio > 0.25 and mud_ratio < 0.55)

	# --- 7. Boss fight. ---
	var boss: Node = null
	for child in interior.ysort.get_children():
		if child.name == "Boss":
			boss = child
	print("Boss node found: ", boss != null)
	print("Boss id is gloomfen_boss: ", boss.boss_id == "gloomfen_boss")

	player.position = boss.position + Vector2(0, 20)
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Boss fight started: ", combat.in_combat)
	print("Fighting the right boss: ", combat.current_enemies[0].name == "The Bogmaw")

	character.stats.max_hp = 500
	character.stats.hp = 500
	character.stats.mp = 999
	var boss_gold_before: int = inventory.get_count("gold")
	var boss_potions_before: int = inventory.get_count("healing_potion")
	var guard := 0
	while combat.in_combat and guard < 40:
		combat.cast_spell("fireball")
		await process_frame
		guard += 1
	print("Boss defeated (", guard, " actions): ", not combat.in_combat)
	print("Gloomfen boss checkpoint marked defeated: ", game_state.boss_defeated.gloomfen_boss)
	print("Gold granted: ", inventory.get_count("gold") > boss_gold_before)
	print("Healing potion granted: ", inventory.get_count("healing_potion") > boss_potions_before)

	await process_frame
	print("Broken platform tile repaired after boss defeat: ", terrain.get_cell_source_id(platform_tile) == interior.SRC_PLATFORM)

	# --- 8. Encounter pool: only the 3 Gloomfen monsters. ---
	player.position = interior._tile_center(interior._gen.spawn_tile)
	await process_frame
	await _clear_combat(combat)
	var got_encounter := false
	var directions := ["move_left", "move_right", "move_up", "move_down"]
	for burst in range(30):
		if got_encounter:
			break
		var action: String = directions[burst % directions.size()]
		Input.action_press(action)
		for i in range(20):
			await physics_frame
			if combat.in_combat:
				got_encounter = true
				break
		Input.action_release(action)
		await physics_frame
	print("Interior random encounter fired: ", got_encounter)
	if got_encounter:
		var names := {"Swamp Hag": true, "Giant Insect": true, "Spectral Undead": true}
		var wrong_enemy := false
		for enemy in combat.current_enemies:
			if enemy != null and not names.has(enemy.name):
				wrong_enemy = true
		print("Every enemy is one of the 3 Gloomfen monsters: ", not wrong_enemy)
		combat.player_run()
		await process_frame

	# --- 9. Exit door returns to the correct overworld position. ---
	player.position = interior._tile_center(interior._gen.spawn_tile)
	await process_frame
	await _clear_combat(combat)
	await _walk(player, "move_down", 20) # spawn_tile sits one tile north of the door - walk the last step onto it
	await _clear_combat(combat)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Left GloomfenInterior via the real portal: ", current_scene.name == "Overworld")
	var back_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed just outside the submerged temple entrance: ", back_tile == world.GLOOMFEN_INTERIOR_ENTRANCE + Vector2i(0, 1))

	# --- 10. Fast travel. ---
	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame
	var list: VBoxContainer = world_map_panel.get_node("Panel/Margin/VBox/List")
	var gf_row: HBoxContainer = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "Sunken Gloomfen Temple":
			gf_row = row
	print("World Map lists Sunken Gloomfen Temple: ", gf_row != null)
	var gf_btn: Button = gf_row.get_child(1)
	gf_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel lands on Overworld: ", current_scene.name == "Overworld")
	var travel_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Fast travel landed at the submerged temple entrance: ", travel_tile == world.GLOOMFEN_INTERIOR_ENTRANCE + Vector2i(0, 1))

	quit()
