extends SceneTree
# Enemy strike cues verification. Run via:
# godot --script res://tools/verify_strike_cues.gd (NOT --headless).
#
# In a fight with several enemies, Combat announces which one is acting
# (enemy_turn_started on the wind-up, enemy_struck on the blow, in slot
# order, one at a time) and the battle panel leans that figure in, then
# shakes and flashes it, leaving the others still.

func _initialize() -> void:
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var panel: Node = root.get_node("BattlePanel")
	await process_frame
	root.get_node("GameState").reset()
	root.get_node("Inventory").reset()
	character.reset()
	var house: Node2D = load("res://scenes/House.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in range(3):
		await process_frame
	character.stats.max_hp = 500
	character.stats.hp = 500
	character.stats.agility = 5 # no dodge: every strike lands

	var starts: Array = []
	var strikes: Array = []
	combat.enemy_turn_started.connect(func(i: int) -> void: starts.append(i))
	combat.enemy_struck.connect(func(i: int) -> void: strikes.append(i))

	# Real-time beats so the cues can be watched mid-turn.
	combat.fast = false
	combat.start_combat(["bandit", "bandit", "bandit"])
	await process_frame
	await process_frame
	print("Three bandits on stage, nobody acting yet: ", combat.in_combat and combat.current_enemies.size() == 3 and panel.acting_index == -1)
	combat.player_defend() # hands the turn to the enemies (a coroutine; the beats run in real time)
	# Oliver's own beat plays first; catch the first wind-up mid-flight.
	var waited0 := 0.0
	while starts.is_empty() and waited0 < 5.0:
		await create_timer(0.02).timeout
		waited0 += 0.02
	await create_timer(0.22).timeout
	var s0: TextureRect = panel.enemy_slots[0].get_node("Box/Sprite")
	var s1: TextureRect = panel.enemy_slots[1].get_node("Box/Sprite")
	var s2: TextureRect = panel.enemy_slots[2].get_node("Box/Sprite")
	print("First bandit winds up: it leans in (scaled up), the other two stay still: ", starts == [0] and panel.acting_index == 0 and s0.scale.x > 1.05 and s1.scale == Vector2.ONE and s2.scale == Vector2.ONE and s1.rotation == 0.0)
	root.get_texture().get_image().save_png("res://verify_strike_windup.png")
	# Wait for its blow, then look during the shake.
	var waited := 0.0
	while strikes.is_empty() and waited < 4.0:
		await create_timer(0.02).timeout
		waited += 0.02
	await create_timer(0.1).timeout
	print("Its blow: the striking figure shakes (the shake tween runs, rotation moved) and flashes bright, the others untouched: ", strikes == [0] and panel.last_struck == 0 and panel._act_tween.is_running() and s0.rotation != 0.0 and s0.self_modulate.r > 1.2 and s1.rotation == 0.0 and s2.rotation == 0.0 and s1.self_modulate == Color.WHITE)
	root.get_texture().get_image().save_png("res://verify_strike_blow.png")
	# Let the whole enemy turn play out.
	waited = 0.0
	while (strikes.size() < 3 or combat.playing) and waited < 12.0:
		await create_timer(0.05).timeout
		waited += 0.05
	await create_timer(0.6).timeout
	print("All three struck in slot order, one at a time, and everything settles back to rest: ", starts == [0, 1, 2] and strikes == [0, 1, 2] and s0.scale == Vector2.ONE and s2.rotation == 0.0 and s2.self_modulate == Color.WHITE and panel.acting_index == -1)
	combat.fast = true
	combat.player_run()
	await process_frame
	quit()
