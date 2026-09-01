extends SceneTree

func _screenshot(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("Saved ", path)

func _player_overlapping(area: Area2D) -> bool:
	for b in area.get_overlapping_bodies():
		if b.is_in_group("player"):
			return true
	return false

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# --- Elder's house ---
	player.position = Vector2(World.ELDER_HOUSE_ENTRANCE.x * 32 + 16, (World.ELDER_HOUSE_ENTRANCE.y + 1) * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame

	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("Scene after entering elder house: ", current_scene.name)
	for i in range(3):
		await process_frame
	_screenshot("res://verify_elder_house.png")

	var elder_house := current_scene
	var elder_player: CharacterBody2D = elder_house.get_node("YSort/Player")
	var elder_npc: StaticBody2D = elder_house.get_node("YSort/NPC")
	print("Elder NPC position: ", elder_npc.position, " player: ", elder_player.position)
	var interact_area: Area2D = elder_npc.get_node("InteractArea")

	# Walk up toward the NPC and talk to them.
	Input.action_press("move_up")
	var steps := 0
	while not _player_overlapping(interact_area) and steps < 40:
		await physics_frame
		steps += 1
	Input.action_release("move_up")
	print("Reached NPC after ", steps, " steps")

	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Dialogue open: ", root.get_node("DialogueUI").is_open())
	_screenshot("res://verify_elder_dialogue.png")

	quit()
