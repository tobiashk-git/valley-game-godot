extends SceneTree

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	root.get_texture().get_image().save_png("res://verify_character_before.png")

	# Open the character panel.
	Input.action_press("toggle_character")
	await process_frame
	Input.action_release("toggle_character")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://verify_character_panel.png")

	# Equip a fake weapon directly to confirm the equipment display updates.
	root.get_node("Character").equip("weapon", "wood")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://verify_character_equipped.png")

	# Toggle closed again.
	Input.action_press("toggle_character")
	await process_frame
	Input.action_release("toggle_character")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://verify_character_closed.png")

	quit()
