extends SceneTree
# Village house sprite verification. Run via:
# godot --script res://tools/verify_house_sprites.gd (NOT --headless - takes
# real screenshots via get_texture()).
#
# The four village houses share HouseEntrance.tscn but the Elder's and the
# Ranger's get their own roof-recoloured PNG via _add_entrance()'s
# texture_path. Checks each house shows the intended texture, every variant
# is the same height as the base sprite (the scene's baked scale/offset
# assume 123px), and takes a village screenshot for a visual pass.

func _house_at(ysort: Node2D, tile: Vector2i) -> Node2D:
	for child in ysort.get_children():
		if child.scene_file_path.ends_with("HouseEntrance.tscn"):
			var t := Vector2i(floori(child.position.x / 32.0), floori(child.position.y / 32.0))
			if t == tile:
				return child
	return null

func _initialize() -> void:
	var world: Node = root.get_node("World")
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var ysort: Node2D = overworld.get_node("YSort")

	var expected := {
		"Elder": [world.ELDER_HOUSE_ENTRANCE, "res://assets/house_elder.png"],
		"Trader": [world.TRADER_HOUSE_ENTRANCE, "res://assets/house.png"],
		"Ranger": [world.EMPTY_HOUSE_ENTRANCE, "res://assets/house_ranger.png"],
		"Oliver's": [world.HOUSE_ENTRANCE, "res://assets/house.png"],
	}
	var base_h: int = load("res://assets/house.png").get_height()
	for name in expected:
		var house: Node2D = _house_at(ysort, expected[name][0])
		var sprite: Sprite2D = house.get_node("Sprite2D") if house else null
		print(name, " house found: ", house != null)
		print(name, " house shows its own sprite: ", sprite != null and sprite.texture.resource_path == expected[name][1])
		print(name, " house sprite is the shared 123px height: ", sprite != null and sprite.texture.get_height() == base_h and base_h == 123)

	var elder: Node2D = _house_at(ysort, world.ELDER_HOUSE_ENTRANCE)
	player.position = elder.position + Vector2(0, 3 * 32)
	cam.reset_smoothing()
	for i in range(4):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_house_sprites.png")
	print("Saved verify_house_sprites.png")
	quit()
