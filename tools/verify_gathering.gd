extends SceneTree
# Resource-gathering animation verification. Run via:
# godot --script res://tools/verify_gathering.gd (NOT --headless).
#
# Instant by default under a verify script (popup included); switched on,
# a press of E starts a half-second swing: Oliver faces the tree and is
# held still, the tree shakes and sheds chips, the wood only lands when
# the swing ends and a "+1 Wood" popup rises; a second E mid-swing is
# ignored; the third gather depletes the tree, which shrinks away.

func _initialize() -> void:
	var inventory: Node = root.get_node("Inventory")
	var game_state: Node = root.get_node("GameState")
	var combat: Node = root.get_node("Combat")
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	inventory.reset()
	combat._steps_since_encounter = -100000
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	# The nearest tree with no other gatherable close enough to share the
	# press (the scatter is dense; a rock beside it would pay out too).
	var gatherables: Array = []
	for child in overworld.get_node("YSort").get_children():
		if child.get("item_id") != null and child.has_node("InteractArea") and child.get("amount") != null:
			gatherables.append(child)
	var tree: Node2D = null
	var best := 1e9
	for g in gatherables:
		if g.scene_file_path != "res://scenes/props/Tree.tscn":
			continue
		var spot: Vector2 = g.position + Vector2(0, 30)
		var alone := true
		for other in gatherables:
			if other != g and other.position.distance_to(spot) < 80.0:
				alone = false
		var d: float = g.position.distance_to(player.position)
		if alone and d < best:
			best = d
			tree = g
	print("An isolated tree is within reach on the overworld: ", tree != null)
	player.position = tree.position + Vector2(0, 30) # inside the 48px reach area, clear of the 28px trunk collider
	player.get_node("Camera2D").reset_smoothing()
	for i in range(8):
		await physics_frame
	await process_frame

	# --- Instant under a verify script. ---
	print("Under a verify script gathering is instant by default: ", not tree.animated)
	await _press("interact")
	print("E grants the wood at once, with the popup: ", inventory.get_count("wood") == 1 and _popup_text(overworld) == "+1 Wood" and not game_state.gathering)

	# --- The real swing. ---
	tree.animated = true
	await _press("interact")
	var shaken := false
	var chips := false
	for i in range(6):
		if tree.sprite.position.x != 0.0:
			shaken = true
		if tree.has_node("Chips"):
			chips = true
		await process_frame
	print("E starts the swing: Oliver faces the tree, is held, no wood yet: ", game_state.gathering and tree.is_busy() and player.facing == "up" and inventory.get_count("wood") == 1)
	var before: Vector2 = player.position
	Input.action_press("move_right")
	for i in range(5):
		await process_frame
	Input.action_release("move_right")
	print("Held still during the swing: ", player.position == before)
	root.get_texture().get_image().save_png("res://verify_gather_swing.png")
	print("Saved verify_gather_swing.png")
	await create_timer(0.3).timeout
	print("The tree shook and shed chips: ", shaken and chips)
	await create_timer(0.5).timeout
	await process_frame
	print("When the swing ends the wood lands, Oliver is free, the popup rises: ", inventory.get_count("wood") == 2 and not game_state.gathering and not tree.is_busy() and _popup_text(overworld) == "+1 Wood")
	root.get_texture().get_image().save_png("res://verify_gather_popup.png")
	print("Saved verify_gather_popup.png")

	# --- A second E mid-swing is ignored; the third gather depletes the tree. ---
	await _press("interact")
	await process_frame
	await _press("interact")
	await create_timer(0.8).timeout
	await process_frame
	print("Double-tapping paid out once: wood 3, tree used up: ", inventory.get_count("wood") == 3 and (not is_instance_valid(tree) or tree.amount == 0))
	await create_timer(0.5).timeout
	print("The depleted tree shrank away and is gone: ", not is_instance_valid(tree) or not tree.is_inside_tree())
	quit()

func _press(action: String) -> void:
	await process_frame
	Input.action_press(action)
	await process_frame
	Input.action_release(action)
	await process_frame

func _popup_text(scene: Node2D) -> String:
	# Newest popup (siblings of the same name get auto-renamed).
	var text := ""
	for child in scene.get_node("YSort").get_children():
		if String(child.name).contains("GatherPopup"):
			text = child.get_child(0).get_node("Text").text
	return text
