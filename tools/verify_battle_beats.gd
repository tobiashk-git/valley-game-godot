extends SceneTree
# Battle beats verification. Run via:
# godot --script res://tools/verify_battle_beats.gd --log-file res://verify_log.txt (NOT --headless).
#
# With beats switched on (Combat.fast = false, as in play): a Defend hides
# the commands and plays the sequence one message at a time - "braces",
# then the enemy's "prepares to strike..." wind-up (HP untouched), then the
# hit (HP drops as the message shows) - each beat holding for its time;
# a tap on the message / E hurries it; the commands return once the
# sequence has ended; the current beat is drawn big above the dimmed
# earlier lines; the phone layout still fits.

func _initialize() -> void:
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var battle: CanvasLayer = root.get_node("BattlePanel")
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	character.reset()
	character.stats.max_hp = 200
	character.stats.hp = 200
	print("Under a verify script beats are instant by default: ", combat.fast)
	combat.fast = false

	combat.start_combat(["bandit"]) # no status attack: the sequence is always exactly three beats
	await process_frame
	print("Fight open, commands shown, nothing playing: ", battle.panel.visible and battle.commands.visible and not combat.playing)
	var t0: int = Time.get_ticks_msec()
	combat.player_defend()
	await process_frame
	print("Defend starts a sequence: commands hidden, 'braces' is the big current line: ", combat.playing and not battle.commands.visible and combat.battle_log.back() == "Oliver braces for the next attack." and battle.log_label.text.contains("[font_size=19][color=#ffffff]Oliver braces for the next attack.[/color][/font_size]"))
	root.get_texture().get_image().save_png("res://verify_beats_waiting.png")
	print("Saved verify_beats_waiting.png")
	# The short beat holds ~0.7 s, then the wind-up.
	await create_timer(0.9).timeout
	var hp_during_windup: int = character.stats.hp
	print("Then the wind-up beat, HP still untouched: ", combat.battle_log.back() == "Bandit prepares to strike..." and hp_during_windup == 200 and combat.playing)
	root.get_texture().get_image().save_png("res://verify_beats_windup.png")
	print("Saved verify_beats_windup.png")
	await create_timer(0.8).timeout
	print("Then the hit: message and HP drop land together: ", combat.battle_log.back().begins_with("Bandit attacks Oliver for") and character.stats.hp < 200 and combat.playing and not battle.commands.visible)
	root.get_texture().get_image().save_png("res://verify_beats_hit.png")
	print("Saved verify_beats_hit.png")
	# E hurries the current beat.
	var hit_line: String = combat.battle_log.back()
	await process_frame # a timer resume lands after the frame's callbacks; press at a frame start so _process sees it
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	var skipped_hit: bool = not combat.playing or combat.battle_log.back() != hit_line
	while combat.playing:
		combat.skip_beat()
		await process_frame
	await process_frame
	var elapsed: int = Time.get_ticks_msec() - t0
	print("E skips the rest of the hit beat: sequence over, commands back (%d ms in all): " % elapsed, skipped_hit and not combat.playing and battle.commands.visible and elapsed < 2600)
	print("The beats took real time (over 1.4 s), not a single frame: ", elapsed > 1400)

	# A tap on the message also hurries a beat.
	t0 = Time.get_ticks_msec()
	combat.player_defend()
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = battle.log_panel.get_global_rect().get_center()
	press.global_position = press.position
	var taps := 0
	while combat.playing and taps < 6:
		battle._on_log_gui_input(press)
		taps += 1
		await process_frame
		await process_frame
	print("Three taps run the three-beat sequence through in well under its 2.5 s (%d taps): " % taps, taps == 3 and not combat.playing and battle.commands.visible and Time.get_ticks_msec() - t0 < 1200)

	# Actions are ignored while a sequence plays.
	combat.player_defend()
	await process_frame
	var hp_before: int = character.stats.hp
	combat.player_attack()
	combat.player_defend()
	await process_frame
	print("A second press mid-sequence is ignored (still one sequence, HP unchanged so far): ", combat.playing and character.stats.hp == hp_before and combat.battle_log.back() == "Oliver braces for the next attack.")
	while combat.playing:
		combat.skip_beat()
		await process_frame

	# Winning: the doze-off beat shows the fallen enemy at 0 HP before the
	# slot clears, and the fight only ends after the last beat.
	combat.current_enemies[0].hp = 1
	combat.player_attack()
	await process_frame
	print("The attack beat comes first: ", combat.playing and combat.battle_log.back().begins_with("Oliver attacks Bandit for"))
	combat.skip_beat()
	await process_frame
	await process_frame
	print("Doze-off beat: enemy still on stage at 0 HP, fight not over yet: ", combat.playing and combat.in_combat and combat.current_enemies[0] != null and combat.current_enemies[0].hp == 0 and combat.battle_log.back().contains("dozes off"))
	root.get_texture().get_image().save_png("res://verify_beats_victory.png")
	print("Saved verify_beats_victory.png")
	while combat.playing:
		combat.skip_beat()
		await process_frame
	await process_frame
	var audio: Node = root.get_node("Audio")
	print("After the last beat the screen HOLDS on the victory summary (loot readable), commands gone, Continue shown, sting asked for: ", combat.in_combat and combat.awaiting_exit and battle.panel.visible and not battle.commands.visible and battle.continue_btn.visible and combat.battle_log.back().begins_with("Victory! You earned") and combat.battle_log.back().contains("XP") and audio.last_sting == "victory")
	root.get_texture().get_image().save_png("res://verify_beats_summary.png")
	print("Saved verify_beats_summary.png")
	print("The summary carries the fight's gold and XP: ", combat.fight_xp > 0 and combat.battle_log.back() == "Victory! You earned %d gold and %d XP.%s" % [combat.fight_gold, combat.fight_xp, "" if combat.fight_items.is_empty() else " Loot: %s." % ", ".join(combat.fight_items)])
	combat.player_attack()
	await process_frame
	print("Commands are ignored on the summary screen: ", combat.awaiting_exit and not combat.playing)
	var ended_victory := [false]
	combat.ended.connect(func(v: bool) -> void: ended_victory[0] = v, CONNECT_ONE_SHOT)
	battle.continue_btn.pressed.emit()
	await process_frame
	print("Continue ends the fight and closes the screen (ended(true) only now): ", not combat.in_combat and not combat.awaiting_exit and not battle.panel.visible and ended_victory[0])
	# E also leaves the summary.
	combat.start_combat(["bandit"])
	await process_frame
	combat.current_enemies[0].hp = 1
	combat.player_attack()
	await process_frame
	while combat.playing:
		combat.skip_beat()
		await process_frame
	await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("E on the summary screen leaves it too: ", not combat.in_combat and not battle.panel.visible)

	# Losing holds too: the last blow and the nap line stay up until Continue,
	# and only then does the nap (house + DefeatPanel) start.
	combat.start_combat(["bandit"])
	await process_frame
	character.stats.hp = 1
	combat.player_defend()
	await process_frame
	while combat.playing:
		combat.skip_beat()
		await process_frame
	await process_frame
	var defeat: Node = root.get_node("DefeatPanel")
	print("A lost fight holds on 'needs a nap' with Continue (no scene change yet): ", combat.in_combat and combat.awaiting_exit and battle.continue_btn.visible and combat.battle_log.back().begins_with("Oliver is worn out") and current_scene == overworld and not defeat.is_open())
	root.get_texture().get_image().save_png("res://verify_beats_defeat_hold.png")
	print("Saved verify_beats_defeat_hold.png")
	battle.continue_btn.pressed.emit()
	for i in range(8):
		await process_frame
	print("Continue starts the nap: fight over, home, nap panel up: ", not combat.in_combat and current_scene.name == "House" and defeat.is_open())
	defeat.wake_up()
	for i in range(4):
		await process_frame
	character.stats.max_hp = 200
	character.stats.hp = 200

	# Phone.
	root.size = Vector2i(400, 660)
	for i in range(6):
		await process_frame
	combat.start_combat(["bandit", "cave_bat"])
	await process_frame
	combat.player_defend()
	await process_frame
	var rect: Rect2 = battle.panel.get_global_rect()
	print("Phone: sequence playing, commands hidden, big line at 17px, panel inside 400x660: ", combat.playing and not battle.commands.visible and battle.log_label.text.contains("[font_size=17]") and rect.end.y <= 660.0 and rect.end.x <= 400.0)
	root.get_texture().get_image().save_png("res://verify_beats_phone.png")
	print("Saved verify_beats_phone.png")
	while combat.playing:
		combat.skip_beat()
		await process_frame
	combat.fast = true
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()
