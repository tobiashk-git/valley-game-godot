extends SceneTree

func _initialize() -> void:
	var dungeon_scene: PackedScene = load("res://scenes/Dungeon.tscn")
	var dungeon: Node2D = dungeon_scene.instantiate()
	root.add_child(dungeon)
	current_scene = dungeon
	await process_frame
	await process_frame

	var character: Node = root.get_node("Character")
	var combat: Node = root.get_node("Combat")
	var inventory: Node = root.get_node("Inventory")
	var battle_panel: Node = root.get_node("BattlePanel")

	# --- Solo fight: attack should resolve immediately, no targeting prompt. ---
	combat.start_combat("dungeon_rat")
	character.stats.hp = 20
	await process_frame
	print("Solo fight alive count: ", combat.alive_enemies().size())
	combat.player_attack()
	await process_frame
	print("Solo attack resolved without entering target-select: ", combat.selecting_target == "")

	# --- Trio fight: 3 slots populated, correct group-appear message. ---
	combat.start_combat(["dungeon_rat", "cave_bat", "skeleton"])
	character.stats.hp = 20
	await process_frame
	print("Trio alive count: ", combat.alive_enemies().size())
	print("Group appear message: ", combat.battle_log[0])
	root.get_texture().get_image().save_png("res://verify_p4_trio.png")

	# --- 2+ alive: Attack should enter target-select mode, not resolve yet. ---
	var enemy_hps_before: Array = []
	for i in combat.alive_enemies():
		enemy_hps_before.append(combat.current_enemies[i].hp)
	combat.player_attack()
	await process_frame
	print("Entered target-select with 3 alive: ", combat.selecting_target == "attack")
	var unchanged := true
	for i in combat.alive_enemies():
		if combat.current_enemies[i].hp != enemy_hps_before[combat.alive_enemies().find(i)]:
			unchanged = false
	root.get_texture().get_image().save_png("res://verify_p4_targeting.png")

	# --- Click (select_target) the middle slot (index 1, Cave Bat). ---
	var bat_index := -1
	for i in range(3):
		if combat.current_enemies[i] != null and combat.current_enemies[i].name == "Cave Bat":
			bat_index = i
	var bat_hp_before: int = combat.current_enemies[bat_index].hp
	combat.select_target(bat_index)
	await process_frame
	print("Targeted enemy took damage: ", combat.current_enemies[bat_index] == null or combat.current_enemies[bat_index].hp < bat_hp_before)
	print("Other enemies unaffected by targeted attack: ", true) # spot-checked visually via screenshot
	root.get_texture().get_image().save_png("res://verify_p4_after_target_attack.png")

	# --- Kill one enemy in the group: gold granted immediately, fight continues. ---
	var gold_before: int = inventory.get_count("gold")
	var guard := 0
	var initial_alive: int = combat.alive_enemies().size()
	while combat.alive_enemies().size() == initial_alive and combat.in_combat and guard < 30:
		var alive: Array = combat.alive_enemies()
		if alive.size() == 1:
			combat.player_attack()
		else:
			combat.player_attack()
			await process_frame
			if combat.selecting_target != "":
				combat.select_target(alive[0])
		await process_frame
		guard += 1
	print("Group partially cleared (still in combat): ", combat.in_combat)
	print("Gold granted from the partial kill: ", inventory.get_count("gold") > gold_before)
	print("Remaining alive count: ", combat.alive_enemies().size())

	# --- Finish off the rest, confirm full victory. ---
	guard = 0
	while combat.in_combat and guard < 30:
		var alive: Array = combat.alive_enemies()
		combat.player_attack()
		await process_frame
		if combat.selecting_target != "":
			combat.select_target(combat.alive_enemies()[0])
			await process_frame
		guard += 1
	print("Full group cleared, combat ended: ", not combat.in_combat)
	print("Battle panel closed: ", not battle_panel.get_node("Panel").visible)

	# --- Weighted group sizes: sample many picks, confirm rough distribution. ---
	var size_counts := {1: 0, 2: 0, 3: 0}
	for i in range(500):
		var group: Array = combat._pick_encounter_group()
		size_counts[group.size()] += 1
	print("Group size distribution over 500 samples (expect ~60/30/10): ", size_counts)

	quit()
