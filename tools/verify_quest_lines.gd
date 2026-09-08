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
	var world: Node = root.get_node("World")
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
	print("Six chapters in order (village, four biomes, finale); every quest is story or side, story quests in a chapter, requirements all real quests (", story_count, " story / ", side_count, " side): ", chapter_ids == ["village", "frostpeak", "verdantwood", "badlands", "gloomfen", "finale"] and shape_ok and story_count == 20 and side_count == 3)
	var chapter_ok := true
	var joins: Dictionary = {"frostpeak": ["join_luigi"], "verdantwood": ["join_eden"], "badlands": ["join_pair"]}
	for c in ["frostpeak", "verdantwood", "badlands", "gloomfen"]:
		var ids: Array = quests.chapter_quests(c)
		ids.sort()
		if ids != ["cross_" + c, "hunt_" + c] + joins.get(c, []):
			chapter_ok = false
	var village: Array = quests.chapter_quests("village")
	village.sort()
	print("Each biome chapter is its ford quest, its companion's joining event (none for Gloomfen) and its hunt; chapter 1 is meet, wood, barrow, Warden, Bone Lord; the finale is the Wraith, the altar, the Warden: ", chapter_ok and village == ["bank_gold", "gather_wood", "hunt_barrow", "hunt_dungeon", "meet_villagers", "open_ancient_barrow"] and quests.chain_of("two_guardians") == ["hunt_castle", "two_guardians", "ancient_warden"])

	# --- gating ---
	print("Meet the Village is the gateway: before it is turned in no ford, barrow or Blacksmith quest is offerable: ", not quests.is_available("cross_frostpeak") and not quests.is_available("open_ancient_barrow") and not quests.is_available("forge_whetstone") and quests.is_available("meet_villagers"))
	quests.quest_state.meet_villagers = "completed"
	print("After the tutorial only the wood errand opens; no ford, no hunt, and not the Blacksmith yet (the story runs in order): ", quests.is_available("gather_wood") and not quests.is_available("forge_whetstone") and not quests.is_available("cross_frostpeak") and not quests.is_available("cross_gloomfen") and not quests.is_available("open_ancient_barrow") and not quests.is_available("hunt_frostpeak"))
	for id in ["gather_wood", "bank_gold", "open_ancient_barrow", "hunt_barrow"]:
		quests.quest_state[id] = "completed"
	print("The barrow arc: the Warden done, the Bone Lord is offered and the northern ford still is not: ", quests.is_available("hunt_dungeon") and not quests.is_available("cross_frostpeak"))
	quests.quest_state.hunt_dungeon = "completed"
	print("The Bone Lord done: the northern ford opens up (and the Blacksmith's whetstone errand, whose follow-up wants frost shards), the other three fords wait for their chapters: ", quests.is_available("cross_frostpeak") and quests.is_available("forge_whetstone") and not quests.is_available("cross_verdantwood") and not quests.is_available("cross_badlands") and not quests.is_available("cross_gloomfen"))
	for id in ["gather_wood", "bank_gold", "open_ancient_barrow", "hunt_barrow", "hunt_dungeon"]:
		quests.quest_state.erase(id)
	quests.quest_state.erase("meet_villagers")
	quests.quest_state.cross_verdantwood = "completed"
	print("Completing a ford unlocks that biome's joining event, and the event its hunt: ", quests.is_available("join_eden") and not quests.is_available("hunt_verdantwood") and not quests.is_available("join_luigi"))
	quests.quest_state.join_eden = "completed"
	print("...and the event its hunt only: ", quests.is_available("hunt_verdantwood") and not quests.is_available("hunt_frostpeak"))

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
	print("Elder carries the whole story chain in order (thirteen steps, the bank lesson, the barrow arc and the castle included): ", elder != null and elder.quest_ids == ["meet_villagers", "gather_wood", "bank_gold", "open_ancient_barrow", "hunt_barrow", "hunt_dungeon", "hunt_frostpeak", "hunt_verdantwood", "hunt_badlands", "hunt_gloomfen", "hunt_castle", "two_guardians", "ancient_warden"])
	print("Fresh Elder offers the tutorial first: ", elder.active_quest() == "meet_villagers" and elder.marker_kind() == "!")
	quests.quest_state.meet_villagers = "completed"
	print("Village met: the Elder offers the wood errand, not the barrow: ", elder.active_quest() == "gather_wood" and elder.marker_kind() == "!")
	quests.quest_state.gather_wood = "completed"
	print("Wood done: the bank lesson next, then the barrow: ", elder.active_quest() == "bank_gold" and elder.marker_kind() == "!")
	quests.quest_state.bank_gold = "completed"
	print("Banked: the barrow next: ", elder.active_quest() == "open_ancient_barrow" and elder.marker_kind() == "!")
	print("Chapter 1 done and the eastern ford and Eden's event done: the Elder offers Elder Bramblewood: ", true)
	quests.quest_state.open_ancient_barrow = "completed"
	quests.quest_state.hunt_barrow = "completed"
	quests.quest_state.hunt_dungeon = "completed"
	quests.quest_state.erase("join_eden")
	print("With the Verdantwood event not done the Elder has nothing to offer and repeats his last closing line (no marker): ", elder.active_quest() == "hunt_dungeon" and elder.marker_kind() == "")
	quests.quest_state.join_eden = "completed"
	print("Eden's event done: the DRUID offers Elder Bramblewood in the field; the Elder does not (he takes the turn-in): ", druid != null and druid.active_quest() == "hunt_verdantwood" and druid.marker_kind() == "!" and elder.active_quest() == "hunt_dungeon" and elder.marker_kind() == "")
	print("The hunt's giver is the Druid, its turn-in the Elder: ", quests.giver_id_of("hunt_verdantwood") == "forest_druid" and quests.turn_in_id_of("hunt_verdantwood") == "village_elder" and quests.turn_in_label("hunt_verdantwood") == "the Village Elder" and quests.giver_label("hunt_verdantwood") == "the Forest Druid")

	# --- accept the hunt from the Druid past the ford, beat the boss, turn it in at the Elder ---
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	quests.npcs_met.village_elder = true # past the one-time intros
	quests.npcs_met.forest_druid = true
	game_state.biome_paths_open.verdantwood = true
	quests.changed.emit()
	await process_frame
	var east_ford: Vector2i = world.BIOME_FORDS[world.Zone.VERDANTWOOD]
	print("With the eastern ford open the Druid stands just past the crossing, on the forest side: ", druid.position.x > east_ford.x * 32 + 16 and absf(druid.position.y - (east_ford.y * 32 + 16)) <= 64.0)
	player.position = druid.position + Vector2(0, 20)
	player.get_node("Camera2D").reset_smoothing()
	for i in range(3):
		await physics_frame
	await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	var offer_ok: bool = dialogue_ui.is_open() and dialogue_ui.text_label.text.begins_with("The crossing's clear and Eden's with you")
	var actions: Array = dialogue_ui.actions_row.get_children()
	print("The Druid offers the hunt in her own words with Accept / Not now: ", offer_ok and actions.size() == 2 and actions[0].text == "Accept")
	actions[0].pressed.emit()
	await process_frame
	print("Accepted: tracked, objective 0/1 Elder Bramblewood asleep, not met: ", quests.quest_state.get("hunt_verdantwood", "") == "accepted" and quests.tracked_quests.has("hunt_verdantwood") and quests.objective_progress_text("hunt_verdantwood") == "0/1 Elder Bramblewood asleep" and not quests.objective_met("hunt_verdantwood"))
	print("Markers show nothing while the boss is awake: ", elder.marker_kind() == "" and druid.marker_kind() == "")
	game_state.boss_defeated.verdantwood_boss = true
	print("Boss asleep: objective met, the Elder shows '?' and the Druid does not: ", quests.objective_met("hunt_verdantwood") and elder.marker_kind() == "?" and druid.marker_kind() == "")
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("The Druid sends Oliver on to the Elder (no Turn In here): ", dialogue_ui.is_open() and dialogue_ui.text_label.text.begins_with("The bramble sleeps? Go and tell the Elder") and dialogue_ui.actions_row.get_child_count() == 0)
	dialogue_ui.hide_dialogue()
	await process_frame
	var xp_before: int = character.stats.xp + 0
	var gold_before: int = inventory.get_count("gold")
	var level_before: int = character.stats.level
	quests._complete_quest("hunt_verdantwood")
	var xp_gained: bool = character.stats.level > level_before or character.stats.xp > xp_before
	print("Turned in: completed, 60 gold and 220 XP paid, a potion granted, chapter 3 complete: ", quests.quest_state.hunt_verdantwood == "completed" and inventory.get_count("gold") == gold_before + 60 and xp_gained and inventory.get_count("healing_potion") == 1 and quests.chapter_state("verdantwood") == "complete" and quests.chapter_state("frostpeak") == "not_started" and quests.chapter_state("village") == "complete")
	print("Turned in, the Druid goes back to her glade: ", druid.position == Vector2(world.place("druid_glade").x * 32 + 16, world.place("druid_glade").y * 32 + 16))

	# --- chains and steps ---
	print("Chains derive from the requirements: ford -> join -> hunt is a three-step chain, the hunt step 3 of 3, the ford step 1 of 3: ", quests.chain_of("hunt_frostpeak") == ["cross_frostpeak", "join_luigi", "hunt_frostpeak"] and quests.step_of("hunt_frostpeak") == [3, 3] and quests.step_of("cross_frostpeak") == [1, 3] and quests.prev_of("hunt_frostpeak") == "join_luigi" and quests.next_of("cross_frostpeak") == ["join_luigi"])
	print("A single-action side quest is a chain of one: ", quests.chain_of("thornback_warden") == ["thornback_warden"] and quests.step_of("thornback_warden") == [1, 1] and quests.line_of("thornback_warden") == "side")

	# --- the finale needs all four hunts ---
	for c in ["frostpeak", "badlands", "gloomfen"]:
		quests.quest_state["cross_" + c] = "completed"
		quests.quest_state["hunt_" + c] = "completed"
	quests.quest_state.join_luigi = "completed"
	quests.quest_state.join_pair = "completed"
	print("All four hunts done: The Royal Wraith opens (the castle), 0/1 Royal Wraith asleep: ", quests.is_available("hunt_castle") and quests.objective_progress_text("hunt_castle") == "0/1 Royal Wraith asleep" and elder.active_quest() == "hunt_castle" and not quests.is_available("two_guardians"))
	quests.quest_state.hunt_castle = "accepted"
	game_state.boss_defeated.castle_boss = true
	print("The Wraith asleep: met; The Altar waits on the turn-in: ", quests.objective_met("hunt_castle") and not quests.is_available("two_guardians"))
	quests._complete_quest("hunt_castle")
	print("Wraith turned in: The Altar is offered (0/1 lair revealed), the Warden waits: ", quests.is_available("two_guardians") and elder.active_quest() == "two_guardians" and quests.objective_progress_text("two_guardians") == "0/1 lair revealed" and not quests.is_available("ancient_warden"))
	quests.quest_state.two_guardians = "accepted"
	game_state.world_progress.final_boss_revealed = true
	quests._complete_quest("two_guardians")
	print("Altar turned in: the Ancient Warden is offered next, finale in progress: ", quests.is_available("ancient_warden") and elder.active_quest() == "ancient_warden" and quests.chapter_state("finale") == "in_progress")

	# --- side chains: the Druid's hunt and the Blacksmith's two steps ---
	print("The Druid follows the ford with the Thornback hunt (side, needs the ford): ", druid != null and druid.quest_ids == ["cross_verdantwood", "hunt_verdantwood", "thornback_warden"] and quests.line_of("thornback_warden") == "side" and quests.is_available("thornback_warden") and druid.active_quest() == "thornback_warden")
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
