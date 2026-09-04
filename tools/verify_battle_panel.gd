extends SceneTree
# Battle screen verification (UI redesign, combat pass). Run via:
# godot --script res://tools/verify_battle_panel.gd (NOT --headless).
#
# Layout (wide + phone), the enemy stage (big sprites, name, HP bar, gold
# target frames + hint while choosing a target, tap-to-target), the log
# (newest line bright), styled commands and submenu rows, floating damage
# numbers over the enemy and the HUD, hit flash, and touch controls hidden
# during a fight.

func _initialize() -> void:
	var combat: Node = root.get_node("Combat")
	var battle: CanvasLayer = root.get_node("BattlePanel")
	var hud: CanvasLayer = root.get_node("HUD")
	var touch: CanvasLayer = root.get_node("TouchControls")
	var character: Node = root.get_node("Character")
	var inventory: Node = root.get_node("Inventory")
	var layout: Node = root.get_node("Layout")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	inventory.add_item("healing_potion", 1)
	touch.visible = true
	touch.set_process(true)

	# --- Two enemies, wide layout. ---
	combat.start_combat(["dungeon_rat", "skeleton"])
	await process_frame
	await process_frame
	var rect: Rect2 = battle.panel.get_global_rect()
	var hud_rect: Rect2 = hud.panel.get_global_rect()
	print("Panel is the 560x420 kit window starting below the HUD (y=148), inside the viewport: ", rect.size == Vector2(560, 420) and rect.position.y == 148.0 and rect.end.y <= 600.0 and not rect.intersects(hud_rect))
	print("Stage, log, commands and submenu keep their paths: ", battle.has_node("Panel/Margin/VBox/Stage") and battle.has_node("Panel/Margin/VBox/LogPanel/LogMargin/LogLabel") and battle.has_node("Panel/Margin/VBox/Commands") and battle.has_node("Panel/Margin/VBox/Submenu"))
	var slot0: PanelContainer = battle.enemy_slots[0]
	var slot1: PanelContainer = battle.enemy_slots[1]
	var slot2: PanelContainer = battle.enemy_slots[2]
	print("Two slots shown, third hidden; sprites 96px, names and HP bars filled: ", slot0.visible and slot1.visible and not slot2.visible and slot0.get_node("Box/Sprite").size.x >= 96.0 and slot0.get_node("Box/NameLabel").text == "Dungeon Rat" and slot1.get_node("Box/NameLabel").text == "Skeleton" and slot0.get_node("Box/BarBox/HPBar/HPLabel").text == "12 / 12")
	print("Commands are kit buttons, Attack gold, 48px tall: ", battle.attack_btn.theme_type_variation == &"PrimaryButton" and battle.run_btn.theme_type_variation == &"SecondaryButton" and battle.attack_btn.size.y >= 48.0)
	print("Log: newest line bright, no target hint yet: ", battle.log_label.text.ends_with("[color=#ffffff]A Dungeon Rat and a Skeleton appear![/color]") and battle.target_hint.modulate.a == 0.0)
	print("Touch controls hidden during the fight: ", not touch.visible)
	root.get_texture().get_image().save_png("res://verify_battle_open.png")
	print("Saved verify_battle_open.png")

	# --- Attack with two enemies -> choose a target: hint + gold frames. ---
	combat.player_attack()
	await process_frame
	print("Choosing a target: hint shown, slots framed gold, commands hidden: ", combat.selecting_target == "attack" and battle.target_hint.modulate.a == 1.0 and slot0.get_theme_stylebox("panel") == battle._target_style and not battle.commands.visible)
	root.get_texture().get_image().save_png("res://verify_battle_targeting.png")
	print("Saved verify_battle_targeting.png")
	# Tap the skeleton's slot.
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	var skel_hp_before: int = combat.current_enemies[1].hp
	character.stats.hp = character.stats.max_hp
	slot1.gui_input.emit(tap)
	await process_frame
	var popups: Array = []
	for child in battle.panel.get_children():
		if child.name.begins_with("DamagePopup"):
			popups.append(child)
	print("Tapping a slot resolves the attack on it: ", combat.selecting_target == "" and combat.current_enemies[1].hp < skel_hp_before)
	var sprite_rect: Rect2 = slot1.get_node("Box/Sprite").get_global_rect()
	print("Damage floats up over the enemy hit (red, negative, positioned over its sprite) and the sprite flashes: ", popups.size() >= 1 and popups[0].text.begins_with("-") and slot1.get_node("Box/Sprite").self_modulate != Color.WHITE and absf(popups[0].get_global_rect().get_center().x - sprite_rect.get_center().x) < 30.0 and popups[0].global_position.y < sprite_rect.end.y)
	var hud_popups: Array = []
	for child in hud.get_children():
		if child.name.begins_with("HpPopup"):
			hud_popups.append(child)
	print("Enemy retaliation shows a floating number on the HUD too (if HP changed): ", character.stats.hp == character.stats.max_hp or hud_popups.size() >= 1)
	print("Frames gone once the target is chosen: ", slot0.get_theme_stylebox("panel") != battle._target_style and battle.commands.visible)
	root.get_texture().get_image().save_png("res://verify_battle_hit.png")
	print("Saved verify_battle_hit.png")

	# --- Magic submenu: kit rows with icons, Back. ---
	combat.player_status.clear()
	combat.open_magic_menu()
	await process_frame
	var rows: Array = battle.submenu.get_children()
	print("Magic submenu: two spell rows + Back, styled, icons capped at 24px: ", rows.size() == 3 and rows[0].text == "Fireball (3 MP)" and rows[0].theme_type_variation == &"SecondaryButton" and rows[0].icon != null and rows[0].get_theme_constant("icon_max_width") == 24 and rows[0].size.y >= 44.0 and rows[2].text == "Back" and rows[2].theme_type_variation == &"TabButton")
	print("Submenu takes the log's place and stays inside the panel: ", not battle.log_panel.visible and rows[2].get_global_rect().end.y <= battle.panel.get_global_rect().end.y)
	root.get_texture().get_image().save_png("res://verify_battle_magic.png")
	print("Saved verify_battle_magic.png")
	combat.close_submenu()
	await process_frame
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	await process_frame
	print("Touch controls back after the fight: ", touch.visible)

	# --- Phone layout. ---
	root.size = Vector2i(400, 660)
	for i in range(6):
		await process_frame
	combat.start_combat(["dungeon_rat", "skeleton", "cave_bat"])
	await process_frame
	await process_frame
	rect = battle.panel.get_global_rect()
	hud_rect = hud.panel.get_global_rect()
	print("Phone: panel spans the width, below the HUD, inside a 660-tall viewport: ", layout.is_narrow() and rect.size.x == 376.0 and rect.position.x == 12.0 and not rect.intersects(hud_rect) and rect.end.y <= 660.0)
	print("Phone: three 80px enemies fit the stage, commands 44px tall and inside the panel: ", battle.enemy_slots[2].visible and slot0.get_node("Box/Sprite").size.x >= 80.0 and battle.attack_btn.size.y >= 44.0 and battle.run_btn.get_global_rect().end.x <= rect.end.x + 0.5 and battle.enemy_slots[2].get_global_rect().end.x <= rect.end.x + 0.5)
	root.get_texture().get_image().save_png("res://verify_battle_phone.png")
	print("Saved verify_battle_phone.png")
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()
