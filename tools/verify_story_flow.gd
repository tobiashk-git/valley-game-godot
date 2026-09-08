extends SceneTree
# Story flow verification. Run via:
# godot --script res://tools/verify_story_flow.gd (NOT --headless).
#
# The storyline runs in order (2026-09-08): chapter 1 is Meet the Village,
# A Village in Need, What Lies Beneath (the Elder now), The Barrow Warden,
# The Bone Lord; each ford quest needs the previous chapter's hunt; the
# finale is The Royal Wraith, The Altar, The Ancient Warden. The dungeon
# and castle gates are barred until their hunts are handed out. Settings
# has a Story jump that starts a test at any chapter.

func _press_e() -> void:
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame

func _initialize() -> void:
	var quests: Node = root.get_node("Quests")
	var game_state: Node = root.get_node("GameState")
	var character: Node = root.get_node("Character")
	var inventory: Node = root.get_node("Inventory")
	var combat: Node = root.get_node("Combat")
	var world: Node = root.get_node("World")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	await process_frame
	game_state.reset()
	quests.reset()
	inventory.reset()
	character.reset()

	# --- the order of things ---
	var chain: Array = ["meet_villagers", "gather_wood", "open_ancient_barrow", "hunt_barrow", "hunt_dungeon", "cross_frostpeak", "join_luigi", "hunt_frostpeak", "cross_verdantwood", "join_eden", "hunt_verdantwood", "cross_badlands", "join_pair", "hunt_badlands", "cross_gloomfen", "hunt_gloomfen", "hunt_castle", "two_guardians", "ancient_warden"]
	var in_order := true
	for i in range(chain.size()):
		var id: String = chain[i]
		# Only the next quest is offerable; everything after it is not.
		if not quests.is_available(id):
			in_order = false
			print("  not available in turn: ", id)
		for later in chain.slice(i + 1):
			if quests.is_available(later):
				in_order = false
				print("  offered too early: ", later, " while ", id, " is open")
		quests.quest_state[id] = "completed"
	print("The nineteen story steps are offered one at a time, each only once the one before is turned in: ", in_order)
	print("The barrow quest is the Elder's now, in chapter 1, after the wood errand; the Trader is a shop: ", quests.QUEST_DEFS.open_ancient_barrow.giver_name == "Village Elder" and quests.chapter_of("open_ancient_barrow") == "village" and quests.requires_of("open_ancient_barrow") == ["gather_wood"] and quests.line_of("open_ancient_barrow") == "story")
	print("Chapter 1 chain: meet, wood, barrow, Barrow Warden, Bone Lord - five steps: ", quests.chain_of("hunt_dungeon") == ["meet_villagers", "gather_wood", "open_ancient_barrow", "hunt_barrow", "hunt_dungeon"])
	print("Each ford needs the previous hunt: ", quests.requires_of("cross_frostpeak") == ["hunt_dungeon"] and quests.requires_of("cross_verdantwood") == ["hunt_frostpeak"] and quests.requires_of("cross_badlands") == ["hunt_verdantwood"] and quests.requires_of("cross_gloomfen") == ["hunt_badlands"])
	print("The finale: the castle (needs the Bogmaw), then the altar (a flag objective), then the Warden: ", quests.requires_of("hunt_castle") == ["hunt_gloomfen"] and quests.QUEST_DEFS.two_guardians.objective.type == "flag" and quests.requires_of("two_guardians") == ["hunt_castle"] and quests.requires_of("ancient_warden") == ["two_guardians"])
	quests.reset()
	quests.quest_state.two_guardians = "accepted"
	var flag_before: bool = quests.objective_met("two_guardians")
	game_state.world_progress.final_boss_revealed = true
	print("The Altar step is met by the altar's reveal flag (0/1 then 1/1 lair revealed): ", not flag_before and quests.objective_met("two_guardians") and quests.objective_progress_text("two_guardians") == "1/1 lair revealed")
	game_state.world_progress.final_boss_revealed = false
	quests.reset()

	# --- the Barrow Warden and the Bone Lord ask for the leather set ---
	var enemies: Node = root.get_node("Enemies")
	print("The Barrow Warden (80 HP / 9) and the Bone Lord (105 HP / 8) are tuned for the leather set (sim --barrow): ", enemies.BOSSES.golden_plains_boss.max_hp == 80 and enemies.BOSSES.golden_plains_boss.attack == 9 and enemies.BOSSES.dungeon_boss.max_hp == 105 and enemies.BOSSES.dungeon_boss.attack == 8)

	# --- barred gates on the overworld ---
	quests.quest_state.meet_villagers = "completed"
	game_state.village_gates_open = true
	MapRecipe.active_path = "res://tools/no_such_recipe.json"
	world.reload_places()
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	for i in range(3):
		await process_frame
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var dungeon_portal: Area2D = overworld.get_node("DungeonPortal")
	var castle_portal: Area2D = overworld.get_node("CastlePortal")
	print("Both gates start barred: ", dungeon_portal.is_locked() and castle_portal.is_locked() and dungeon_portal.lock_quest == "hunt_dungeon" and castle_portal.lock_quest == "hunt_castle")
	player.position = dungeon_portal.position + Vector2(20, 0) # inside the 56 px trigger
	player.get_node("Camera2D").reset_smoothing()
	for i in range(3):
		await physics_frame
	await process_frame
	if combat.in_combat:
		combat.player_run()
		await process_frame
	await _press_e()
	print("E on the barred dungeon gate: a message that the Elder might help, no scene change: ", current_scene == overworld and dialogue_ui.is_open() and dialogue_ui.text_label.text.contains("Elder might know") and dialogue_ui.name_label.text == "Barred gate")
	dialogue_ui.hide_dialogue()
	await process_frame
	quests.quest_state.hunt_dungeon = "accepted"
	print("Once The Bone Lord is handed out the gate is open (the castle's still barred): ", not dungeon_portal.is_locked() and castle_portal.is_locked())
	await _press_e()
	await process_frame
	await process_frame
	print("...and E walks Oliver into the dungeon: ", current_scene != null and current_scene.name == "Dungeon")
	root.get_texture().get_image().save_png("res://verify_story_flow_dungeon.png")

	# --- the Story jump ---
	var ok_jump := true
	for chapter_id in StoryJump.CHAPTER_ORDER:
		if not StoryJump.apply(self, chapter_id):
			ok_jump = false
	print("Story jump knows every chapter: ", ok_jump)
	StoryJump.apply(self, "village")
	print("Jump to chapter 1: a fresh game with the intro skipped: ", quests.quest_state.is_empty() and character.stats.level == 1 and not game_state.intro_pending and inventory.get_count("gold") == 0)
	StoryJump.apply(self, "frostpeak")
	print("Jump to chapter 2: chapter 1 done, barrow + Bone Lord asleep, a crystal, level 3 in the full leather set, gates open, the dungeon unbarred: ", quests.quest_state.get("hunt_dungeon", "") == "completed" and game_state.boss_defeated.dungeon_boss and game_state.boss_defeated.golden_plains_boss and inventory.get_count("magic_crystal") == 1 and character.stats.level == 3 and character.equipped_id("legs") == "leather_greaves" and character.equipped_id("weapon") == "wooden_pickaxe" and game_state.village_gates_open and game_state.world_progress.golden_plains_revealed and quests.is_available("cross_frostpeak") and not game_state.biome_paths_open.frostpeak)
	StoryJump.apply(self, "badlands")
	print("Jump to chapter 4: Frostpeak and Verdantwood done, Eden joined (Luigi too), fords north and east open, level 8 in ironwood, the southern ford quest next: ", quests.quest_state.get("hunt_verdantwood", "") == "completed" and quests.companion_joined("join_eden") and quests.companion_joined("join_luigi") and game_state.biome_paths_open.frostpeak and game_state.biome_paths_open.verdantwood and not game_state.biome_paths_open.badlands and character.stats.level == 8 and character.equipped_id("armor") == "ironwood_mail" and quests.is_available("cross_badlands") and combat.roster_for_zone(world.Zone.VERDANTWOOD) == ["eden"])
	StoryJump.apply(self, "finale")
	print("Jump to chapter 6: all hunts done, level 12 in bog-iron, The Royal Wraith offered, the castle still barred until it is taken: ", quests.quest_state.get("hunt_gloomfen", "") == "completed" and character.stats.level == 12 and character.equipped_id("armor") == "bogiron_harness" and quests.is_available("hunt_castle") and not quests.quest_state.has("hunt_castle") and combat.roster_for_event("join_pair") == ["luigi", "eden"])
	var settings: CanvasLayer = root.get_node("SettingsPanel")
	print("Settings carries the six jump buttons in its Game section: ", settings.jump_buttons.size() == 6 and settings.jump_buttons[0].text == "1" and settings.jump_row.get_parent() == settings.game_section)
	quit()
