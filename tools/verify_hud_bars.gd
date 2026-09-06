extends SceneTree
# HUD verification: HP/MP bars + effects line + location label + fitted
# panel. Run via:
# godot --script res://tools/verify_hud_bars.gd (NOT --headless - takes a
# real screenshot via get_texture()).
#
# Covers the user-requested move of the player's HP/MP bars and status
# badges from the battle screen to the always-visible top-left HUD, laid
# out as a left-hand column (HP over MP, effects line beneath); the
# follow-up that replaced "World N" with the player's current biome (word-
# wrapped) and shrank the panel to fit its content; and - the condition the
# move was made under - that the HUD stays fully visible and uncovered
# while a fight screen is up, even with the longest biome name showing.

func _initialize() -> void:
	var hud: CanvasLayer = root.get_node("HUD")
	var battle: CanvasLayer = root.get_node("BattlePanel")
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var world: Node = root.get_node("World")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	var stats: Dictionary = character.stats
	print("HUD has HP + MP bars and an effects line under the counters: ", hud.has_node("Panel/Margin/VBox/HPBar") and hud.has_node("Panel/Margin/VBox/MPBar") and hud.has_node("Panel/Margin/VBox/StatusLabel"))
	print("HUD HP bar tracks Character.stats: ", hud.hp_bar.value == stats.hp and hud.hp_bar.max_value == stats.max_hp and hud.hp_label.text == "HP %d / %d" % [stats.hp, stats.max_hp])
	print("HUD MP bar tracks Character.stats: ", hud.mp_bar.value == stats.mp and hud.mp_bar.max_value == stats.max_mp and hud.mp_label.text == "MP %d / %d" % [stats.mp, stats.max_mp])
	var hud_panel: Panel = hud.get_node("Panel")
	var hp_rect: Rect2 = hud.hp_bar.get_global_rect()
	var mp_rect: Rect2 = hud.mp_bar.get_global_rect()
	var status_rect: Rect2 = hud.status_label.get_global_rect()
	var counters_x: float = hud.get_node("Panel/Margin/VBox/HBox").get_global_rect().position.x
	print("HP bar sits directly above the MP bar: ", hp_rect.end.y <= mp_rect.position.y and mp_rect.position.y - hp_rect.end.y < 12.0)
	print("Effects line sits below the MP bar: ", mp_rect.end.y <= status_rect.position.y)
	print("Bars + effects line are left-aligned with the counters (a column): ", is_equal_approx(hp_rect.position.x, mp_rect.position.x) and is_equal_approx(hp_rect.position.x, status_rect.position.x) and is_equal_approx(hp_rect.position.x, counters_x))
	print("Panel is the narrow 320px (was 440): ", is_equal_approx(hud_panel.size.x, 320.0))
	print("Bars span the panel's inner width: ", is_equal_approx(hp_rect.size.x, hud_panel.size.x - 16.0))
	print("Effects line reads 'No effects' when nothing is active: ", combat.player_status.is_empty() and hud.status_label.text == "No effects")
	print("Gold counter above the bars, wood/stone counters gone: ", hud.has_node("Panel/Margin/VBox/HBox/GoldLabel") and not hud.has_node("Panel/Margin/VBox/HBox/WoodLabel") and not hud.has_node("Panel/Margin/VBox/HBox/StoneLabel"))
	print("Old 'World N' label is gone: ", not hud.has_node("Panel/Margin/VBox/HBox/WorldLabel"))
	print("Battle panel no longer has its own player HP/MP bars or status row: ", not battle.has_node("Panel/Margin/VBox/PlayerRow"))

	# --- Location label + fitted panel. Village spawn is Golden Plains
	# (short, one line); Emberfall Badlands is the longest name (two lines)
	# and must still keep the panel above the fight screen's top (y=148). ---
	print("Location shows the biome under the player at the village spawn: ", hud.location_label.text == "Golden Plains", " -> '", hud.location_label.text, "'")
	var fitted_short: float = hud_panel.size.y
	print("Panel height fits its content (no dead space under the effects line): ", is_equal_approx(fitted_short, hud.get_node("Panel/Margin").get_combined_minimum_size().y), " (", fitted_short, "px)")
	print("Panel fits under 140px with a one-line location (XP row included): ", fitted_short < 140.0)
	print("Gold XP bar under the MP bar, tracking level progress: ", hud.has_node("Panel/Margin/VBox/XPBar") and hud.xp_bar.theme_type_variation == &"XPBar" and hud.xp_bar.get_global_rect().position.y >= mp_rect.end.y and hud.xp_bar.get_global_rect().end.y <= status_rect.position.y and hud.xp_bar.max_value == character.xp_to_next(stats.level) and hud.xp_bar.value == stats.xp and hud.xp_label.text == "Level %d   %d / %d XP" % [stats.level, stats.xp, character.xp_to_next(stats.level)])

	var badlands_tile := Vector2i(world.WORLD_CENTER_X, world.WORLD_CENTER_Y + world.VALLEY_RADIUS + 12)
	player.position = Vector2(badlands_tile.x * 32 + 16, badlands_tile.y * 32 + 16)
	cam.reset_smoothing()
	for i in range(4):
		await process_frame
	print("Location updates as the player moves biome: ", hud.location_label.text == "Emberfall Badlands", " -> '", hud.location_label.text, "'")
	print("Longest biome name fits on one line beside the gold counter (wood/stone gone), panel still 320: ", hud.location_label.get_line_count() == 1 and is_equal_approx(hud_panel.size.x, 320.0))
	var hud_rect_long: Rect2 = hud_panel.get_global_rect()
	print("Panel keeps its height with the long name and ends above the fight screen (y<164): ", is_equal_approx(hud_rect_long.size.y, fitted_short) and hud_rect_long.end.y < 164.0, " (ends y=", hud_rect_long.end.y, ")")

	# --- Fight screen up (with the tall/long-name HUD): HUD must stay
	# visible AND uncovered. ---
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	combat.start_combat(["dungeon_rat"])
	await process_frame
	await process_frame
	print("Fight screen is up: ", combat.in_combat and battle.panel.visible)
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
	character.stats.xp = 7
	character.changed.emit()
	await process_frame
	print("XP bar follows Character.stats.xp: ", hud.xp_bar.value == 7 and hud.xp_label.text.contains("7 / "))

	# --- Back at the village for the resting-state screenshot. ---
	player.position = Vector2(world.WORLD_CENTER_X * 32 + 16, (world.WORLD_CENTER_Y + 4) * 32 + 16)
	cam.reset_smoothing()
	for i in range(4):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_hud_bars.png")
	print("Saved verify_hud_bars.png")
	quit()
