extends SceneTree

func _walk(direction: String, frames: int) -> void:
	Input.action_press(direction)
	for i in range(frames):
		await process_frame
	Input.action_release(direction)
	await process_frame

func _test_house(scene_path: String, door_tile: Vector2i, label: String) -> void:
	var scene: PackedScene = load(scene_path)
	var instance: Node2D = scene.instantiate()
	root.add_child(instance)
	current_scene = instance
	await process_frame
	await process_frame

	var player: CharacterBody2D = instance.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	cam.reset_smoothing()
	await process_frame

	# Walk straight south for way more frames than needed to cross the door
	# and wander into the (previously unbounded) void beyond it.
	await _walk("move_down", 90)
	var tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	print("[%s] Player tile after walking south through the door: %s" % [label, tile])
	print("[%s] Stopped at or before one tile past the door (not wandering off): %s" % [label, tile.y <= door_tile.y + 1])
	root.get_texture().get_image().save_png("res://verify_door_blocker_%s.png" % label)

	# Now confirm E still works normally from here (or backing up onto the
	# door tile if the blocker pushed them back before it).
	if tile.y < door_tile.y:
		await _walk("move_down", 10)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("[%s] E from the doorway still returns to the Overworld: %s" % [label, current_scene.name == "Overworld"])

	# change_scene_to_file() (inside portal.gd) already freed the house
	# instance automatically; just clean up the Overworld it left us on
	# before the next house loads.
	# The scene change is deferred - give it a frame or two, then clean up
	# whatever is current (null if it's still mid-swap).
	await process_frame
	await process_frame
	# (remove_child() of the current scene clears current_scene itself, so
	# hold a reference first.)
	var old_scene: Node = current_scene
	if old_scene != null:
		root.remove_child(old_scene)
		old_scene.queue_free()
	await process_frame

func _initialize() -> void:
	await _test_house("res://scenes/House.tscn", Vector2i(5, 8), "OwnHouse")
	await _test_house("res://scenes/ElderHouse.tscn", Vector2i(4, 6), "ElderHouse")
	quit()
