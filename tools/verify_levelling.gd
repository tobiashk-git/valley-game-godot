extends SceneTree
# Levelling verification. Run via:
# godot --script res://tools/verify_levelling.gd (NOT --headless).
#
# XP per enemy from its stats (bosses double), gain_xp levels up with the
# stat gains and a full heal (several levels at once too), a won fight pays
# XP into the battle log and a level-up is announced there and over the
# HUD, agility above base makes enemies miss, the sheet's Hero tab shows
# level / XP / next-level rows, saves keep level and XP and an old save
# without them starts at level 1.

func _initialize() -> void:
	var character: Node = root.get_node("Character")
	var combat: Node = root.get_node("Combat")
	var enemies: Node = root.get_node("Enemies")
	var save: Node = root.get_node("SaveSystem")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	var hud: CanvasLayer = root.get_node("HUD")
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	character.reset()

	# --- Formulas. ---
	var rat: Dictionary = enemies.ENEMIES.dungeon_rat
	print("A Dungeon Rat (12 HP, ATK 4, DEF 0) is worth 10 XP; a Skeleton (18/6/2) 19; a boss pays double: ", enemies.xp_for(rat) == 10 and enemies.xp_for(enemies.ENEMIES.skeleton) == 19 and enemies.xp_for(enemies.BOSSES.dungeon_boss, true) == 2 * enemies.xp_for(enemies.BOSSES.dungeon_boss))
	print("Level costs: 60 XP to reach 2, 120 to reach 3, 180 to reach 4: ", character.xp_to_next(1) == 60 and character.xp_to_next(2) == 120 and character.xp_to_next(3) == 180)

	# --- gain_xp. ---
	character.stats.hp = 7
	character.stats.mp = 2
	var gained: int = character.gain_xp(9)
	print("9 XP at level 1: no level yet, xp 9/60, HP untouched: ", gained == 0 and character.stats.level == 1 and character.stats.xp == 9 and character.stats.hp == 7)
	var levelled: Array = []
	character.levelled_up.connect(func(l: int) -> void: levelled.append(l))
	gained = character.gain_xp(51)
	print("Reaching 60 XP -> level 2: +4 max HP (24), +2 max MP (12), +1 STR (6), +1 AGI (6, even level), current HP/MP up by the same +4/+2 (11/4) - NOT a full heal, xp back to 0, signal fired: ", gained == 1 and character.stats.level == 2 and character.stats.max_hp == 24 and character.stats.max_mp == 12 and character.stats.strength == 6 and character.stats.agility == 6 and character.stats.hp == 11 and character.stats.mp == 4 and character.stats.xp == 0 and levelled == [2])
	gained = character.gain_xp(120 + 180 + 5)
	print("A big payout climbs two levels at once (2 -> 4), leftover 5 XP, AGI +1 only on the even level (7): ", gained == 2 and character.stats.level == 4 and character.stats.xp == 5 and character.stats.strength == 8 and character.stats.agility == 7 and character.stats.max_hp == 32)
	print("Level-up text names the gains; AGI only on even levels: ", character.level_up_text(3) == "+4 HP, +2 MP, +1 STR" and character.level_up_text(4) == "+4 HP, +2 MP, +1 STR, +1 AGI")
	print("Dodge: 0% at base agility, 2% per point above it, capped at 30%: ", character.dodge_chance() == 0.04 and _dodge_at(character, 5) == 0.0 and _dodge_at(character, 40) == 0.3)
	character.stats.agility = 7

	# --- In a fight: XP in the log, level-up announced. ---
	character.reset()
	character.stats.xp = 55 # one rat (10 XP) away from level 2
	combat.start_combat(["dungeon_rat"])
	await process_frame
	while combat.in_combat:
		character.stats.hp = 500
		for i in range(combat.current_enemies.size()):
			if combat.current_enemies[i] != null:
				combat.current_enemies[i].hp = 1
		combat.player_attack()
		if combat.selecting_target != "":
			combat.select_target(0)
		await process_frame
	await process_frame
	var xp_line := false
	var level_line := false
	for line in combat.battle_log:
		if line.contains("+10 XP."):
			xp_line = true
		if line.begins_with("Level up! Oliver is now level 2 (+4 HP, +2 MP, +1 STR, +1 AGI)."):
			level_line = true
	print("Winning logs '+10 XP.' on the doze-off line and the level-up with its gains: ", xp_line and level_line and character.stats.level == 2 and character.stats.xp == 5)
	var popup := false
	for child in hud.get_children():
		if child is Label and child.has_meta("popup") and child.text == "Level 2!":
			popup = true
	print("HUD floats a 'Level 2!' popup: ", popup)
	# In play the level-up's full heal spawns a heal number at the same
	# moment: simultaneous popups stack upwards instead of overlapping.
	hud._spawn_popup(12)
	hud._spawn_text_popup("Level 9!", Color.YELLOW)
	var ys: Array = []
	for child in hud.get_children():
		if child is Label and child.has_meta("popup"):
			ys.append(child.position.y)
	ys.sort()
	var spaced: bool = ys.size() >= 2
	for i in range(1, ys.size()):
		if ys[i] - ys[i - 1] < 20.0:
			spaced = false
	print("Popups that spawn together stack 24px apart (%s): " % str(ys), spaced)
	root.get_texture().get_image().save_png("res://verify_levelling_levelup.png")
	print("Saved verify_levelling_levelup.png")

	# --- Dodging: with agility maxed every attack misses. ---
	character.stats.agility = 100
	character.stats.hp = character.stats.max_hp
	combat.start_combat(["skeleton"])
	await process_frame
	# 40 defends with HP topped up each turn: a dodged turn leaves HP at 500
	# and its log line says so. P(no dodge in 40 at 30%) ~ 6e-7.
	var dodged := 0
	var logged := true
	for i in range(40):
		character.stats.hp = 500
		combat.player_defend()
		await process_frame
		if character.stats.hp == 500:
			dodged += 1
			var seen := false
			for line in combat.battle_log:
				if line.contains("Oliver dodges!"):
					seen = true
			if not seen:
				logged = false
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	print("Agility 100 (30%% cap) dodges some of 40 attacks, each logged (%d dodged): " % dodged, dodged >= 3 and dodged <= 25 and logged)
	character.stats.agility = 7

	# --- Sheet: level and XP rows, header line. ---
	sheet.open("character")
	await process_frame
	await process_frame
	var titles: Array = []
	var rows: Dictionary = {}
	for child in sheet.stats_list.get_children():
		if child is Label:
			titles.append(child.text)
		elif child is HBoxContainer and child.get_child_count() == 2 and child.get_child(0) is Label and child.get_child(1) is Label: # skip the Music/Sounds slider rows
			rows[child.get_child(0).text] = child.get_child(1).text
	print("Hero tab: 'Level 2' section with Experience 5 / 120 and Next level in 115 XP; header says level 2: ", titles.has("Level 2") and rows.get("Experience", "") == "5 / 120" and rows.get("Next level in", "") == "115 XP" and sheet.location_label.text.begins_with("Level 2 adventurer"))
	print("Agility row shows the dodge chance once it's above base: ", rows.get("Agility", "").begins_with("7") and rows.get("Agility", "").contains("dodge 4%"))
	root.get_texture().get_image().save_png("res://verify_levelling_sheet.png")
	print("Saved verify_levelling_sheet.png")
	sheet.close()

	# --- Saves. ---
	var snap: Dictionary = save.snapshot()
	print("Snapshot carries level and xp: ", int(snap.character.stats.level) == 2 and int(snap.character.stats.xp) == 5)
	character.stats.level = 9
	character.stats.xp = 99
	save.apply(snap)
	print("Applying it restores level 2, 5 XP: ", character.stats.level == 2 and character.stats.xp == 5)
	snap.character.stats.erase("level")
	snap.character.stats.erase("xp")
	character.stats.level = 9
	save.apply(snap)
	print("An older save without level/xp starts at level 1, 0 XP (not the previous game's level): ", character.stats.level == 1 and character.stats.xp == 0)
	character.reset()
	print("reset() returns to level 1, 0 XP, base stats: ", character.stats.level == 1 and character.stats.xp == 0 and character.stats.max_hp == 20 and character.stats.agility == 5)

	# --- Phone: the Hero tab still fits with the new rows. ---
	root.size = Vector2i(400, 660)
	for i in range(6):
		await process_frame
	sheet.open("character")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://verify_levelling_phone.png")
	print("Saved verify_levelling_phone.png")
	sheet.close()
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()

func _dodge_at(character: Node, agility: int) -> float:
	var keep: int = character.stats.agility
	character.stats.agility = agility
	var d: float = character.dodge_chance()
	character.stats.agility = keep
	return d
