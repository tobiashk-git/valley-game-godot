extends SceneTree
# Companions (phase 1) verification. Run via:
# godot --script res://tools/verify_companions.gd (NOT --headless).
#
# Luigi and Eden are once-per-fight boosters: locked until Meet the Village
# is turned in, then one charge each per fight. Bite = one target, twice
# Oliver's attack power; Scream = every enemy, no armour, regular survivors
# may be left reeling and skip a strike, a boss only flinches. The called
# companion then tanks: enemy blows land on its own small pool (a share of
# Oliver's max HP, no armour) until it limps out; calling the other sends it
# back. The battle panel shows bust buttons above the commands and a cameo
# with an HP bar beside the message box.

func _initialize() -> void:
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var quests: Node = root.get_node("Quests")
	var panel: Node = root.get_node("BattlePanel")
	await process_frame
	root.get_node("GameState").reset()
	root.get_node("Inventory").reset()
	character.reset()
	quests.reset()
	var house: Node2D = load("res://scenes/House.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in range(3):
		await process_frame
	character.stats.max_hp = 2000
	character.stats.hp = 2000
	character.stats.agility = 5 # no dodge
	var hp_bandit: int = root.get_node("Enemies").ENEMIES.bandit.max_hp
	# Every beat, in order (the battle log itself keeps only eight lines).
	var beats: Array = []
	combat.beat.connect(func(m: String) -> void: beats.append(m))

	# --- locked before the gateway ---
	combat.start_combat(["bandit"])
	await process_frame
	print("Before Meet the Village is turned in: no charges, the companion row is hidden: ", not combat.companions_unlocked() and combat.companion_charges.is_empty() and not panel.companion_row.visible)
	var log_before: int = combat.battle_log.size()
	combat.companion_act("luigi")
	await process_frame
	print("Calling Luigi while locked does nothing: ", combat.battle_log.size() == log_before and combat.current_enemies[0].hp == hp_bandit)
	combat.player_run()
	await process_frame

	# --- unlocked: who comes along follows the story ---
	quests.quest_state.meet_villagers = "completed"
	var world: Node = root.get_node("World")
	combat.start_combat(["bandit"])
	await process_frame
	var alone: bool = combat.companion_charges.is_empty() and not panel.companion_row.visible
	combat.player_run()
	await process_frame
	combat.start_boss_fight("dungeon_boss")
	await process_frame
	alone = alone and combat.companion_charges.is_empty()
	combat.player_run()
	await process_frame
	combat.start_combat(["bandit"], world.Zone.FROSTPEAK)
	await process_frame
	var before_event: bool = combat.companion_charges.is_empty()
	combat.player_run()
	await process_frame
	print("Before his joining event Luigi does not come along even in Frostpeak: ", before_event)
	quests.quest_state.join_luigi = "completed"
	quests.quest_state.join_eden = "completed"
	quests.quest_state.join_pair = "completed"
	combat.start_combat(["bandit"], world.Zone.FROSTPEAK)
	await process_frame
	var frost_luigi: bool = combat.companion_charges == {"luigi": 1} and panel.companion_row.visible and panel.companion_btns.luigi.visible and not panel.companion_btns.eden.visible
	combat.player_run()
	await process_frame
	combat.start_combat(["bandit"], world.Zone.VERDANTWOOD)
	await process_frame
	var verdant_eden: bool = combat.companion_charges == {"eden": 1} and not panel.companion_btns.luigi.visible and panel.companion_btns.eden.visible
	combat.player_run()
	await process_frame
	combat.start_boss_fight("verdantwood_boss")
	await process_frame
	verdant_eden = verdant_eden and combat.companion_charges == {"eden": 1}
	combat.player_run()
	await process_frame
	combat.start_boss_fight("frostpeak_boss")
	await process_frame
	frost_luigi = frost_luigi and combat.companion_charges == {"luigi": 1}
	combat.player_run()
	await process_frame
	print("Oliver is on his own in the village and the dungeon (no charges, no row): ", alone)
	print("Luigi comes along in Frostpeak (wilds and the Revenant), Eden stays home: ", frost_luigi)
	print("Eden alone in Verdantwood (wilds and the Bramblewood): ", verdant_eden)
	combat.start_combat(["bandit"], world.Zone.BADLANDS)
	await process_frame
	print("From the Badlands on both come: one charge each, the row shows both busts enabled: ", combat.companion_charges == {"luigi": 1, "eden": 1} and panel.companion_row.visible and panel.companion_btns.luigi.icon != null and panel.companion_btns.eden.icon != null and not panel.companion_btns.luigi.disabled and not panel.companion_btns.eden.disabled)
	print("The companion row sits inside the panel above the commands: ", panel.companion_row.get_global_rect().end.y <= panel.commands.get_global_rect().position.y and panel.commands.get_global_rect().end.y <= panel.panel.get_global_rect().end.y + 0.5)
	root.get_texture().get_image().save_png("res://verify_companions.png")
	print("Saved verify_companions.png")

	# --- Bite: twice an attack, one target ---
	character.stats.strength = 10
	var bandit_def: int = combat.current_enemies[0].defense
	var base: float = (20.0 + combat._weapon_attack_bonus()) * 8.0 / (8.0 + bandit_def) # a plain attack before its +-15%
	var bite_lo: int = int(floor(base * combat.BITE_MULT * 0.85)) - 1
	var bite_hi: int = int(ceil(base * combat.BITE_MULT * 1.15)) + 1
	combat.current_enemies[0].hp = 1000
	combat.current_enemies[0].max_hp = 1000
	var cameo_seen: Array = [false] # (a lambda captures locals by value - hence the array)
	combat.companion_called.connect(func(_id: String) -> void: cameo_seen[0] = panel.cameo.visible and panel.cameo.texture != null)
	combat.companion_act("luigi")
	await process_frame
	var bite: int = 1000 - combat.current_enemies[0].hp
	print("Luigi's bite lands at 1.5x a plain attack (", bite, ", expected ", bite_lo, "-", bite_hi, " around a plain ", int(round(base)), "): ", bite >= bite_lo and bite <= bite_hi)
	print("The cameo popped onto the stage when Luigi was called: ", cameo_seen[0])
	print("Luigi stays on as the tank with a pool of %d%% of Oliver's max HP, shown on the cameo's bar: " % int(combat.COMPANION_HP_FACTOR * 100), combat.companion_active == "luigi" and combat.companion_max_hp == int(round(2000 * combat.COMPANION_HP_FACTOR)) and panel.cameo.visible and panel.cameo_bar.visible and panel.cameo_bar.max_value == combat.companion_max_hp)
	print("The bandit's blow landed on Luigi, not Oliver: ", character.stats.hp == 2000 and combat.companion_hp < combat.companion_max_hp and combat.battle_log.any(func(l: String) -> bool: return l.contains("attacks Luigi the Fearless")))
	print("The charge is spent: the bust dims and a second call is ignored: ", combat.companion_charges.luigi == 0 and panel.companion_btns.luigi.disabled and panel.companion_btns.luigi.modulate.r < 0.6 and not panel.companion_btns.eden.disabled)
	var hp_now: int = combat.current_enemies[0].hp
	combat.companion_act("luigi")
	await process_frame
	print("...really ignored (no damage, no beat): ", combat.current_enemies[0].hp == hp_now)
	# Down to his last point: the next blow knocks him out, and does not carry over.
	combat.companion_hp = 1
	beats.clear()
	combat.player_defend()
	await process_frame
	print("With one point left the next blow knocks Luigi back out of the fight (Oliver untouched): ", combat.companion_active == "" and character.stats.hp == 2000 and beats.any(func(l: String) -> bool: return l.contains("limps out")) and panel.cameo_id == "")
	combat.player_defend()
	await process_frame
	print("The round after, the bandit hits Oliver again: ", character.stats.hp < 2000)
	combat.player_run()
	await process_frame

	# --- Bite with three enemies asks for a target ---
	combat.start_combat(["bandit", "bandit", "bandit"], world.Zone.GLOOMFEN)
	await process_frame
	print("A new fight refills both charges: ", combat.companion_charges == {"luigi": 1, "eden": 1})
	for e in combat.current_enemies:
		e.hp = 1000
		e.max_hp = 1000
	combat.companion_act("luigi")
	await process_frame
	print("With three bandits Luigi waits for a target (the cameo stays out): ", combat.selecting_target == "bite" and not combat.playing and panel.cameo.visible)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://verify_companions_cameo.png")
	combat.select_target(1)
	await process_frame
	print("The chosen bandit took the bite, the others none: ", combat.current_enemies[1].hp < 1000 and combat.current_enemies[0].hp == 1000 and combat.current_enemies[2].hp == 1000)

	# --- Scream: everyone, no armour; the reeling skip a strike ---
	for e in combat.current_enemies:
		e.hp = 1000
	beats.clear()
	combat.companion_act("eden")
	await process_frame
	print("Calling Eden while Luigi tanks sends him back and puts her on stage: ", beats.any(func(l: String) -> bool: return l.contains("steps back")) and combat.companion_active == "eden" and panel.cameo_id == "eden" and combat.companion_hp > 0)
	var all_hit := true
	var stunned := 0
	for e in combat.current_enemies:
		if e.hp >= 1000:
			all_hit = false
		if e.get("stunned", false):
			stunned += 1
	print("Eden's scream hurt all three bandits: ", all_hit and beats.any(func(l: String) -> bool: return l.contains("SCREAMS")))
	print("Its charge is spent, Luigi's was already: ", combat.companion_charges == {"luigi": 0, "eden": 0})
	# The stun flag is a coin flip; force it and watch the strikes get skipped.
	for e in combat.current_enemies:
		e.stunned = true
	combat.player_status = {} # no poison tick from an earlier bandit hit
	character.stats.hp = 2000
	beats.clear()
	combat.player_defend()
	await process_frame
	print("Reeling bandits skip their strike (Oliver untouched, three reeling beats) and shake it off after: ", character.stats.hp == 2000 and beats.filter(func(l: String) -> bool: return l.contains("still reeling")).size() == 3 and not combat.current_enemies.any(func(e) -> bool: return e != null and e.get("stunned", false)))
	combat.player_status = {}
	combat.companion_hp = combat.companion_max_hp
	combat.player_defend()
	await process_frame
	print("The next round they strike again - at Eden, who is tanking: ", character.stats.hp == 2000 and combat.companion_hp < combat.companion_max_hp)
	combat.player_run()
	await process_frame

	# --- a boss only flinches ---
	combat.start_boss_fight("gloomfen_boss")
	await process_frame
	combat.current_enemies[0].hp = 1000
	combat.current_enemies[0].max_hp = 1000
	combat.companion_act("eden")
	await process_frame
	print("Against the Bogmaw the scream hurts but never stuns: ", combat.current_enemies[0].hp < 1000 and not combat.current_enemies[0].get("stunned", false) and combat.battle_log.any(func(l: String) -> bool: return l.contains("only flinches")))
	combat.player_run()
	await process_frame
	print("Out of combat the row and cameo are gone: ", not combat.in_combat and not panel.companion_row.visible)
	quit()
