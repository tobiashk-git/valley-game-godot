extends SceneTree
# One-off visual check for Phase 7c ground-tile variety - teleports into each
# of the 4 affected biomes and saves a screenshot. Run via:
# godot --script res://tools/verify_ground_variety.gd (NOT --headless)

const OFFSETS := {
	"frostpeak": Vector2i(0, -40),
	"badlands": Vector2i(0, 40),
	"verdantwood": Vector2i(40, 0),
	"gloomfen": Vector2i(-40, 0),
}

func _initialize() -> void:
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var combat: Node = root.get_node("Combat")
	await process_frame

	for name in OFFSETS:
		var off: Vector2i = OFFSETS[name]
		player.position = Vector2((100 + off.x) * 32 + 16, (100 + off.y) * 32 + 16)
		cam.reset_smoothing()
		await process_frame
		await process_frame
		if combat.in_combat:
			combat.player_run()
			await physics_frame
			await process_frame
			await process_frame
		root.get_texture().get_image().save_png("res://verify_ground_%s.png" % name)
		print("Saved verify_ground_%s.png" % name)

	quit()
