extends SceneTree
# Builds a reusable Portal.tscn (Area2D + CollisionShape2D + portal.gd) —
# target_scene/target_spawn get set per-instance at runtime by whichever
# scene places it (see overworld.gd/house.gd).
# Run via: godot --headless --script res://tools/setup_portal.gd

func _initialize() -> void:
	var root := Area2D.new()
	root.name = "Portal"
	root.set_script(load("res://scripts/portal.gd"))

	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	shape_node.shape = rect
	root.add_child(shape_node)
	shape_node.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/Portal.tscn")
	print("Portal.tscn saved: ", err)
	quit()
