extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Overworld.tscn")
	var instance: Node2D = scene.instantiate()
	root.add_child(instance)
	await process_frame

	var world: Node = root.get_node("World")
	var player: CharacterBody2D = instance.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom = Vector2(2.0, 2.0)

	player.position = Vector2(world.place("dungeon").x * 32 + 16, world.place("dungeon").y * 32 + 16 + 40)
	cam.reset_smoothing()
	for i in range(5):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_dungeon_entrance.png")

	player.position = Vector2(world.place("castle").x * 32 + 16, world.place("castle").y * 32 + 16 + 40)
	cam.reset_smoothing()
	for i in range(5):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_castle_entrance.png")

	print("Saved both entrance screenshots")
	quit()
