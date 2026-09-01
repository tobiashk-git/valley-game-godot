extends SceneTree
# Non-headless verification for Phase 1 (real window, real rendering).
# Run via: godot --script res://tools/verify_phase1.gd

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Overworld.tscn")
	var instance: Node2D = scene.instantiate()
	root.add_child(instance)

	for i in range(5):
		await process_frame

	var player: CharacterBody2D = instance.get_node("Player")
	print("Player spawn position: ", player.position, " tile: ", player.position / 32)

	var img1 := root.get_texture().get_image()
	img1.save_png("res://verify_village.png")
	print("Saved verify_village.png")

	# Walk north through the village and out the north gate toward the snow biome.
	Input.action_press("move_up")
	for i in range(400):
		await physics_frame
	Input.action_release("move_up")

	print("Player position after walking north: ", player.position, " tile: ", player.position / 32)
	var img2 := root.get_texture().get_image()
	img2.save_png("res://verify_snow_biome.png")
	print("Saved verify_snow_biome.png")

	print("=== Phase 1 verification complete ===")
	quit()
