extends SceneTree

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# --- Trader's house ---
	player.position = Vector2(World.TRADER_HOUSE_ENTRANCE.x * 32 + 16, (World.TRADER_HOUSE_ENTRANCE.y + 1) * 32 + 16)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("Scene: ", current_scene.name)
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_trader_house.png")

	# Back to overworld, then --- Empty house ---
	var trader_house := current_scene
	var out_portal: Area2D = trader_house.get_node("OutPortal")
	var trader_player: CharacterBody2D = trader_house.get_node("YSort/Player")
	trader_player.position = out_portal.position
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("Scene after leaving trader house: ", current_scene.name)

	var overworld2 := current_scene
	var player2: CharacterBody2D = overworld2.get_node("YSort/Player")
	var cam2: Camera2D = player2.get_node("Camera2D")
	player2.position = Vector2(World.EMPTY_HOUSE_ENTRANCE.x * 32 + 16, (World.EMPTY_HOUSE_ENTRANCE.y + 1) * 32 + 16)
	cam2.reset_smoothing()
	for i in range(3):
		await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("Scene: ", current_scene.name)
	for i in range(3):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_empty_house.png")

	var empty_house := current_scene
	print("Empty house has NPC node: ", empty_house.has_node("YSort/NPC"))
	print("Empty house furniture count (YSort children besides Player): ", empty_house.get_node("YSort").get_child_count() - 1)

	quit()
