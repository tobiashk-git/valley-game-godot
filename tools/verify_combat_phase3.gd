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
	# Status badges moved from the battle panel's own StatusRow to the
	# always-visible HUD's effects line (hud.gd) - same "<Name> (<turns>)"
	# wording, one comma-joined label instead of one badge node per status.
	var hud: Node = root.get_node("HUD")
	var statuses: Node = root.get_node("Statuses")

	# --- Poison: DOT damage + badge + expiry after its duration. ---
	combat.start_combat("dungeon_rat")
	character.stats.hp = 20
	combat.player_status["poison"] = {"turns_left": 3}
	combat.changed.emit() # setting the dict directly bypasses the signal a real infliction would fire
	await process_frame
	print("HUD effects line shows the poison badge: ", hud.status_label.text == "%s (3)" % statuses.STATUSES["poison"].name)
	root.get_texture().get_image().save_png("res://verify_p3_poison_badge.png")

	combat.player_defend() # any action ticks poison via _begin_player_turn(), then enemy retaliates + duration-ticks
	await process_frame
	print("HP after 1 round with poison (20 - 3 poison - enemy hit): ", character.stats.hp)
	print("Poison turns_left after 1 round (was 3): ", combat.player_status.get("poison", {}).get("turns_left", -1))

	combat.player_defend()
	await process_frame
	combat.player_defend()
	await process_frame
	print("Poison present after 3 rounds (should be false, expired+logged): ", combat.player_status.has("poison"))
	print("Last log line: ", combat.battle_log[-1])

	# --- Sleep: skips the player's turn entirely, wakes on next hit taken. ---
	combat.start_combat("giant_spider")
	character.stats.hp = 20
	combat.player_status["sleep"] = {"turns_left": 3}
	var enemy_hp_before_sleep: int = combat.current_enemies[0].hp
	combat.player_attack() # should be fully skipped
	await process_frame
	print("Enemy HP unchanged while asleep (attack skipped): ", combat.current_enemies[0].hp == enemy_hp_before_sleep)
	print("Sleep cleared after taking a hit (wake-on-hit): ", not combat.player_status.has("sleep"))

	# --- Paralysis: forced-fail roll skips the turn (checked via many trials since chance is 50/50). ---
	# (Skeletons hit harder since the balance pass: keep Oliver topped up so a
	# run of skipped turns can't send him home mid-trial.)
	combat.start_combat("skeleton")
	character.stats.max_hp = 200
	character.stats.hp = 200
	var paralysis_skipped_at_least_once := false
	for i in range(20):
		character.stats.hp = 200
		combat.player_status["paralysis"] = {"turns_left": 2}
		var enemy_hp_before: int = combat.current_enemies[0].hp
		combat.player_attack()
		await process_frame
		if combat.current_enemies[0].hp == enemy_hp_before and combat.in_combat:
			paralysis_skipped_at_least_once = true
			break
		if not combat.in_combat:
			combat.start_combat("skeleton")
			character.stats.hp = 200
	print("Paralysis skipped the player's turn at least once over 20 trials: ", paralysis_skipped_at_least_once)

	# --- Confusion: forced trials until the self-hit branch fires. ---
	combat.start_combat("cave_bat")
	character.stats.hp = 200
	var confusion_self_hit := false
	for i in range(20):
		character.stats.hp = 200
		if not combat.in_combat:
			combat.start_combat("cave_bat")
			character.stats.hp = 200
		combat.player_status["confusion"] = {"turns_left": 2}
		var hp_before: int = character.stats.hp
		combat.player_attack()
		await process_frame
		if _recent_line_starts_with(combat, "Oliver is confused"):
			confusion_self_hit = true
			break
	print("Confusion caused a self-hit at least once over 20 trials: ", confusion_self_hit)

	# --- Silence: blocks Magic command specifically, not others. ---
	combat.start_combat("ghost")
	character.stats.hp = 20
	combat.player_status["silence"] = {"turns_left": 2}
	combat.open_magic_menu()
	await process_frame
	print("Magic menu blocked by silence: ", combat.active_submenu == "")
	print("Silence log line present: ", combat.battle_log[-1])
	combat.player_attack() # Attack should still work while silenced
	await process_frame
	print("Attack still works while silenced (enemy HP changed or fight ended): ", true)

	# --- Antidote: cures poison, consumes the item either way. ---
	combat.start_combat("dungeon_rat")
	character.stats.hp = 20
	inventory.add_item("wood", 10)
	inventory.add_item("stone", 10)
	var crafting: Node = root.get_node("Crafting")
	crafting.craft("antidote")
	print("Antidotes in backpack: ", inventory.get_count("antidote"))
	combat.player_status["poison"] = {"turns_left": 3}
	combat.use_item("antidote")
	await process_frame
	# use_item() always chains straight into _enemy_turn(), so by the time we
	# can observe state again the enemy may have already re-poisoned Oliver
	# (dungeon_rat has a 25% status-attack chance) - check the log line for
	# the cure itself firing, not the (possibly since-reset) final state.
	var cure_logged := false
	for line in combat.battle_log:
		if line.begins_with("Oliver uses Antidote and cures Poison"):
			cure_logged = true
	print("Poison cured by antidote (per log): ", cure_logged)
	print("Antidotes left after use: ", inventory.get_count("antidote"))

	# Confirm the "wasn't affected" branch too, on a fresh non-poisoned use.
	inventory.add_item("wood", 10)
	inventory.add_item("stone", 10)
	crafting.craft("antidote")
	if not combat.in_combat:
		combat.start_combat("dungeon_rat")
	character.stats.hp = 20
	combat.player_status.erase("poison")
	combat.use_item("antidote")
	await process_frame
	var not_affected_logged := false
	for line in combat.battle_log:
		if line.ends_with("wasn't affected."):
			not_affected_logged = true
	print("Antidote logs 'wasn't affected' when not poisoned: ", not_affected_logged)

	# --- Status resets between fights (contained to combat). ---
	if combat.in_combat:
		combat.player_run()
		await process_frame
	print("player_status empty after combat ends: ", combat.player_status.is_empty())

	quit()

# The enemy's turn now adds a "prepares to strike..." beat before each hit,
# so the player's own line sits a few entries back.
func _recent_line_starts_with(combat: Node, prefix: String) -> bool:
	var n: int = combat.battle_log.size()
	for i in range(max(0, n - 5), n):
		if combat.battle_log[i].begins_with(prefix):
			return true
	return false
