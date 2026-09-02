extends SceneTree
# Phase 6a (Golden Plains' own interior) verification. Run via:
# godot --script res://tools/verify_golden_plains_interior.gd (NOT
# --headless - this takes real screenshots via get_texture()).
#
# Structurally simpler than the 4 outer-biome interiors: no ford crossing (no
# river ring around Golden Plains/Zone.VALLEY), no hazard tiles, and the
# gating quest is given by an EXISTING NPC (the Village Trader) that must
# also still work as a shop afterward - see npc.gd's quest-active-before-shop
# dispatch priority added this phase. Applies every established lesson from
# the start: physics_frame for movement waits, a combat.in_combat clear after
# every teleport/walk, positioning with real margin inside a portal's
# trigger, actually walking the last tile onto an exit door.

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

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var quests: Node = root.get_node("Quests")
	var inventory: Node = root.get_node("Inventory")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var world_map_panel: Node = root.get_node("WorldMapPanel")
	var shop_panel: Node = root.get_node("ShopPanel")

	# --- 1. The entrance does NOT exist before the gating quest completes. ---
	var overworld0: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld0)
	current_scene = overworld0
	await process_frame
	await process_frame

	var player0: CharacterBody2D = overworld0.get_node("YSort/Player")
	var cam0: Camera2D = player0.get_node("Camera2D")
	var entrance_center: Vector2 = Vector2(world.GOLDEN_PLAINS_INTERIOR_ENTRANCE.x * 32 + 16, world.GOLDEN_PLAINS_INTERIOR_ENTRANCE.y * 32 + 16)
	player0.position = entrance_center
	cam0.reset_smoothing()
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Entrance does not exist before the quest completes: ", current_scene.name == "Overworld")

	root.remove_child(overworld0)
	overworld0.queue_free()
	await process_frame

	# --- 2. Quest flow via the Village Trader (TraderHouse) - also still a shop. ---
	var trader_house: Node2D = load("res://scenes/TraderHouse.tscn").instantiate()
	root.add_child(trader_house)
	current_scene = trader_house
	await process_frame
	await process_frame

	var house_player: CharacterBody2D = trader_house.get_node("YSort/Player")
	var house_ysort: Node2D = trader_house.get_node("YSort")
	var trader: Node = null
	for child in house_ysort.get_children():
		if child.get("npc_id") == "village_trader":
			trader = child
	print("Village Trader NPC found: ", trader != null)

	house_player.position = trader.position + Vector2(0, 20)
	for i in range(3):
		await process_frame

	# One-time intro first.
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Intro shown first: ", dialogue_ui.text_label.text.begins_with("Welcome, welcome"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# Quest offer takes priority over the shop while the quest is active.
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Offer text shown (quest, not shop): ", dialogue_ui.text_label.text.begins_with("There's an old barrow"))
	var offer_actions: Array = dialogue_ui.actions_row.get_children()
	offer_actions[0].pressed.emit()
	await process_frame
	print("Quest accepted: ", quests.quest_state.get("open_ancient_barrow", "") == "accepted")

	inventory.add_item("stone", 3)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("In-progress shows partial Stone: ", dialogue_ui.text_label.text.contains("3/6"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	inventory.add_item("stone", 3)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Ready text shown: ", dialogue_ui.text_label.text.begins_with("That's enough"))
	var ready_actions: Array = dialogue_ui.actions_row.get_children()
	var gold_before: int = inventory.get_count("gold")
	var potions_before: int = inventory.get_count("healing_potion")
	ready_actions[0].pressed.emit()
	await process_frame
	print("Stone deducted: ", inventory.get_count("stone") == 0)
	print("Gold granted: ", inventory.get_count("gold") == gold_before + 25)
	print("Potions granted: ", inventory.get_count("healing_potion") == potions_before + 1)
	print("Quest marked completed: ", quests.quest_state.get("open_ancient_barrow", "") == "completed")
	print("Golden Plains revealed flag set: ", game_state.world_progress.golden_plains_revealed == true)

	# Now that the quest is completed, interacting should open the shop -
	# confirms npc.gd's quest-active-before-shop priority correctly falls
	# through once there's no active quest left to show.
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Shop still opens once the quest is completed: ", shop_panel.is_open())
	shop_panel.close()
	await process_frame

	root.remove_child(trader_house)
	trader_house.queue_free()
	await process_frame

	# --- 3. Entrance now exists and is reachable in the Overworld. ---
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	player.position = entrance_center + Vector2(20, 0) # real margin inside the 56x56 trigger, not right at its edge
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	await _walk(player, "move_left", 20) # short approach, proves movement isn't broken near the entrance
	await _clear_combat(combat)
	player.position = entrance_center + Vector2(20, 0)
	await process_frame
	await _clear_combat(combat)

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Entered GoldenPlainsInterior via the real portal: ", current_scene.name == "GoldenPlainsInterior")
	print("Golden Plains interior marked discovered: ", game_state.discovered_pois.golden_plains_interior == true)
	root.get_texture().get_image().save_png("res://verify_golden_plains_entrance.png")

	# --- 4. Interior loaded with the expected shared skeleton. ---
	var interior: Node2D = current_scene
	var terrain: TileMapLayer = interior.get_node("TerrainLayer")
	var fog: TileMapLayer = interior.get_node("FogLayer")
	print("Interior has TerrainLayer + FogLayer: ", terrain != null and fog != null)
	player = interior.get_node("YSort/Player") # the scene change freed the Overworld's Player

	# --- 5. Zero random encounters - a real regression check, not luck. ---
	player.position = interior._tile_center(interior._gen.spawn_tile)
	await process_frame
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
	print("Zero random encounters exploring the interior: ", not got_encounter)

	# --- 6. Boss fight. ---
	var boss: Node = null
	for child in interior.ysort.get_children():
		if child.name == "Boss":
			boss = child
	print("Boss node found: ", boss != null)
	print("Boss id is golden_plains_boss: ", boss.boss_id == "golden_plains_boss")

	player.position = boss.position + Vector2(0, 20)
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Boss fight started: ", combat.in_combat)
	print("Fighting the right boss: ", combat.current_enemies[0].name == "The Barrow Warden")

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
	print("Golden Plains boss checkpoint marked defeated: ", game_state.boss_defeated.golden_plains_boss)
	print("Gold granted: ", inventory.get_count("gold") > boss_gold_before)
	print("Healing potion granted: ", inventory.get_count("healing_potion") > boss_potions_before)

	# --- 7. Exit door returns to the correct overworld position. ---
	player.position = interior._tile_center(interior._gen.spawn_tile)
	await process_frame
	await _walk(player, "move_down", 20) # spawn_tile sits one tile north of the door - walk the last step onto it
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Left GoldenPlainsInterior via the real portal: ", current_scene.name == "Overworld")
	var back_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed just outside the barrow entrance: ", back_tile == world.GOLDEN_PLAINS_INTERIOR_ENTRANCE + Vector2i(0, 1))

	# --- 8. Fast travel. ---
	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame
	var list: VBoxContainer = world_map_panel.get_node("Panel/Margin/VBox/List")
	var gp_row: HBoxContainer = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "The Ancient Barrow":
			gp_row = row
	print("World Map lists The Ancient Barrow: ", gp_row != null)
	var gp_btn: Button = gp_row.get_child(1)
	gp_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel lands on Overworld: ", current_scene.name == "Overworld")
	var travel_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Fast travel landed at the barrow entrance: ", travel_tile == world.GOLDEN_PLAINS_INTERIOR_ENTRANCE + Vector2i(0, 1))

	quit()
