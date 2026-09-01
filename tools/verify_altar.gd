extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/Overworld.tscn")
	var instance: Node2D = scene.instantiate()
	root.add_child(instance)
	var player: CharacterBody2D = instance.get_node("Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# overworld.gd's own _ready() (which sets the default gate-side spawn) is
	# deferred, not synchronous with add_child() — wait a frame for it to run
	# before overriding, or this override gets clobbered right after.
	await process_frame

	player.position = Vector2(50 * 32 + 16, 51 * 32 + 16)
	cam.reset_smoothing()

	for i in range(5):
		await process_frame
	print("Final position: ", player.position, " camera global: ", cam.global_position)

	var img := root.get_texture().get_image()
	img.save_png("res://verify_altar.png")
	print("Saved verify_altar.png")
	quit()
