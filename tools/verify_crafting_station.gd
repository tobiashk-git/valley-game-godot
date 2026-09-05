extends SceneTree
# Crafting station + salvage verification. Run via:
# godot --script res://tools/verify_crafting_station.gd (NOT --headless).
#
# The village's bottom-right house is the Blacksmith's, with the Blacksmith
# NPC and the Workbench; the Frostpeak Ranger who lived there now camps by
# the north ford with his quest. With the station rule on (as in play):
# away from the bench the Crafting tab is browsable but Craft is disabled
# with the workbench hint and Crafting.craft() refuses; beside the bench
# the flag flips, E opens the tab, crafting works, leaving clears it.
# Salvage mode lists carried gear only, says what half the recipe gives
# back, breaks the piece down for it, refuses a boss drop, fits the phone.

func _initialize() -> void:
	var crafting: Node = root.get_node("Crafting")
	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var combat: Node = root.get_node("Combat")
	var world: Node = root.get_node("World")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	inventory.reset()
	character.reset()
	combat._steps_since_encounter = -100000
	print("Under a verify script the station rule is off by default: ", not crafting.require_station)
	crafting.require_station = true
	inventory.add_item("frost_shard", 6)
	inventory.add_item("wood", 10)
	inventory.add_item("stone", 10)

	# --- The Ranger camps outside now. ---
	var ranger: Node = null
	for child in overworld.get_node("YSort").get_children():
		if child.get("npc_id") == "frostpeak_ranger":
			ranger = child
	print("Frostpeak Ranger stands in the valley by the north ford with his quest: ", ranger != null and ranger.position == Vector2(world.RANGER_CAMP_POS.x * 32 + 16, world.RANGER_CAMP_POS.y * 32 + 16) and ranger.quest_id == "cross_frostpeak" and world.RANGER_CAMP_POS.y < world.VILLAGE_BOUNDS.y0)

	# --- Away from the bench. ---
	sheet.open("crafting")
	await process_frame
	sheet._select_recipe("frost_pick")
	await process_frame
	print("Out in the field: not at a station, Craft disabled with the workbench hint, craft() refuses: ", not crafting.at_station and sheet.craft_action.disabled and sheet.craft_hint.text == crafting.STATION_HINT and not crafting.craft("frost_pick") and inventory.get_count("frost_pick") == 0)
	sheet.close()

	# --- The Blacksmith's. ---
	change_scene_to_packed(load("res://scenes/BlacksmithHouse.tscn"))
	await process_frame
	await process_frame
	var player: CharacterBody2D = current_scene.get_node("YSort/Player")
	var bench: Node2D = null
	var smith: Node = null
	for child in current_scene.get_node("YSort").get_children():
		if child.scene_file_path == "res://scenes/props/Workbench.tscn":
			bench = child
		if child.get("npc_id") == "village_blacksmith":
			smith = child
	print("The Blacksmith's house has the Workbench and the Village Blacksmith: ", bench != null and smith != null and smith.npc_name == "Village Blacksmith" and root.get_node("HUD").location_name() == "Village")
	player.position = bench.position + Vector2(0, 40)
	for i in range(8):
		await physics_frame
	await process_frame
	print("Standing beside the bench: at a station: ", crafting.at_station)
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("E at the bench opens the Crafting tab: ", sheet.is_open() and sheet.current_tab == "crafting")
	sheet._set_craft_mode("craft")
	sheet._select_recipe("frost_pick")
	await process_frame
	print("Craft enabled here, hint back to normal: ", not sheet.craft_action.disabled and sheet.craft_hint.text != crafting.STATION_HINT)
	sheet.craft_action.pressed.emit()
	await process_frame
	print("Crafted a Frost Pick at the bench: ", inventory.get_count("frost_pick") == 1 and inventory.get_count("frost_shard") == 3)
	root.get_texture().get_image().save_png("res://verify_station_bench.png")
	print("Saved verify_station_bench.png")

	# --- Salvage mode. ---
	inventory.add_item("monster_fur", 2)
	crafting.craft("frostweave_coat")
	inventory.add_item("bone_greatsword", 1)
	character.equip("armor", "frostweave_coat")
	sheet.salvage_mode_btn.pressed.emit()
	await process_frame
	var names: Array = []
	for btn in sheet.craft_slots():
		names.append(String(btn.name))
	print("Salvage mode lists carried gear only (pick + greatsword; the worn coat stays out): ", sheet.craft_mode == "salvage" and names.has("SalvageFrostPickSlot") and names.has("SalvageBoneGreatswordSlot") and not names.has("SalvageFrostweaveCoatSlot"))
	var pick_uid: int = inventory.gear_of("frost_pick")[0].uid
	sheet._select_salvage_target(pick_uid)
	await process_frame
	var yields: Dictionary = crafting.salvage_yield("frost_pick")
	print("Frost Pick (3 shard + 2 wood) breaks down to 1 shard + 1 wood, shown in the pane: ", yields == {"frost_shard": 1, "wood": 1} and sheet.craft_rows.has_node("YieldFrostShard") and sheet.craft_rows.has_node("YieldWood") and not sheet.craft_action.disabled)
	root.get_texture().get_image().save_png("res://verify_station_salvage.png")
	print("Saved verify_station_salvage.png")
	var shards_before: int = inventory.get_count("frost_shard")
	sheet.craft_action.pressed.emit()
	await process_frame
	print("Salvaging removes the pick and pays out: ", inventory.get_count("frost_pick") == 0 and inventory.get_count("frost_shard") == shards_before + 1 and sheet.craft_action.text == "Salvaged!")
	var sword_uid: int = inventory.gear_of("bone_greatsword")[0].uid
	sheet._select_salvage_target(sword_uid)
	await process_frame
	print("A boss drop (no recipe) can't be salvaged: ", sheet.craft_action.disabled and sheet.craft_desc.text.begins_with("Nothing to reclaim") and crafting.salvage(sword_uid).is_empty() and inventory.get_count("bone_greatsword") == 1)
	print("Salvage yields never go to zero: the pickaxe (3 wood + 2 stone) gives 1 wood + 1 stone; the charm (2/2/5) gives 1/1/2: ", crafting.salvage_yield("wooden_pickaxe") == {"wood": 1, "stone": 1} and crafting.salvage_yield("charm_of_warding") == {"wood": 1, "stone": 1, "gold": 2})
	sheet.close()

	# --- Leaving the bench. ---
	player.position = bench.position + Vector2(128, 32)
	for i in range(8):
		await physics_frame
	await process_frame
	if crafting.at_station:
		print("DEBUG stations_near=", crafting._stations_near, " player=", player.position, " bench=", bench.position, " inside=", bench._player_inside)
	print("Walking away clears the station: ", not crafting.at_station)

	# --- Phone: salvage pane fits. ---
	player.position = bench.position + Vector2(0, 40)
	for i in range(8):
		await physics_frame
	root.size = Vector2i(400, 660)
	for i in range(6):
		await process_frame
	sheet.open("crafting")
	sheet._set_craft_mode("salvage")
	await process_frame
	await process_frame
	var pane: Control = sheet.craft_action
	print("Phone: Salvage mode open at the bench, action button inside the window: ", sheet.craft_mode == "salvage" and crafting.at_station and pane.get_global_rect().end.y <= sheet.window.get_global_rect().end.y + 0.5 and pane.get_global_rect().end.x <= 400.0)
	root.get_texture().get_image().save_png("res://verify_station_phone.png")
	print("Saved verify_station_phone.png")
	sheet.close()
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()
