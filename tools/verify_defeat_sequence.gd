extends SceneTree
# Death sequence verification. Run via:
# godot --script res://tools/verify_defeat_sequence.gd (NOT --headless).
#
# A lost fight: HP/MP restored, a tenth of the gold gone, the player sent
# home under a black fade, then the defeat panel names what got you and
# what it cost, movement is blocked until Wake up, which fades the panel
# away; poison and confusion deaths get their own line; the phone layout
# fits; a new fight dismisses a stale panel.

func _initialize() -> void:
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var inventory: Node = root.get_node("Inventory")
	var defeat: CanvasLayer = root.get_node("DefeatPanel")
	var layout: Node = root.get_node("Layout")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	inventory.add_item("gold", 37)

	# --- Lose to a skeleton. ---
	combat.start_combat(["skeleton"])
	await process_frame
	character.stats.hp = 1
	combat.player_defend() # the skeleton's turn finishes Oliver off
	await process_frame
	await process_frame
	await process_frame
	print("Defeat sends the player home with HP/MP restored, out of combat: ", current_scene.name == "House" and character.stats.hp == character.stats.max_hp and character.stats.mp == character.stats.max_mp and not combat.in_combat)
	print("A tenth of the gold is lost (37 -> 34): ", inventory.get_count("gold") == 34 and combat.last_defeat.gold_lost == 3 and combat.last_defeat.cause == "Skeleton")
	print("The screen is black while the house loads: ", defeat.is_open() and defeat.black.visible and defeat.black.modulate.a == 1.0 and not defeat.panel.visible)
	await create_timer(1.6).timeout
	print("Then the panel fades in over the dimmed house, naming the skeleton and the cost: ", defeat.panel.visible and defeat.panel.modulate.a > 0.95 and defeat.black.modulate.a < 0.7 and defeat.body_label.text.begins_with("The Skeleton got the better of you.") and defeat.body_label.text.contains("3 gold slipped"))
	var player: CharacterBody2D = current_scene.get_node("YSort/Player")
	var before: Vector2 = player.position
	Input.action_press("move_right")
	for i in range(10):
		await process_frame
	Input.action_release("move_right")
	await process_frame
	print("Movement is blocked while the panel is up: ", player.position == before)
	root.get_texture().get_image().save_png("res://verify_defeat_panel.png")
	print("Saved verify_defeat_panel.png")
	defeat.wake_btn.pressed.emit()
	await create_timer(0.8).timeout
	print("Wake up fades the panel away and frees the player: ", not defeat.is_open() and not defeat.panel.visible and not defeat.black.visible)
	Input.action_press("move_right")
	for i in range(10):
		await process_frame
	Input.action_release("move_right")
	await process_frame
	print("...and Oliver can walk again: ", player.position.x > before.x)

	# --- Story lines for the other causes. ---
	print("Poison and confusion deaths get their own lines; no gold -> purse line: ", defeat.story({"cause": "poison", "gold_lost": 0}).begins_with("The poison finally took its toll.") and defeat.story({"cause": "poison", "gold_lost": 0}).contains("untouched") and defeat.story({"cause": "confusion", "gold_lost": 2}).begins_with("Confused, you struck yourself down."))

	# --- Phone layout. ---
	root.size = Vector2i(400, 660)
	for i in range(6):
		await process_frame
	combat.start_combat(["dungeon_rat"])
	await process_frame
	character.stats.hp = 1
	combat.player_defend()
	await process_frame
	await create_timer(1.6).timeout
	var rect: Rect2 = defeat.panel.get_global_rect()
	print("Phone: panel spans the width, text and button inside: ", layout.is_narrow() and rect.size.x == 376.0 and defeat.wake_btn.get_global_rect().end.y <= rect.end.y and defeat.body_label.get_global_rect().end.y <= defeat.wake_btn.global_position.y and rect.end.y <= 660.0)
	root.get_texture().get_image().save_png("res://verify_defeat_phone.png")
	print("Saved verify_defeat_phone.png")
	# A new fight dismisses a stale panel.
	combat.start_combat(["dungeon_rat"])
	await process_frame
	await process_frame
	print("A new fight dismisses the panel: ", not defeat.is_open() and not defeat.panel.visible)
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()
