extends SceneTree
# Phase 2 (Frostpeak Ridge deep pass) verification. Run via:
# godot --script res://tools/verify_frostpeak_interior.gd (NOT --headless -
# this takes real screenshots via get_texture()).

func _walk(player: CharacterBody2D, action: String, frames: int) -> void:
	Input.action_press(action)
	for i in range(frames):
		await physics_frame
	Input.action_release(action)
	await physics_frame

# scatter_trees_and_rocks() has no fixed seed and DUNGEON_ENTRANCE sits on
# this same north-south column (see verify_biome_revamp.gd) - clear a
# corridor so the long walk north tests the quest/ford mechanic, not scatter
# placement luck.
func _clear_corridor(overworld: Node2D, player: CharacterBody2D, x: float) -> void:
	var ysort: Node2D = overworld.get_node("YSort")
	for child in ysort.get_children():
		if child != player and child is Node2D and absf(child.position.x - x) < 100.0:
			child.queue_free()
	await process_frame
	await process_frame

# scatter_biome_obstacles() has no fixed seed - an IceBoulder can
# occasionally land close enough to FROSTPEAK_INTERIOR_ENTRANCE to
# destabilize the fixed teleport-and-interact approach below even with the
# gameplay-side clearance reservation alone (confirmed directly for the
# equivalent Verdantwood/MightyOak case - a ~1-in-6 intermittent failure
# that _clear_corridor()'s own column-clear didn't fully cover). Clear a
# generous radius around one fixed world position - same "fix belongs in
# the test" reasoning as _clear_corridor() above, just keyed to a point.
func _clear_point(overworld: Node2D, player: CharacterBody2D, pos: Vector2, radius: float) -> void:
	var ysort: Node2D = overworld.get_node("YSort")
	for child in ysort.get_children():
		if child != player and child is Node2D and child.position.distance_to(pos) < radius:
			child.queue_free()
	await process_frame
	await process_frame

# Loop (not a single call) - a single physics_frame isn't always enough for
# combat.in_combat to actually settle back to false after player_run(),
# confirmed directly this session on the equivalent Verdantwood/MightyOak
# case (visually caught mid-battle in a real-rendered run - a Stone Sentinel
# encounter firing near the entrance approach and not being fully cleared
# before the portal interact).
func _clear_combat(cb: Node) -> void:
	var attempts := 0
	while cb.in_combat and attempts < 10:
		cb.player_run()
		await physics_frame
		attempts += 1

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var game_state: Node = root.get_node("GameState")
	var quests: Node = root.get_node("Quests")
	var inventory: Node = root.get_node("Inventory")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var world_map_panel: Node = root.get_node("WorldMapPanel")

	# --- 1. Quest flow via the Frostpeak Ranger (EmptyHouse). ---
	var empty_house: Node2D = load("res://scenes/EmptyHouse.tscn").instantiate()
	root.add_child(empty_house)
	current_scene = empty_house
	await process_frame
	await process_frame

	var house_player: CharacterBody2D = empty_house.get_node("YSort/Player")
	var house_ysort: Node2D = empty_house.get_node("YSort")
	var ranger: Node = null
	for child in house_ysort.get_children():
		if child.name.begins_with("NPC"):
			ranger = child
	print("Frostpeak Ranger NPC found: ", ranger != null)

	house_player.position = ranger.position + Vector2(0, 20)
	for i in range(3):
		await process_frame

	# One-time intro first.
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Intro shown first: ", dialogue_ui.text_label.text.begins_with("You made it this far"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# Quest offer.
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Offer text shown: ", dialogue_ui.text_label.text.begins_with("The ford north"))
	var offer_actions: Array = dialogue_ui.actions_row.get_children()
	offer_actions[0].pressed.emit()
	await process_frame
	print("Quest accepted: ", quests.quest_state.get("cross_frostpeak", "") == "accepted")

	# Partial materials - in-progress line.
	inventory.add_item("wood", 3)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("In-progress shows partial Wood/Stone: ", dialogue_ui.text_label.text.contains("3/8") and dialogue_ui.text_label.text.contains("0/8"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# Rest of materials - ready to turn in.
	inventory.add_item("wood", 5)
	inventory.add_item("stone", 8)
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
	print("Wood deducted: ", inventory.get_count("wood") == 0)
	print("Stone deducted: ", inventory.get_count("stone") == 0)
	print("Gold granted: ", inventory.get_count("gold") == gold_before + 35)
	print("Potions granted: ", inventory.get_count("healing_potion") == potions_before + 2)
	print("Quest marked completed: ", quests.quest_state.get("cross_frostpeak", "") == "completed")
	print("Frostpeak ford flag opened: ", game_state.biome_paths_open.frostpeak == true)

	root.remove_child(empty_house)
	empty_house.queue_free()
	await process_frame

	# --- 2/3. Ford now walkable, entrance reachable in Frostpeak territory. ---
	game_state.village_gates_open = true
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var center_x: float = world.WORLD_CENTER_X * 32 + 16
	await _clear_corridor(overworld, player, center_x)
	player.position = Vector2(center_x, (world.WORLD_CENTER_Y - 3) * 32 + 16)
	cam.reset_smoothing()
	# village edge (-3) to just past the ring (-25): 22 tiles = 704px, ~264
	# ticks minimum at ~2.67px/tick. Bumped from 350 to 400 (was already
	# "generous margin", but IceBoulder scatter now means this walk can
	# occasionally graze a boulder just outside _clear_corridor()'s cleared
	# band and lose a few ticks' worth of distance to deflection - confirmed
	# directly, a real (if low-severity) flake on this exact assertion). A
	# single-file straight walk the WHOLE way to the entrance would just
	# slide around its 1-tile collision rather than stopping there (same
	# lesson as Phase 1's DUNGEON_ENTRANCE) - teleport for the actual
	# approach instead, matching verify_castle.gd/verify_dungeon.gd's
	# convention.
	await _walk(player, "move_up", 400)
	var river_y: float = float(world.WORLD_CENTER_Y - world.VALLEY_RADIUS) * 32.0
	print("Crossed the now-open ford into Frostpeak territory: ", player.position.y < river_y)
	# That walk crosses real Frostpeak territory (past the ring), where
	# outdoor encounters are live - it can genuinely trigger combat. Combat
	# is an autoload, so leaving it in_combat would permanently block the
	# watchtower portal's own "not Combat.in_combat" guard (same lesson as
	# Phase 1's verify_biome_revamp.gd).
	await _clear_combat(combat)

	var entrance_world_pos: Vector2 = Vector2(world.FROSTPEAK_INTERIOR_ENTRANCE.x * 32 + 16, world.FROSTPEAK_INTERIOR_ENTRANCE.y * 32 + 16)
	await _clear_point(overworld, player, entrance_world_pos, 200.0)
	var approach: Vector2i = world.FROSTPEAK_INTERIOR_ENTRANCE + Vector2i(0, 2)
	player.position = Vector2(approach.x * 32 + 16, approach.y * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	# The teleport above is itself a tile-change in Frostpeak territory and
	# can roll its own encounter during these settle frames - if uncleared,
	# player.gd zeroes velocity for the entire walk below, leaving the
	# player stranded 2 tiles short of the portal's trigger range.
	await _clear_combat(combat)
	await _walk(player, "move_up", 20) # short approach, proves movement isn't broken near the entrance
	await _clear_combat(combat)
	# A straight walk into a single-tile obstacle is inherently variable
	# (move_and_slide() can deflect sideways enough to land just outside the
	# portal's 56x56 trigger, or just inside it, depending on exact contact
	# angle) - snap toward the entrance instead of relying on where the walk
	# happened to stop. The tile exactly one tile south (matching the game's
	# own target_spawn convention) sits right at the trigger's edge (32px
	# from center vs. a 28px half-width) - knife-edge, so bias a bit closer
	# to guarantee overlap for this entry attempt specifically.
	var entrance_center: Vector2 = Vector2(world.FROSTPEAK_INTERIOR_ENTRANCE.x * 32 + 16, world.FROSTPEAK_INTERIOR_ENTRANCE.y * 32 + 16)
	player.position = entrance_center + Vector2(0, 20)
	await process_frame
	await _clear_combat(combat)

	# Retry the interact press a few times, same reasoning as the
	# strengthened _clear_combat() above - a real player whose first E press
	# lands during a one-frame UI/combat-clearing race just presses E again.
	var interact_attempts := 0
	while current_scene.name != "FrostpeakInterior" and interact_attempts < 5:
		await _clear_combat(combat)
		Input.action_press("interact")
		await process_frame
		await process_frame
		Input.action_release("interact")
		await process_frame
		interact_attempts += 1
	print("Entered FrostpeakInterior via the real portal: ", current_scene.name == "FrostpeakInterior")
	print("Frostpeak interior marked discovered: ", game_state.discovered_pois.frostpeak_interior == true)
	root.get_texture().get_image().save_png("res://verify_frostpeak_entrance.png")

	# --- 4. Interior loaded with the expected shared skeleton. ---
	var interior: Node2D = current_scene
	var terrain: TileMapLayer = interior.get_node("TerrainLayer")
	var fog: TileMapLayer = interior.get_node("FogLayer")
	print("Interior has TerrainLayer + FogLayer: ", terrain != null and fog != null)
	# The scene change freed the Overworld's Player - re-fetch the new one.
	player = interior.get_node("YSort/Player")

	# --- 5. Ice sliding. ---
	var ice_room = interior._gen.room_chain[2]
	var ice_center := Vector2i(ice_room.x + ice_room.w / 2, ice_room.y + ice_room.h / 2)
	player.position = Vector2(ice_center.x * 32 + 16, ice_center.y * 32 + 16)
	await process_frame
	Input.action_press("move_right")
	for i in range(10):
		await physics_frame
	Input.action_release("move_right")
	await physics_frame # first tick after release
	var vel_after_release: Vector2 = player.velocity
	var pos_before_extra_tick: Vector2 = player.position
	await physics_frame # second tick after release
	var pos_after_extra_tick: Vector2 = player.position
	print("Still sliding after releasing input on ice: ", vel_after_release.length() > 50.0 and pos_after_extra_tick.x > pos_before_extra_tick.x + 1.0)

	# Known plain-floor tile: the entrance room's spawn tile.
	player.position = interior._tile_center(interior._gen.spawn_tile)
	await process_frame
	Input.action_press("move_right")
	for i in range(10):
		await physics_frame
	Input.action_release("move_right")
	await physics_frame
	var pos_floor_release: Vector2 = player.position
	await physics_frame
	await physics_frame
	print("Grips normally (stops quickly) on plain floor: ", player.position.distance_to(pos_floor_release) < 1.0)

	# --- 6. Brittle bridge. ---
	var final_corridor: Array = interior._gen.corridors[interior._gen.corridors.size() - 1]
	var bridge_cells: Array = []
	for pos in final_corridor:
		if interior.hazard_map.get(pos, "") == "bridge":
			bridge_cells.append(pos)
	print("Bridge corridor has hazard cells: ", bridge_cells.size() > 0)
	var bridge_a: Vector2i = bridge_cells[0]
	player.position = interior._tile_center(bridge_a)
	await process_frame
	await process_frame
	# Step off to a guaranteed-different, non-bridge tile (not just the next
	# corridor cell, which could equal bridge_a if the corridor only has one
	# hazard cell this run) so the "vacated" timer reliably starts.
	player.position = interior._tile_center(interior._gen.spawn_tile)
	await process_frame
	for i in range(75): # BRIDGE_BREAK_DELAY (1.0s) at 60 ticks/s + margin
		await physics_frame
	print("Vacated bridge tile source becomes SRC_WALL: ", terrain.get_cell_source_id(bridge_a) == 0)

	# --- 7/8. Boss fight, then bridge repairs. ---
	var boss: Node = null
	for child in interior.ysort.get_children():
		if child.name == "Boss":
			boss = child
	print("Boss node found: ", boss != null)
	print("Boss id is frostpeak_boss: ", boss.boss_id == "frostpeak_boss")

	player.position = boss.position + Vector2(0, 20)
	for i in range(3):
		await process_frame
	# The interior's own encounter_zone means this teleport (a tile change)
	# can roll a random Frostpeak monster before the interact press below -
	# left uncleared, that random fight (not the boss) would be what this
	# section actually ends up fighting.
	if combat.in_combat:
		combat.player_run()
		await physics_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Boss fight started: ", combat.in_combat)
	print("Fighting the right boss: ", combat.current_enemies[0].name == "Glacial Revenant")

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
	print("Frostpeak boss checkpoint marked defeated: ", game_state.boss_defeated.frostpeak_boss)
	print("Gold granted: ", inventory.get_count("gold") > boss_gold_before)
	print("Healing potion granted: ", inventory.get_count("healing_potion") > boss_potions_before)

	await process_frame
	print("Broken bridge tile repaired after boss defeat: ", terrain.get_cell_source_id(bridge_a) == 3)

	# --- 9. Encounter pool: only the 3 Frostpeak monsters. ---
	# A single fixed direction can hit a wall almost immediately in a small
	# room, wasting the tick budget stationary (encounters only roll on tile
	# change) - alternate directions in short bursts to keep actually moving
	# regardless of room size/shape.
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
	print("Interior random encounter fired: ", got_encounter)
	if got_encounter:
		var names := {"Ice Wraith": true, "Frost Wolf": true, "Stone Sentinel": true}
		var wrong_enemy := false
		for enemy in combat.current_enemies:
			if enemy != null and not names.has(enemy.name):
				wrong_enemy = true
		print("Every enemy is one of the 3 Frostpeak monsters: ", not wrong_enemy)
		combat.player_run()
		await process_frame

	# --- 10. Exit door returns to the correct overworld position. ---
	# spawn_tile sits one tile north of the door itself - teleporting there
	# alone leaves the player right at the edge of (or just outside) the
	# portal's trigger, unreliably. Walk the last step onto the door tile,
	# matching verify_castle.gd's proven approach.
	player.position = interior._tile_center(interior._gen.spawn_tile)
	await process_frame
	if combat.in_combat: # this teleport is itself a tile change and can roll a fresh encounter
		combat.player_run()
		await physics_frame
	await _walk(player, "move_down", 20)
	if combat.in_combat:
		combat.player_run()
		await physics_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Left FrostpeakInterior via the real portal: ", current_scene.name == "Overworld")
	var back_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Landed just outside the watchtower entrance: ", back_tile == world.FROSTPEAK_INTERIOR_ENTRANCE + Vector2i(0, 1))

	# --- 11. Fast travel. ---
	Input.action_press("toggle_map")
	await process_frame
	Input.action_release("toggle_map")
	await process_frame
	var list: VBoxContainer = world_map_panel.get_node("Panel/Margin/VBox/List")
	var fp_row: HBoxContainer = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "Frostpeak Ice Caves":
			fp_row = row
	print("World Map lists Frostpeak Ice Caves: ", fp_row != null)
	var fp_btn: Button = fp_row.get_child(1)
	fp_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Fast travel lands on Overworld: ", current_scene.name == "Overworld")
	var travel_tile := Vector2i(int(current_scene.get_node("YSort/Player").position.x / 32), int(current_scene.get_node("YSort/Player").position.y / 32))
	print("Fast travel landed at the watchtower entrance: ", travel_tile == world.FROSTPEAK_INTERIOR_ENTRANCE + Vector2i(0, 1))

	quit()
