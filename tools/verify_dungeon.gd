extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Dungeon.tscn")
	var instance: Node2D = scene.instantiate()
	root.add_child(instance)
	for i in range(5):
		await process_frame

	var player: CharacterBody2D = instance.get_node("YSort/Player")
	print("Spawn position: ", player.position)

	var img1 := root.get_texture().get_image()
	img1.save_png("res://verify_dungeon_spawn.png")
	print("Saved verify_dungeon_spawn.png")

	# Walk up (toward the rest of the maze) for a while to explore.
	Input.action_press("move_up")
	for i in range(200):
		await physics_frame
	Input.action_release("move_up")

	print("Position after walking: ", player.position)
	var img2 := root.get_texture().get_image()
	img2.save_png("res://verify_dungeon_explored.png")
	print("Saved verify_dungeon_explored.png")

	quit()
