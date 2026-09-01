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
	var player: CharacterBody2D = dungeon.get_node("YSort/Player")

	# --- Force a fight and confirm the panel opens correctly. ---
	combat.start_combat("dungeon_rat")
	await process_frame
	print("In combat: ", combat.in_combat)
	print("Battle panel visible: ", battle_panel.get_node("Panel").visible)
	print("Enemy: ", combat.current_enemy.name, " hp=", combat.current_enemy.hp, "/", combat.current_enemy.max_hp)
	root.get_texture().get_image().save_png("res://verify_combat_open.png")

	# --- Movement should be frozen while in combat. ---
	var pos_before: Vector2 = player.position
	Input.action_press("move_right")
	await process_frame
	await process_frame
	Input.action_release("move_right")
	print("Player moved while in combat (should be false): ", player.position != pos_before)

	# --- Defend: enemy retaliation should be logged. ---
	var hp_before_defend: int = character.stats.hp
	combat.player_defend()
	await process_frame
	print("Defend logged: ", combat.battle_log[-1])
	print("HP after defend-retaliation: ", character.stats.hp, " (was ", hp_before_defend, ")")

	# --- Cast Spell: MP should drop by 3, enemy HP should drop. ---
	var enemy_hp_before_spell: int = combat.current_enemy.hp
	var mp_before_spell: int = character.stats.mp
	combat.player_cast_spell()
	await process_frame
	print("MP after spell: ", character.stats.mp, " (was ", mp_before_spell, ")")
	print("Enemy HP after spell: ", combat.current_enemy.hp, " (was ", enemy_hp_before_spell, ")")
	root.get_texture().get_image().save_png("res://verify_combat_midfight.png")

	# --- Attack until victory. ---
	var gold_before: int = inventory.get_count("gold")
	var guard := 0
	while combat.in_combat and guard < 30:
		combat.player_attack()
		await process_frame
		guard += 1
	print("In combat after attack loop: ", combat.in_combat, " (", guard, " attacks)")
	print("Gold after victory: ", inventory.get_count("gold"), " (was ", gold_before, ")")
	print("Battle panel visible after victory: ", battle_panel.get_node("Panel").visible)
	root.get_texture().get_image().save_png("res://verify_combat_victory.png")

	# --- Run: should end combat immediately with no reward. ---
	combat.start_combat("cave_bat")
	await process_frame
	var gold_before_run: int = inventory.get_count("gold")
	combat.player_run()
	await process_frame
	print("In combat after run: ", combat.in_combat)
	print("Gold unchanged after run: ", inventory.get_count("gold") == gold_before_run)

	# --- Defeat: drive HP to 0 via a tough enemy, confirm respawn-at-house. ---
	combat.start_combat("skeleton")
	character.stats.hp = 1
	await process_frame
	combat.player_defend() # any action triggers enemy retaliation
	await process_frame
	await process_frame
	print("Scene after defeat: ", current_scene.name)
	print("HP restored after defeat: ", character.stats.hp, "/", character.stats.max_hp)
	print("In combat after defeat: ", combat.in_combat)

	# --- Random encounter wiring: repeated calls should eventually trigger. ---
	var triggered := false
	for i in range(100):
		if combat.in_combat:
			combat.player_run()
		combat.check_random_encounter()
		if combat.in_combat:
			triggered = true
	print("Random encounter triggered over 100 calls: ", triggered)

	quit()
