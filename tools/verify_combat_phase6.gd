extends SceneTree
# Bone Lord (60 HP, attack 8) is a genuine threat to an unequipped 20-HP
# Oliver - a straightforward attack loop can lose. The victory-path test
# below deliberately boosts HP first (isolating "does the boss mechanic
# work" from "is this a fair fight at Oliver's current gear level", the
# latter being a balance question flagged for real playtesting later, same
# as the JS reference's own boss stats). Flee/defeat are tested separately,
# same isolation pattern every earlier phase's regression script already uses.

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
	var game_state: Node = root.get_node("GameState")
	var items: Node = root.get_node("Items")
	var player: CharacterBody2D = dungeon.get_node("YSort/Player")
	var boss: StaticBody2D = dungeon.get_node("YSort/Boss")

	print("Boss node found in Dungeon scene: ", boss != null)
	print("Boss starts undefeated: ", not game_state.boss_defeated.dungeon_boss)
	print("Boss sprite tint alive (purple): ", boss.get_node("Sprite2D").modulate == boss.ALIVE_TINT)

	# --- Real interaction path: walk up to the boss and press E. ---
	# Being dropped onto the boss's collision pushes the player out, which
	# counts as steps and could roll a random encounter first - suppress.
	combat._steps_since_encounter = -100000
	player.position = boss.position + Vector2(0, 20)
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Combat started via walk-up + E: ", combat.in_combat)
	print("current_boss_id set to dungeon_boss: ", combat.current_boss_id == "dungeon_boss")
	print("Boss enemy shown: ", combat.current_enemies[0].name, " hp=", combat.current_enemies[0].hp, "/", combat.current_enemies[0].max_hp)
	root.get_texture().get_image().save_png("res://verify_p6_boss_fight.png")

	var pos_before: Vector2 = player.position
	Input.action_press("move_right")
	await process_frame
	await process_frame
	Input.action_release("move_right")
	print("Player didn't move during boss fight: ", player.position == pos_before)

	# --- Victory path (HP boosted so the fight can't be lost mid-test). ---
	character.stats.max_hp = 500
	character.stats.hp = 500
	character.stats.mp = 999
	var gold_before: int = inventory.get_count("gold")
	var guard := 0
	while combat.in_combat and guard < 40:
		combat.cast_spell("fireball")
		await process_frame
		guard += 1
	print("Boss fight ended in victory (", guard, " actions): ", not combat.in_combat)
	print("Boss checkpoint now marked defeated: ", game_state.boss_defeated.dungeon_boss)
	print("Gold granted: ", inventory.get_count("gold") > gold_before)
	print("Bone Greatsword obtained: ", inventory.get_count("bone_greatsword") == 1)
	print("Bone Greatsword stat suffix: ", items.describe_stats("bone_greatsword"))
	character.equip("weapon", "bone_greatsword")
	print("Equipping Bone Greatsword works: ", character.equipped_id("weapon") == "bone_greatsword")
	await process_frame
	print("Boss sprite dims after defeat: ", boss.get_node("Sprite2D").modulate == boss.DEFEATED_TINT)
	root.get_texture().get_image().save_png("res://verify_p6_boss_defeated.png")

	# --- Defeated boss ignores the real E-press path (no re-fight). ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Pressing E on a defeated boss does nothing: ", not combat.in_combat)

	# --- Flee: reset the checkpoint to test the fresh-fight path, confirm
	# fleeing leaves it undefeated. ---
	game_state.boss_defeated.dungeon_boss = false
	combat.start_boss_fight("dungeon_boss")
	await process_frame
	combat.player_run()
	await process_frame
	print("Fleeing a boss leaves it undefeated: ", not game_state.boss_defeated.dungeon_boss)
	print("current_boss_id cleared after fleeing: ", combat.current_boss_id == "")

	# --- Defeat: force a loss, confirm it leaves the boss undefeated too. ---
	combat.start_boss_fight("dungeon_boss")
	character.stats.hp = 1
	await process_frame
	combat.player_defend() # any action triggers enemy retaliation
	await process_frame
	await process_frame
	print("Scene after defeat: ", current_scene.name)
	print("Losing to a boss leaves it undefeated: ", not game_state.boss_defeated.dungeon_boss)
	print("current_boss_id cleared after defeat: ", combat.current_boss_id == "")

	# --- Random encounters never roll a boss (structural - BOSSES is a
	# separate dict pick_random_id() never reads - sampled here for
	# explicit confirmation). ---
	var enemies: Node = root.get_node("Enemies")
	var saw_boss := false
	for i in range(300):
		if enemies.pick_random_id() == "dungeon_boss":
			saw_boss = true
	print("Random encounter pool never includes the boss: ", not saw_boss)

	quit()
