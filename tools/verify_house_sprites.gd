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
		"Blacksmith": [world.BLACKSMITH_HOUSE_ENTRANCE, "res://assets/house_smithy.png"],
		"Oliver's": [world.HOUSE_ENTRANCE, "res://assets/house.png"],
	}
	var base_h: int = load("res://assets/house.png").get_height()
	for name in expected:
		var house: Node2D = _house_at(ysort, expected[name][0])
		var sprite: Sprite2D = house.get_node("Sprite2D") if house else null
		print(name, " house found: ", house != null)
		print(name, " house shows its own sprite: ", sprite != null and sprite.texture.resource_path == expected[name][1])
		print(name, " house sprite is the shared 117px width, roughly the shared height (the smithy's steeper roof is 108 tall): ", sprite != null and sprite.texture.get_width() == 117 and sprite.texture.get_height() >= 100 and sprite.texture.get_height() <= 123)

	# --- Solid footprint: the house blocks from every side, not just its
	# entrance tile (user report: could walk into the drawn wall from the
	# back and get hidden behind it). Walk at the Elder's house from the
	# left, right and top; the player's body must never enter the drawn
	# sprite rect. From below the doorstep band stays walkable so the
	# entrance portal is still reachable - verify_house_portal.gd covers
	# that. ---
	# Oliver's house has open grass either side (the village wall runs one
	# tile above every house, so a pure top approach can't start far enough
	# back - the side approaches at roof height cover "walking in from the
	# back" instead). Each walk must actually REACH the house: a gap of more
	# than a few px means something else stopped the player and the check
	# would be vacuous.
	var house: Node2D = _house_at(ysort, world.HOUSE_ENTRANCE)
	var hsprite: Sprite2D = house.get_node("Sprite2D")
	var drawn: Vector2 = hsprite.texture.get_size() * hsprite.scale
	var sprite_rect := Rect2(house.position + Vector2(-drawn.x / 2.0, hsprite.offset.y * hsprite.scale.y - drawn.y / 2.0), drawn)
	var combat: Node = root.get_node("Combat")
	const PLAYER_HALF := 10.0
	# The collider itself: one rect from the sprite's top edge down to the
	# tile's bottom edge (HALF=16), full drawn width minus a 1px trim - the
	# geometry the walks below exercise from the sides; the top edge is
	# asserted here directly because the village wall sits one tile above
	# every house, too close for a clean top-down walk to start from.
	var collider: CollisionShape2D = house.get_node("CollisionShape2D")
	var col_rect := Rect2(house.position + collider.position - collider.shape.size / 2.0, collider.shape.size)
	print("Collider spans the drawn sprite from its top edge to the tile bottom: ", absf(col_rect.position.y - sprite_rect.position.y) < 1.0 and absf(col_rect.end.y - (house.position.y + 16.0)) < 1.0 and absf(col_rect.size.x - (drawn.x - 2.0)) < 1.0, " collider=", col_rect)
	# Scattered valley Tree/Rock props can sit right beside the house and stop
	# a walk short - clear them (same pattern as the other verify scripts).
	for child in ysort.get_children():
		if (child.scene_file_path.ends_with("Tree.tscn") or child.scene_file_path.ends_with("Rock.tscn")) and child.position.distance_to(house.position) < 140.0:
			child.queue_free()
	await process_frame
	await process_frame
	# Starts 30px out (player body spans 20-40px from the wall) - a 50px
	# start overlapped a village wall post beside the house at roof height
	# and got pushed to its far side.
	var approaches := [
		["left, wall height", sprite_rect.position + Vector2(-30.0, drawn.y * 0.8), "move_right", "left"],
		["left, roof height", sprite_rect.position + Vector2(-30.0, drawn.y * 0.25), "move_right", "left"],
		["right, wall height", sprite_rect.position + Vector2(drawn.x + 30.0, drawn.y * 0.8), "move_left", "right"],
		["right, roof height", sprite_rect.position + Vector2(drawn.x + 30.0, drawn.y * 0.25), "move_left", "right"],
	]
	for approach in approaches:
		var start: Vector2 = approach[1]
		player.position = start
		cam.reset_smoothing()
		for i in range(3):
			await physics_frame
		Input.action_press(approach[2])
		for i in range(45):
			await physics_frame
		Input.action_release(approach[2])
		await physics_frame
		while combat.in_combat:
			combat.player_run()
			await physics_frame
		# Gap between the player's body edge and the drawn sprite edge on the
		# approach side: negative = inside the drawn house (the bug), more
		# than a few px = never got there (test setup problem, not a pass).
		var gap: float
		match approach[3]:
			"left": gap = sprite_rect.position.x - (player.position.x + PLAYER_HALF)
			"right": gap = (player.position.x - PLAYER_HALF) - sprite_rect.end.x
			_: gap = sprite_rect.position.y - (player.position.y + PLAYER_HALF)
		print("House is solid from the ", approach[0], " (stopped touching the drawn edge, gap ", snappedf(gap, 0.1), "px): ", gap >= -2.0 and gap <= 6.0, "  start=", start, " end=", player.position)
	print("House sprite still bottom-anchored at its entrance tile: ", absf(sprite_rect.end.y - (house.position.y + 16.0)) < 12.0)

	var elder: Node2D = _house_at(ysort, world.ELDER_HOUSE_ENTRANCE)
	player.position = elder.position + Vector2(0, 3 * 32)
	cam.reset_smoothing()
	for i in range(4):
		await process_frame
	root.get_texture().get_image().save_png("res://verify_house_sprites.png")
	print("Saved verify_house_sprites.png")
	quit()
