extends SceneTree
# Non-headless verification pass for Phase 0 — run with a real window so the
# viewport actually renders (true --headless disables rendering entirely).
# Loads Main.tscn, screenshots it, simulates movement input, screenshots
# again, and prints the player's position so movement can be confirmed
# without needing a Web export just to prove the loop works.
# Run via: godot --script res://tools/verify_phase0.gd

func _initialize() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main_instance: Node2D = main_scene.instantiate()
	root.add_child(main_instance)

	# let a few frames render before the first screenshot
	for i in range(5):
		await process_frame

	var player: CharacterBody2D = main_instance.get_node("Player")
	print("Initial player position: ", player.position)

	var img1 := root.get_texture().get_image()
	img1.save_png("res://verify_before.png")
	print("Saved verify_before.png")

	# simulate holding "move_right" for ~30 physics frames (~0.5s at 60fps)
	Input.action_press("move_right")
	for i in range(30):
		await physics_frame

	print("Player position after moving right: ", player.position)

	var img2 := root.get_texture().get_image()
	img2.save_png("res://verify_after_move.png")
	print("Saved verify_after_move.png")

	Input.action_release("move_right")

	print("=== Verification complete ===")
	quit()
