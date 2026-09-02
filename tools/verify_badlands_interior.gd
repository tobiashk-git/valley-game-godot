extends SceneTree
# Phase 4 (Emberfall Badlands deep pass) verification. Run via:
# godot --script res://tools/verify_badlands_interior.gd (NOT --headless -
# this takes real screenshots via get_texture()).
#
# Applies every lesson from Phases 2-3's verify scripts from the start:
# physics_frame for movement waits, a combat.in_combat clear after every
# teleport/walk in a live-encounter zone, positioning with real margin
# inside a portal's trigger rather than relying on a straight walk to stop
# exactly in range, actually walking the last tile onto an exit door, and
# alternating movement direction for the encounter-pool check.

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

# Badlands' ford crossing is a vertical (north-south) walk along
# x=WORLD_CENTER_X - which runs directly through DUNGEON_ENTRANCE, sitting
# exactly on that column. Clear by column-proximity (not row, like
# Verdantwood's horizontal walk needed).
func _clear_corridor_column(overworld: Node2D, player: CharacterBody2D, x: float) -> void:
	var ysort: Node2D = overworld.get_node("YSort")
	for child in ysort.get_children():
		if child != player and child is Node2D and absf(child.position.x - x) < 56.0:
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

	# --- 1. Quest flow via the standalone Badlands Prospector NPC. ---
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var prospector: Node = null
	for child in overworld.get_node("YSort").get_children():
		if child.get("npc_id") == "badlands_prospector":
			prospector = child
	print("Badlands Prospector NPC found: ", prospector != null)

	player.position = prospector.position + Vector2(0, 20)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Intro shown first: ", dialogue_ui.text_label.text.begins_with("Emberfall's past that ford"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Offer text shown: ", dialogue_ui.text_label.text.begins_with("The ford into Emberfall's crumbling"))
	var offer_actions: Array = dialogue_ui.actions_row.get_children()
	offer_actions[0].pressed.emit()
	await process_frame
	print("Quest accepted: ", quests.quest_state.get("cross_badlands", "") == "accepted")

	inventory.add_item("stone", 4)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("In-progress shows partial Stone: ", dialogue_ui.text_label.text.contains("4/12"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	inventory.add_item("stone", 8)
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
	print("Stone deducted: ", inventory.get_count("stone") == 0)
	print("Gold granted: ", inventory.get_count("gold") == gold_before + 35)
	print("Potions granted: ", inventory.get_count("healing_potion") == potions_before + 2)
	print("Quest marked completed: ", quests.quest_state.get("cross_badlands", "") == "completed")
	print("Badlands ford flag opened: ", game_state.biome_paths_open.badlands == true)

	root.remove_child(overworld)
	overworld.queue_free()
	await process_frame

	# --- 2/3. Ford now walkable, entrance reachable in Badlands territory. ---
	game_state.village_gates_open = true
	var overworld2: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld2)
	current_scene = overworld2
	await process_frame
	await process_frame

	var player2: CharacterBody2D = overworld2.get_node("YSort/Player")
	var cam2: Camera2D = player2.get_node("Camera2D")
	var center_x: float = world.WORLD_CENTER_X * 32 + 16
	await _clear_corridor_column(overworld2, player2, center_x)
	player2.position = Vector2(center_x, (world.WORLD_CENTER_Y + 3) * 32 + 16)
	cam2.reset_smoothing()
	# village edge (+3) to just past the ring (+25): 22 tiles = 704px, ~264
	# ticks minimum at ~2.67px/tick - generous margin.
	await _walk(player2, "move_down", 350)
	var river_y: float = float(world.WORLD_CENTER_Y + world.VALLEY_RADIUS) * 32.0
	print("Crossed the now-open ford into Badlands territory: ", player2.position.y > river_y)
	await _clear_combat(combat)

	var entrance_center: Vector2 = Vector2(world.BADLANDS_INTERIOR_ENTRANCE.x * 32 + 16, world.BADLANDS_INTERIOR_ENTRANCE.y * 32 + 16)
	player2.position = entrance_center + Vector2(0, -20) # real margin inside the 56x56 trigger, not right at its edge
	cam2.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	await _walk(player2, "move_down", 20) # short approach, proves movement isn't broken near the entrance
	await _clear_combat(combat)
	player2.position = entrance_center + Vector2(0, -20)
	await process_frame
	await _clear_combat(combat)

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Entered BadlandsInterior via the real portal: ", current_scene.name == "BadlandsInterior")
	print("Badlands interior marked discovered: ", game_state.discovered_pois.badlands_interior == true)
	root.get_texture().get_image().save_png("res://verify_badlands_entrance.png")

	# --- 4. Interior loaded with the expected shared skeleton. ---
	var interior: Node2D = current_scene
	var terrain: TileMapLayer = interior.get_node("TerrainLayer")
	var fog: TileMapLayer = interior.get_node("FogLayer")
	print("Interior has TerrainLayer + FogLayer: ", terrain != null and fog != null)
	player = interior.get_node("YSort/Player") # the scene change freed the Overworld's Player

	# --- 5. Crumbling rim (same mechanic as Frostpeak's brittle bridge). ---
	var rim_tile := Vector2i(-9999, -9999)
	for pos in interior.hazard_map:
		if interior.hazard_map[pos] == "rim":
			rim_tile = pos
			break
	print("Rim hazard cell found: ", rim_tile != Vector2i(-9999, -9999))
	player.position = interior._tile_center(rim_tile)
	await process_frame
	await process_frame
	await _clear_combat(combat)
	player.position = interior._tile_center(interior._gen.spawn_tile) # step off, vacating the rim tile
	await process_frame
	await _clear_combat(combat)
	for i in range(75): # RIM_BREAK_DELAY (1.0s) at 60 ticks/s + margin
		await physics_frame
	print("Vacated rim tile source becomes SRC_WALL: ", terrain.get_cell_source_id(rim_tile) == 0)

	# --- 6. Geyser vents. ---
	var geyser_tile := Vector2i(-9999, -9999)
	for pos in interior.hazard_map:
		if interior.hazard_map[pos] == "geyser":
			geyser_tile = pos
			break
	print("Geyser hazard cell found: ", geyser_tile != Vector2i(-9999, -9999))
	player.position = interior._tile_center(geyser_tile)
	await process_frame
	await _clear_combat(combat)
	# Force the cycle to just before an eruption starts, then advance past
	# the wrap so it enters the erupting window. Poll for the actual push
	# rather than a fixed tick count - idle-frame delta size (and therefore
	# how many ticks are needed to accumulate the remaining 0.05s of game
	# time) varies run to run in this environment.
	interior._geyser_cycle_time = 2.95 # GEYSER_CYCLE (3.0) - 0.05
	interior._geyser_pushed_this_eruption = false
	var pos_before_eruption: Vector2 = player.position
	var pushed := false
	for i in range(120): # generous cap - well under the 0.6s eruption window even at a slow tick rate
		await physics_frame
		if interior._geyser_pushed_this_eruption:
			pushed = true
			break
	var pos_after_eruption: Vector2 = player.position
	var pushed_distance: float = pos_before_eruption.distance_to(pos_after_eruption)
	print("Geyser pushed the player roughly 2 tiles (~64px): ", pushed and pushed_distance > 50.0 and pushed_distance < 80.0)
	for i in range(15): # a few more ticks, still within the same eruption window
		await physics_frame
	print("No second push within the same eruption: ", player.position.distance_to(pos_after_eruption) < 1.0)

	# --- 7. Boss fight. ---
	var boss: Node = null
	for child in interior.ysort.get_children():
		if child.name == "Boss":
			boss = child
	print("Boss node found: ", boss != null)
	print("Boss id is badlands_boss: ", boss.boss_id == "badlands_boss")

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
	print("Fighting the right boss: ", combat.current_enemies[0].name == "Cinderjaw")

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
	print("Badlands boss checkpoint marked defeated: ", game_state.boss_defeated.badlands_boss)
	print("Gold granted: ", inventory.get_count("gold") > boss_gold_before)
	print("Healing potion granted: ", inventory.get_count("healing_potion") > boss_potions_before)

	await process_frame
	print("Broken rim tile repaired after boss defeat: ", terrain.get_cell_source_id(rim_tile) == 2)

	# --- 8. Encounter pool: only the 3 Badlands monsters. ---
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
		var names := {"Magma Slime": true, "Fire Drake": true, "Ash Golem": true}
		var wrong_enemy := false
		for enemy in combat.current_enemies:
			if enemy != null and not names.has(enemy.name):
				wrong_enemy = true
		print("Every enemy is one of the 3 Badlands monsters: ", not wrong_enemy)
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
	print("Left BadlandsInterior via the real portal: ", current_scene.name == "Overworld")
	var back_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed just outside the volcano entrance: ", back_tile == world.BADLANDS_INTERIOR_ENTRANCE + Vector2i(0, 1))

	# --- 10. Fast travel. ---
	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame
	var list: VBoxContainer = world_map_panel.get_node("Panel/Margin/VBox/List")
	var bl_row: HBoxContainer = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "Emberfall Caldera":
			bl_row = row
	print("World Map lists Emberfall Caldera: ", bl_row != null)
	var bl_btn: Button = bl_row.get_child(1)
	bl_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel lands on Overworld: ", current_scene.name == "Overworld")
	var travel_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Fast travel landed at the volcano entrance: ", travel_tile == world.BADLANDS_INTERIOR_ENTRANCE + Vector2i(0, 1))

	quit()
