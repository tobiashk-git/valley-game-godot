extends SceneTree
# Verifies trees/rocks/entrance markers. Run via:
# godot --script res://tools/verify_phase1b.gd

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Overworld.tscn")
	var instance: Node2D = scene.instantiate()
	root.add_child(instance)
	await process_frame

	var player: CharacterBody2D = instance.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom = Vector2(1.0, 1.0)

	# House entrance area (WORLD_CENTER_X-5, WORLD_CENTER_Y-3) = (45, 47)
	player.position = Vector2(45 * 32 + 16, 47 * 32 + 16)
	cam.reset_smoothing()
	for i in range(5):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_house_entrance.png")
	print("Saved verify_house_entrance.png")

	# Open valley area, away from the village, to see scattered trees/rocks
	player.position = Vector2(38 * 32 + 16, 38 * 32 + 16)
	cam.reset_smoothing()
	for i in range(5):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_valley_trees.png")
	print("Saved verify_valley_trees.png")

	print("=== Verification complete ===")
	quit()
