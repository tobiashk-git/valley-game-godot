extends SceneTree
# HUD HP/MP bars + effects line verification. Run via:
# godot --script res://tools/verify_hud_bars.gd (NOT --headless - takes a
# real screenshot via get_texture()).
#
# Covers the user-requested move of the player's HP/MP bars and status
# badges from the battle screen to the always-visible top-left HUD, laid
# out as a left-hand column (HP over MP, effects line beneath): the bars
# exist and track Character.stats, the effects line tracks
# Combat.player_status, the battle panel no longer carries its own copies,
# and - the condition the move was made under - the HUD stays fully visible
# and uncovered while a fight screen is up.

func _initialize() -> void:
	var hud: CanvasLayer = root.get_node("HUD")
	var battle: CanvasLayer = root.get_node("BattlePanel")
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var stats: Dictionary = character.stats
	print("HUD has HP + MP bars and an effects line under the counters: ", hud.has_node("Panel/Margin/VBox/HPBar") and hud.has_node("Panel/Margin/VBox/MPBar") and hud.has_node("Panel/Margin/VBox/StatusLabel"))
	print("HUD HP bar tracks Character.stats: ", hud.hp_bar.value == stats.hp and hud.hp_bar.max_value == stats.max_hp and hud.hp_label.text == "HP %d / %d" % [stats.hp, stats.max_hp])
	print("HUD MP bar tracks Character.stats: ", hud.mp_bar.value == stats.mp and hud.mp_bar.max_value == stats.max_mp and hud.mp_label.text == "MP %d / %d" % [stats.mp, stats.max_mp])
	var hp_rect: Rect2 = hud.hp_bar.get_global_rect()
	var mp_rect: Rect2 = hud.mp_bar.get_global_rect()
	var status_rect: Rect2 = hud.status_label.get_global_rect()
	var counters_x: float = hud.get_node("Panel/Margin/VBox/HBox").get_global_rect().position.x
	print("HP bar sits directly above the MP bar: ", hp_rect.end.y <= mp_rect.position.y and mp_rect.position.y - hp_rect.end.y < 12.0)
	print("Effects line sits below the MP bar: ", mp_rect.end.y <= status_rect.position.y)
	print("Bars + effects line are left-aligned with the counters (a column): ", is_equal_approx(hp_rect.position.x, mp_rect.position.x) and is_equal_approx(hp_rect.position.x, status_rect.position.x) and is_equal_approx(hp_rect.position.x, counters_x))
	print("Bars are a fixed width, not stretched across the panel: ", is_equal_approx(hp_rect.size.x, 300.0) and is_equal_approx(mp_rect.size.x, 300.0))
	print("Effects line reads 'No effects' when nothing is active: ", combat.player_status.is_empty() and hud.status_label.text == "No effects")
	print("Counters still present above the bars: ", hud.has_node("Panel/Margin/VBox/HBox/WoodLabel") and hud.has_node("Panel/Margin/VBox/HBox/GoldLabel") and hud.has_node("Panel/Margin/VBox/HBox/WorldLabel"))
	print("Battle panel no longer has its own player HP/MP bars or status row: ", not battle.has_node("Panel/Margin/VBox/PlayerRow"))

	# --- Fight screen up: HUD must stay visible AND uncovered. ---
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	combat.start_combat(["dungeon_rat"])
	await process_frame
	await process_frame
	print("Fight screen is up: ", combat.in_combat and battle.panel.visible)
	var hud_panel: Panel = hud.get_node("Panel")
	print("HUD still visible during the fight: ", hud.visible and hud_panel.visible)
	var hud_rect: Rect2 = hud_panel.get_global_rect()
	var battle_rect: Rect2 = battle.panel.get_global_rect()
	print("HUD column not covered by the fight screen (rects don't overlap): ", not hud_rect.intersects(battle_rect), " hud=", hud_rect, " battle=", battle_rect)
	print("Fight screen still fits the 800x600 base viewport: ", battle_rect.end.y <= 600.0)

	# --- Bars + effects update live: an in-fight HP change and a status
	# announced via Combat.changed, and an out-of-fight one via
	# Character.changed, all land. ---
	var hp_before: float = hud.hp_bar.value
	character.stats.hp = max(1, character.stats.hp - 3)
	combat.player_status["poison"] = {"turns_left": 3}
	combat.changed.emit()
	await process_frame
	print("HUD HP bar updates on Combat.changed: ", hud.hp_bar.value == character.stats.hp and hud.hp_bar.value != hp_before and hud.hp_label.text == "HP %d / %d" % [character.stats.hp, character.stats.max_hp])
	var poison_name: String = root.get_node("Statuses").STATUSES["poison"].name
	print("Effects line shows an active status with turns left: ", hud.status_label.text == "%s (3)" % poison_name, " -> '", hud.status_label.text, "'")

	root.get_texture().get_image().save_png("res://verify_hud_bars_fight.png")
	print("Saved verify_hud_bars_fight.png")

	while combat.in_combat:
		combat.player_run()
		await physics_frame
	await process_frame
	print("Effects line clears once the fight ends: ", hud.status_label.text == "No effects")
	var mp_before: float = hud.mp_bar.value
	character.stats.mp = max(0, character.stats.mp - 2)
	character.changed.emit()
	await process_frame
	print("HUD MP bar updates on Character.changed: ", hud.mp_bar.value == character.stats.mp and hud.mp_bar.value != mp_before)

	root.get_texture().get_image().save_png("res://verify_hud_bars.png")
	print("Saved verify_hud_bars.png")
	quit()
