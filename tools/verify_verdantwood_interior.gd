extends SceneTree
# Phase 3 (Verdantwood Forest deep pass) verification. Run via:
# godot --script res://tools/verify_verdantwood_interior.gd (NOT --headless -
# this takes real screenshots via get_texture()).
#
# Applies every lesson from tools/verify_frostpeak_interior.gd's debugging
# from the start: physics_frame for movement waits, a combat.in_combat clear
# after every teleport/walk in a live-encounter zone (a tile change alone
# can roll an encounter and permanently block a nearby portal/boss's own
# "not Combat.in_combat" guard), positioning with real margin inside a
# portal's trigger rather than relying on a straight walk to stop exactly in
# range, and alternating movement direction for the encounter-pool check.

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

# Verdantwood's ford crossing is a horizontal (east-west) walk along
# y=WORLD_CENTER_Y - which runs directly through CASTLE_ENTRANCE, sitting
# exactly on that row. Clear by row-proximity (not column, like Frostpeak's
# vertical walk needed) so that single-tile obstacle doesn't deflect the
# walk off course the same way DUNGEON_ENTRANCE did in Phase 1/2.
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

	# --- 1. Quest flow via the standalone Forest Druid NPC. ---
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var druid: Node = null
	for child in overworld.get_node("YSort").get_children():
		if child.name.begins_with("NPC"):
			druid = child
	print("Forest Druid NPC found: ", druid != null)

	player.position = druid.position + Vector2(0, 20)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Intro shown first: ", dialogue_ui.text_label.text.begins_with("You've wandered far"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Offer text shown: ", dialogue_ui.text_label.text.begins_with("The ford into Verdantwood"))
	var offer_actions: Array = dialogue_ui.actions_row.get_children()
	offer_actions[0].pressed.emit()
	await process_frame
	print("Quest accepted: ", quests.quest_state.get("cross_verdantwood", "") == "accepted")

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
	print("Ready text shown: ", dialogue_ui.text_label.text.begins_with("That should do it"))
	var ready_actions: Array = dialogue_ui.actions_row.get_children()
	var gold_before: int = inventory.get_count("gold")
	var potions_before: int = inventory.get_count("healing_potion")
	ready_actions[0].pressed.emit()
	await process_frame
	print("Wood deducted: ", inventory.get_count("wood") == 0)
	print("Gold granted: ", inventory.get_count("gold") == gold_before + 35)
	print("Potions granted: ", inventory.get_count("healing_potion") == potions_before + 2)
	print("Quest marked completed: ", quests.quest_state.get("cross_verdantwood", "") == "completed")
	print("Verdantwood ford flag opened: ", game_state.biome_paths_open.verdantwood == true)

	root.remove_child(overworld)
	overworld.queue_free()
	await process_frame

	# --- 2/3. Ford now walkable, entrance reachable in Verdantwood territory. ---
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
	player2.position = Vector2((world.WORLD_CENTER_X + 3) * 32 + 16, center_y)
	cam2.reset_smoothing()
	# village edge (+3) to just past the ring (+25): 22 tiles = 704px, ~264
	# ticks minimum at ~2.67px/tick - generous margin.
	await _walk(player2, "move_right", 350)
	var river_x: float = float(world.WORLD_CENTER_X + world.VALLEY_RADIUS) * 32.0
	print("Crossed the now-open ford into Verdantwood territory: ", player2.position.x > river_x)
	await _clear_combat(combat)

	var entrance_center: Vector2 = Vector2(world.VERDANTWOOD_INTERIOR_ENTRANCE.x * 32 + 16, world.VERDANTWOOD_INTERIOR_ENTRANCE.y * 32 + 16)
	player2.position = entrance_center + Vector2(-20, 0) # real margin inside the 56x56 trigger, not right at its edge
	cam2.reset_smoothing()
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	await _walk(player2, "move_right", 20) # short approach, proves movement isn't broken near the entrance
	await _clear_combat(combat)
	player2.position = entrance_center + Vector2(-20, 0)
	await process_frame
	await _clear_combat(combat)

	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Entered VerdantwoodInterior via the real portal: ", current_scene.name == "VerdantwoodInterior")
	print("Verdantwood interior marked discovered: ", game_state.discovered_pois.verdantwood_interior == true)
	root.get_texture().get_image().save_png("res://verify_verdantwood_entrance.png")

	# --- 4. Interior loaded with the expected shared skeleton. ---
	var interior: Node2D = current_scene
	var terrain: TileMapLayer = interior.get_node("TerrainLayer")
	var fog: TileMapLayer = interior.get_node("FogLayer")
	print("Interior has TerrainLayer + FogLayer: ", terrain != null and fog != null)
	player = interior.get_node("YSort/Player") # the scene change freed the Overworld's Player

	# --- 5. Root snare. ---
	var root_tile := Vector2i(-9999, -9999)
	for pos in interior.hazard_map:
		if interior.hazard_map[pos] == "root":
			root_tile = pos
			break
	player.position = interior._tile_center(root_tile)
	for i in range(3):
		await process_frame
	await _clear_combat(combat)
	# Confirm immobilization with a short held-input burst.
	Input.action_press("move_right")
	var pos_before_snare: Vector2 = player.position
	for i in range(60): # well under SNARE_DURATION's 1.5s (90 ticks) - should still be immobilized
		await physics_frame
	print("Immobilized by the root snare: ", player.position.distance_to(pos_before_snare) < 1.0)
	Input.action_release("move_right")
	# Release input and let the snare expire naturally (no input = no
	# movement regardless of the override, so this alone doesn't prove
	# anything - it's just draining the remaining duration cleanly). The
	# checkerboard root layout (see _place_hazards()) means the immediately
	# adjacent tile is always clear, but a SUSTAINED walk in one direction
	# still alternates root/clear/root/... - so the actual proof-of-release
	# check below uses a short burst that can't cross a full tile (5 ticks
	# ~= 13px, well under 32px), confirming the override itself has
	# stopped applying without getting caught by a second root tile.
	for i in range(90):
		await physics_frame
	var pos_after_snare_wears_off: Vector2 = player.position
	Input.action_press("move_right")
	for i in range(5):
		await physics_frame
	Input.action_release("move_right")
	print("Moves normally once the snare wears off: ", player.position.distance_to(pos_after_snare_wears_off) > 1.0)
	await _clear_combat(combat)

	# --- 6. Canopy fog. ---
	var canopy_tile := Vector2i(-9999, -9999)
	for pos in interior.hazard_map:
		if interior.hazard_map[pos] == "canopy":
			canopy_tile = pos
			break
	player.position = interior._tile_center(canopy_tile)
	await process_frame
	await _clear_combat(combat)
	await process_frame
	var far_cell := canopy_tile + Vector2i(2, 0) # within the base FOG_REVEAL_RADIUS (2) but outside the canopy's shrunk radius (1)
	var near_cell := canopy_tile + Vector2i(1, 0)
	print("Canopy fog: near cell revealed: ", fog.get_cell_source_id(near_cell) == -1)
	print("Canopy fog: far cell (radius 2, outside the shrunk radius) stays fogged: ", fog.get_cell_source_id(far_cell) != -1)

	# --- 7. Boss fight. ---
	var boss: Node = null
	for child in interior.ysort.get_children():
		if child.name == "Boss":
			boss = child
	print("Boss node found: ", boss != null)
	print("Boss id is verdantwood_boss: ", boss.boss_id == "verdantwood_boss")

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
	print("Fighting the right boss: ", combat.current_enemies[0].name == "Elder Bramblewood")

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
	print("Verdantwood boss checkpoint marked defeated: ", game_state.boss_defeated.verdantwood_boss)
	print("Gold granted: ", inventory.get_count("gold") > boss_gold_before)
	print("Healing potion granted: ", inventory.get_count("healing_potion") > boss_potions_before)

	# --- 8. Encounter pool: only the 3 Verdantwood monsters. ---
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
		var names := {"Forest Spirit": true, "Bandit": true, "Corrupted Fauna": true}
		var wrong_enemy := false
		for enemy in combat.current_enemies:
			if enemy != null and not names.has(enemy.name):
				wrong_enemy = true
		print("Every enemy is one of the 3 Verdantwood monsters: ", not wrong_enemy)
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
	print("Left VerdantwoodInterior via the real portal: ", current_scene.name == "Overworld")
	var back_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed just outside the druid circle entrance: ", back_tile == world.VERDANTWOOD_INTERIOR_ENTRANCE + Vector2i(0, 1))

	# --- 10. Fast travel. ---
	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame
	var list: VBoxContainer = world_map_panel.get_node("Panel/Margin/VBox/List")
	var vw_row: HBoxContainer = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "Verdantwood Grove":
			vw_row = row
	print("World Map lists Verdantwood Grove: ", vw_row != null)
	var vw_btn: Button = vw_row.get_child(1)
	vw_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel lands on Overworld: ", current_scene.name == "Overworld")
	var travel_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Fast travel landed at the druid circle entrance: ", travel_tile == world.VERDANTWOOD_INTERIOR_ENTRANCE + Vector2i(0, 1))

	quit()
