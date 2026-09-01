extends SceneTree
# Verifies the overworld <-> house portal round trip. change_scene_to_file()
# operates on current_scene, which the normal F5 boot sets automatically —
# a manually-driven --script runner has to set it explicitly too.

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# Stand right next to the house entrance (which is itself solid).
	player.position = Vector2(World.HOUSE_ENTRANCE.x * 32 + 16, (World.HOUSE_ENTRANCE.y + 1) * 32 + 16)
	cam.reset_smoothing()
	for i in range(5):
		await process_frame

	root.get_texture().get_image().save_png("res://verify_before_enter.png")
	print("Saved verify_before_enter.png, current_scene: ", current_scene.name)

	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	# change_scene_to_file() is deferred to the end of the frame.
	await process_frame
	await process_frame

	print("current_scene after E press: ", current_scene.name)
	for i in range(5):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_inside_house.png")
	print("Saved verify_inside_house.png")

	# Now walk out through the door.
	var house := current_scene
	var house_player: CharacterBody2D = house.get_node("YSort/Player")
	print("House player start position: ", house_player.position)
	var out_portal: Area2D = house.get_node("OutPortal")
	print("OutPortal position: ", out_portal.position, " shape size: ", out_portal.get_node("CollisionShape2D").shape.size)

	# Walk in small steps, stopping as soon as the portal detects the player
	# (walking a fixed distance blindly can overshoot straight past the zone).
	Input.action_press("move_down")
	var steps := 0
	while out_portal.get_overlapping_bodies().is_empty() and steps < 40:
		await physics_frame
		steps += 1
	Input.action_release("move_down")
	for i in range(2):
		await process_frame

	print("House player position when overlap detected: ", house_player.position, " after ", steps, " steps")
	print("Overlapping bodies in portal: ", out_portal.get_overlapping_bodies())

	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame

	print("current_scene after leaving: ", current_scene.name)
	for i in range(5):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_back_outside.png")
	print("Saved verify_back_outside.png")

	quit()
