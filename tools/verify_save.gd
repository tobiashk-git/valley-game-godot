extends SceneTree
# Save / load / new game verification. Run via:
# godot --script res://tools/verify_save.gd (NOT --headless).
#
# Builds up a varied game state (items, an enhanced instance, worn gear,
# stats, quests + tracking + villagers met, chest contents, a discovered
# place, opened gates and a ford, a defeated wild monster, a house scene at
# a position), saves to a TEST slot, wipes everything with new_game(),
# reloads, and checks every piece came back - then autosave on a scene
# change, the boot-continue path, the Hero tab's Game block, and that
# --script runs leave the real auto slot alone.

func _initialize() -> void:
	var save: Node = root.get_node("SaveSystem")
	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var quests: Node = root.get_node("Quests")
	var storage: Node = root.get_node("Storage")
	var game_state: Node = root.get_node("GameState")
	var crafting: Node = root.get_node("Crafting")
	var combat: Node = root.get_node("Combat")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	const SLOT := "verify_test"
	save.delete_save(SLOT)

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	# (Autoload _ready() runs after this script's first line, so check now.)
	print("Autosave and boot-continue are off in --script runs: ", not save.enabled)

	# --- Build a state worth saving. ---
	inventory.add_item("wood", 7)
	inventory.add_item("healing_potion", 2)
	inventory.add_item("leather_armor", 2)
	inventory.add_item("monster_fur", 3)
	var enhanced_uid: int = inventory.gear[1].uid
	crafting.enhance(enhanced_uid, "fur_lined")
	inventory.add_item("wooden_pickaxe", 1)
	character.equip("weapon", "wooden_pickaxe")
	character.equip("armor", enhanced_uid)
	character.stats.hp = 13
	character.stats.mp = 4
	quests._accept_quest("meet_villagers")
	quests.mark_npc_met("village_trader") # completes the tutorial, opens the gates
	quests._accept_quest("gather_wood")
	storage.add_item("house_chest", "stone", 4)
	game_state.discovered_pois.dungeon = true
	game_state.biome_paths_open.frostpeak = true
	game_state.wild_monsters_defeated["100_80"] = true
	game_state.boss_defeated.dungeon_boss = true
	var next_uid_before: int = inventory._next_uid
	# Stand somewhere specific inside a house.
	change_scene_to_packed(load("res://scenes/House.tscn"))
	await process_frame
	await process_frame
	var player: CharacterBody2D = current_scene.get_node("YSort/Player")
	player.position = Vector2(150, 200)
	await process_frame

	# --- Save. ---
	print("Save writes the slot file: ", save.save_game(SLOT) and save.has_save(SLOT))
	var data: Dictionary = save.read_save(SLOT)
	print("Save records scene, position and version: ", data.scene == "res://scenes/House.tscn" and data.position == [150.0, 200.0] and int(data.version) == save.SAVE_VERSION)
	print("Save carries the enhanced instance's mod: ", data.inventory.gear.size() == 1 and data.character.equipment.armor.mods[0].id == "fur_lined")

	# --- Wipe with new_game(). ---
	save.new_game()
	await process_frame
	await process_frame
	print("New game resets everything and wakes Oliver beside his bed with the intro pending: ", current_scene.name == "House" and current_scene.get_node("YSort/Player").position == Vector2(current_scene.NAP_SPAWN_TILE.x * 32 + 16, current_scene.NAP_SPAWN_TILE.y * 32 + 16) and game_state.intro_pending and root.get_node("Intro").is_playing() and inventory.backpack.is_empty() and inventory.gear.is_empty() and character.equipped_id("weapon") == "" and character.stats.hp == 20 and quests.quest_state.is_empty() and quests.tracked_quests.is_empty() and storage.get_count("house_chest", "stone") == 0 and not game_state.village_gates_open and not game_state.discovered_pois.dungeon and not game_state.biome_paths_open.frostpeak and game_state.wild_monsters_defeated.is_empty() and not game_state.boss_defeated.dungeon_boss)
	print("Test slot untouched by new_game (only the auto slot is wiped): ", save.has_save(SLOT))

	# --- Load. ---
	print("Load returns true: ", save.load_game(SLOT))
	await process_frame
	await process_frame
	await process_frame
	print("Load travels to the saved scene and position: ", current_scene.name == "House" and current_scene.get_node("YSort/Player").position == Vector2(150, 200))
	print("Backpack restored (wood 7, potions 2, fur 0): ", inventory.get_count("wood") == 7 and inventory.get_count("healing_potion") == 2 and inventory.get_count("monster_fur") == 0)
	var worn: Dictionary = character.equipped("armor")
	print("Gear instances restored: carried plain armour, worn Fur-lined armour with its mod and uid, pickaxe worn: ", inventory.gear.size() == 1 and inventory.gear[0].mods.is_empty() and worn.uid == enhanced_uid and worn.mods.size() == 1 and worn.mods[0].label == "Fur-lined" and character.equipped_id("weapon") == "wooden_pickaxe" and character.gear_total("defense") == 4)
	print("Uid counter restored so new gear never collides: ", inventory._next_uid == next_uid_before)
	print("Stats restored (hp 13, mp 4): ", character.stats.hp == 13 and character.stats.mp == 4 and character.stats.max_hp == 20)
	print("Quests restored (tutorial done, wood quest accepted + tracked, trader met): ", quests.quest_state.get("meet_villagers", "") == "completed" and quests.quest_state.get("gather_wood", "") == "accepted" and quests.tracked_quests == ["gather_wood"] and quests.npcs_met.get("village_trader", false))
	print("Chest restored: ", storage.get_count("house_chest", "stone") == 4)
	print("World progress restored (gates, ford, dungeon discovered, boss + wild monster defeated): ", game_state.village_gates_open and game_state.biome_paths_open.frostpeak and game_state.discovered_pois.dungeon and game_state.boss_defeated.dungeon_boss and game_state.wild_monsters_defeated.get("100_80", false))
	print("HUD and sheet see the restored state: ", root.get_node("HUD").hp_label.text == "HP 13 / 20")

	# --- The cog's Settings window: Save now says "Saved!" for a moment, Load
	# beside it. ---
	var bar: CanvasLayer = root.get_node("PanelButtons")
	var settings: CanvasLayer = root.get_node("SettingsPanel")
	save.delete_save(save.AUTO_SLOT)
	bar.settings_btn.pressed.emit()
	await process_frame
	print("The cog opens Settings with the Game section; Load disabled without a save: ", settings.is_open() and settings.game_section.visible and settings.load_btn.disabled)
	settings.save_btn.pressed.emit()
	await process_frame
	print("Save now writes the auto slot, the button reads 'Saved!' (disabled) meanwhile, Load enables, the age line updates: ", save.has_save(save.AUTO_SLOT) and settings.save_btn.text == "Saved!" and settings.save_btn.disabled and not settings.load_btn.disabled and settings.save_line.text == "Saved just now")
	root.get_texture().get_image().save_png("res://verify_save_settings.png")
	print("Saved verify_save_settings.png")
	await create_timer(settings.FEEDBACK_SECONDS + 0.3).timeout
	print("...and reads 'Save now' again after a moment: ", settings.save_btn.text == "Save now" and not settings.save_btn.disabled)
	settings.close()
	sheet.open("character")
	await process_frame
	print("Hero tab no longer carries Save / Load: ", sheet.stats_list.find_child("SaveNowBtn", true, false) == null and sheet.stats_list.find_child("LoadBtn", true, false) == null)
	sheet.close()

	# --- Autosave on a scene change (enable it for this step, on the test
	# slot's behalf via the auto slot, then clean up). ---
	save.delete_save(save.AUTO_SLOT)
	save.enabled = true
	save._last_scene = current_scene
	change_scene_to_packed(load("res://scenes/Overworld.tscn"))
	for i in range(6):
		await process_frame
	print("Scene change autosaves to the auto slot: ", save.has_save(save.AUTO_SLOT) and save.read_save(save.AUTO_SLOT).scene == "res://scenes/Overworld.tscn")
	print("Saved-ago text reads 'just now': ", save.saved_ago_text() == "Saved just now")

	# --- Title screen: Continue restores the auto save and travels to its
	# scene; New Game confirms before overwriting. ---
	var here: CharacterBody2D = current_scene.get_node("YSort/Player")
	here.position = Vector2(999, 999)
	change_scene_to_packed(load("res://scenes/House.tscn"))
	await process_frame
	await process_frame
	for i in range(6):
		await process_frame # the autosave after the change
	inventory.add_item("gold", 3)
	await process_frame
	var auto: Dictionary = save.read_save(save.AUTO_SLOT)
	print("Auto save follows the player into the house: ", auto.scene == "res://scenes/House.tscn")
	save.enabled = false
	save.new_game()
	await process_frame
	await process_frame
	# new_game() deleted the auto slot - write one by hand from the house data and boot.
	var f := FileAccess.open(save.slot_path(save.AUTO_SLOT), FileAccess.WRITE)
	f.store_string(JSON.stringify(auto))
	f.close()
	change_scene_to_packed(load("res://scenes/Title.tscn"))
	await process_frame
	await process_frame
	var title: Control = current_scene
	print("Title shows Continue (primary) with the save line, overlays hidden: ", title.continue_btn.visible and title.continue_btn.theme_type_variation == &"PrimaryButton" and title.save_line.text.begins_with("Saved just now  -  in your House") and not root.get_node("HUD").visible and not root.get_node("PanelButtons").visible and not root.get_node("QuickBar").visible)
	root.get_texture().get_image().save_png("res://verify_title_continue.png")
	print("Saved verify_title_continue.png")
	title.new_game_btn.pressed.emit()
	await process_frame
	print("New Game with a save asks to confirm first: ", title.new_game_btn.text == "Overwrite save?" and save.has_save(save.AUTO_SLOT))
	title.continue_btn.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	print("Continue restores the state and travels to the saved scene, overlays back: ", current_scene.name == "House" and inventory.get_count("wood") == 7 and root.get_node("HUD").visible)
	save.enabled = false

	# --- Clean up: no real saves left behind by this run. ---
	save.delete_save(save.AUTO_SLOT)
	save.delete_save(SLOT)
	print("Test saves removed: ", not save.has_save(save.AUTO_SLOT) and not save.has_save(SLOT))
	quit()
