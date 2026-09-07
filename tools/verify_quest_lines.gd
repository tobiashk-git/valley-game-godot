extends SceneTree
# Quest lines verification (revamp phase 1: data + logic). Run via:
# godot --script res://tools/verify_quest_lines.gd (NOT --headless).
#
# Every quest sits on the story or side line; story quests belong to one of
# the ordered chapters; a quest with requirements is only offered once they
# are completed (the Elder skips locked chapters, so biomes come in any
# order); the defeat-a-boss objective reads GameState.boss_defeated; chains
# and steps are derived from the requirements; the finale needs all four
# hunts; the Blacksmith hands out a two-step side chain.

func _initialize() -> void:
	var quests: Node = root.get_node("Quests")
	var game_state: Node = root.get_node("GameState")
	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	await process_frame
	game_state.reset()
	inventory.reset()
	character.reset()
	quests.reset()

	# --- data shape ---
	var chapter_ids: Array = quests.CHAPTERS.map(func(c): return c.id)
	var shape_ok := true
	var story_count := 0
	var side_count := 0
	for id in quests.QUEST_DEFS.keys():
		var line: String = quests.line_of(id)
		if line == "story":
			story_count += 1
			if not chapter_ids.has(quests.chapter_of(id)):
				shape_ok = false
		elif line == "side":
			side_count += 1
		else:
			shape_ok = false
		for req in quests.requires_of(id):
			if not quests.QUEST_DEFS.has(req):
				shape_ok = false
	print("Six chapters in order (village, four biomes, finale); every quest is story or side, story quests in a chapter, requirements all real quests (", story_count, " story / ", side_count, " side): ", chapter_ids == ["village", "frostpeak", "verdantwood", "badlands", "gloomfen", "finale"] and shape_ok and story_count == 12 and side_count == 4)
	var chapter_ok := true
	for c in ["frostpeak", "verdantwood", "badlands", "gloomfen"]:
		var ids: Array = quests.chapter_quests(c)
		ids.sort()
		if ids != ["cross_" + c, "hunt_" + c]:
			chapter_ok = false
	print("Each biome chapter is its ford quest then its hunt; the finale is the Guardians then the Warden: ", chapter_ok and quests.chapter_quests("finale").size() == 2 and quests.chain_of("two_guardians") == ["two_guardians", "ancient_warden"])

	# --- gating ---
	print("At a fresh start the fords are open in any order (all four ford quests offerable) but no hunt is: ", quests.is_available("cross_frostpeak") and quests.is_available("cross_gloomfen") and not quests.is_available("hunt_frostpeak") and not quests.is_available("hunt_gloomfen") and not quests.is_available("two_guardians"))
	quests.quest_state.cross_verdantwood = "completed"
	print("Completing a ford unlocks that biome's hunt only: ", quests.is_available("hunt_verdantwood") and not quests.is_available("hunt_frostpeak"))

	# --- the Elder skips locked chapters ---
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	for i in range(3):
		await process_frame
	var elder: Node = null
	var druid: Node = null
	for child in overworld.get_node("YSort").get_children():
		if child.get("npc_name") == "Village Elder":
			elder = child
		elif child.get("npc_name") == "Forest Druid":
			druid = child
	print("Elder carries the story chain in chapter order: ", elder != null and elder.quest_ids == ["meet_villagers", "gather_wood", "hunt_frostpeak", "hunt_verdantwood", "hunt_badlands", "hunt_gloomfen", "two_guardians", "ancient_warden"])
	print("Fresh Elder offers the tutorial first: ", elder.active_quest() == "meet_villagers" and elder.marker_kind() == "!")
	quests.quest_state.meet_villagers = "completed"
	quests.quest_state.gather_wood = "completed"
	print("Village done, Verdantwood ford open, Frostpeak not: the Elder skips chapter 2 and offers Elder Bramblewood: ", elder.active_quest() == "hunt_verdantwood" and elder.marker_kind() == "!")
	quests.quest_state.erase("cross_verdantwood")
	print("With no chapter unlocked he has nothing to offer and repeats the last closing line (no marker): ", elder.active_quest() == "gather_wood" and elder.marker_kind() == "")
	quests.quest_state.cross_verdantwood = "completed"

	# --- accept a hunt through the Elder's dialogue, then beat the boss ---
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	quests.npcs_met.village_elder = true # past the one-time intro
	player.position = elder.position + Vector2(0, 20)
	for i in range(3):
		await physics_frame
	await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	var offer_ok: bool = dialogue_ui.is_open() and dialogue_ui.text_label.text.begins_with("With the eastern crossing clear")
	var actions: Array = dialogue_ui.actions_row.get_children()
	print("The Elder offers the hunt in his own words with Accept / Not now: ", offer_ok and actions.size() == 2 and actions[0].text == "Accept")
	actions[0].pressed.emit()
	await process_frame
	print("Accepted: tracked, objective 0/1 Elder Bramblewood asleep, not met: ", quests.quest_state.get("hunt_verdantwood", "") == "accepted" and quests.tracked_quests.has("hunt_verdantwood") and quests.objective_progress_text("hunt_verdantwood") == "0/1 Elder Bramblewood asleep" and not quests.objective_met("hunt_verdantwood"))
	print("Marker shows nothing while the boss is awake: ", elder.marker_kind() == "")
	game_state.boss_defeated.verdantwood_boss = true
	print("Boss asleep: objective met, Elder shows '?': ", quests.objective_met("hunt_verdantwood") and elder.marker_kind() == "?")
	var xp_before: int = character.stats.xp + 0
	var gold_before: int = inventory.get_count("gold")
	var level_before: int = character.stats.level
	quests._complete_quest("hunt_verdantwood")
	var xp_gained: bool = character.stats.level > level_before or character.stats.xp > xp_before
	print("Turned in: completed, 60 gold and 220 XP paid, a potion granted, chapter 3 complete: ", quests.quest_state.hunt_verdantwood == "completed" and inventory.get_count("gold") == gold_before + 60 and xp_gained and inventory.get_count("healing_potion") == 1 and quests.chapter_state("verdantwood") == "complete" and quests.chapter_state("frostpeak") == "not_started")

	# --- chains and steps ---
	print("Chains derive from the requirements: ford -> hunt is a two-step chain, the hunt is step 2 of 2, a ford step 1 of 2: ", quests.chain_of("hunt_frostpeak") == ["cross_frostpeak", "hunt_frostpeak"] and quests.step_of("hunt_frostpeak") == [2, 2] and quests.step_of("cross_frostpeak") == [1, 2] and quests.prev_of("hunt_frostpeak") == "cross_frostpeak" and quests.next_of("cross_frostpeak") == ["hunt_frostpeak"])
	print("A single-action side quest is a chain of one: ", quests.chain_of("open_ancient_barrow") == ["open_ancient_barrow"] and quests.step_of("open_ancient_barrow") == [1, 1] and quests.line_of("open_ancient_barrow") == "side")

	# --- the finale needs all four hunts ---
	for c in ["frostpeak", "badlands", "gloomfen"]:
		quests.quest_state["cross_" + c] = "completed"
		quests.quest_state["hunt_" + c] = "completed"
	print("All four hunts done: the Guardians quest opens, 0/2 Guardians asleep: ", quests.is_available("two_guardians") and quests.objective_progress_text("two_guardians") == "0/2 Guardians asleep" and elder.active_quest() == "two_guardians")
	quests.quest_state.two_guardians = "accepted"
	game_state.boss_defeated.dungeon_boss = true
	print("One Guardian asleep: 1/2, not met: ", quests.objective_progress_text("two_guardians") == "1/2 Guardians asleep" and not quests.objective_met("two_guardians"))
	game_state.boss_defeated.castle_boss = true
	print("Both asleep: met; the Warden quest waits on it: ", quests.objective_met("two_guardians") and not quests.is_available("ancient_warden"))
	quests._complete_quest("two_guardians")
	print("Guardians turned in: the Ancient Warden is offered next, finale in progress: ", quests.is_available("ancient_warden") and elder.active_quest() == "ancient_warden" and quests.chapter_state("finale") == "in_progress")

	# --- side chains: the Druid's hunt and the Blacksmith's two steps ---
	print("The Druid follows the ford with the Thornback hunt (side, needs the ford): ", druid != null and druid.quest_ids == ["cross_verdantwood", "thornback_warden"] and quests.line_of("thornback_warden") == "side" and quests.is_available("thornback_warden") and druid.active_quest() == "thornback_warden")
	overworld.queue_free()
	await process_frame
	var smithy: Node2D = load("res://scenes/BlacksmithHouse.tscn").instantiate()
	root.add_child(smithy)
	current_scene = smithy
	for i in range(3):
		await process_frame
	var smith: Node = null
	for child in smithy.get_node("YSort").get_children():
		if child.get("npc_name") == "Village Blacksmith":
			smith = child
	print("The Blacksmith hands out A Keen Edge then Cold Iron (a two-step side chain, step 2 locked until step 1 is turned in): ", smith != null and smith.quest_ids == ["forge_whetstone", "forge_frost"] and smith.active_quest() == "forge_whetstone" and quests.chain_of("forge_frost") == ["forge_whetstone", "forge_frost"] and quests.step_of("forge_frost") == [2, 2] and not quests.is_available("forge_frost"))
	quests.quest_state.forge_whetstone = "completed"
	print("Whetstone done: the Blacksmith offers Cold Iron: ", quests.is_available("forge_frost") and smith.active_quest() == "forge_frost" and smith.marker_kind() == "!")
	quit()
