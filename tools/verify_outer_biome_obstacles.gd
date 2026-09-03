extends SceneTree
# Outer-biome scattered-obstacle verification (mighty oaks/Verdantwood, ice
# boulders + ice crystal shards/Frostpeak so far). Run via:
# godot --script res://tools/verify_outer_biome_obstacles.gd (NOT --headless -
# this takes real screenshots via get_texture()).

const OBSTACLES := [
	{"scene_path": "res://scenes/props/MightyOak.tscn", "zone_name": "VERDANTWOOD"},
	{"scene_path": "res://scenes/props/IceBoulder.tscn", "zone_name": "FROSTPEAK"},
	{"scene_path": "res://scenes/props/IceCrystalShard.tscn", "zone_name": "FROSTPEAK"},
	{"scene_path": "res://scenes/props/IcePool.tscn", "zone_name": "FROSTPEAK"},
	{"scene_path": "res://scenes/props/FallenLog.tscn", "zone_name": "VERDANTWOOD"},
	{"scene_path": "res://scenes/props/TangledBush.tscn", "zone_name": "VERDANTWOOD"},
	{"scene_path": "res://scenes/props/SwampTree.tscn", "zone_name": "GLOOMFEN"},
	{"scene_path": "res://scenes/props/SwampFerns.tscn", "zone_name": "GLOOMFEN"},
]

func _walk(player: CharacterBody2D, action: String, frames: int) -> void:
	Input.action_press(action)
	for i in range(frames):
		await physics_frame
	Input.action_release(action)
	await physics_frame

func _initialize() -> void:
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	var world: Node = root.get_node("World")
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var combat: Node = root.get_node("Combat")
	var ysort: Node2D = overworld.get_node("YSort")
	await process_frame

	for obstacle in OBSTACLES:
		var zone: int = world.Zone[obstacle.zone_name]
		# e.g. "res://scenes/props/IceCrystalShard.tscn" -> "IceCrystalShard" -
		# distinguishes 2 obstacles sharing the same zone_name (IceBoulder and
		# IceCrystalShard both scatter into FROSTPEAK).
		var label: String = obstacle.scene_path.get_file().get_basename()

		# Confirmed directly this session: Godot's sibling auto-rename for
		# repeated same-scene instances does NOT produce "Name2"/"Name3" -
		# only the very first instance keeps its scene-root name, every other
		# one gets an opaque "@StaticBody2D@N" internal name. scene_file_path
		# (set on the root of any instantiated PackedScene, immune to node
		# renaming) is the reliable match - same lesson as the npc_id-based
		# NPC lookup gotcha, just discovered fresh for props here.
		var instances: Array = []
		for child in ysort.get_children():
			if child.scene_file_path == obstacle.scene_path:
				instances.append(child)
		print("[%s] instances scattered: " % label, instances.size())
		print("[%s] At least one present: " % label, instances.size() > 0)

		if instances.is_empty():
			continue

		# Every found instance should genuinely be in its target biome (not
		# leaked into an adjacent biome, the valley, or the new mountain band).
		var all_in_zone := true
		for instance in instances:
			var tile := Vector2i(int(instance.position.x / 32), int(instance.position.y / 32))
			if world.biome_at(tile.x, tile.y).zone != zone:
				all_in_zone = false
				break
		print("[%s] Every scattered instance is in the right zone: " % label, all_in_zone)

		# --- Real collision check: walk straight into a known instance,
		# confirm it actually blocks movement rather than just rendering on
		# top. ---
		var target: Node2D = instances[0]
		player.position = target.position + Vector2(0, 48) # a tile and a half below it
		cam.reset_smoothing()
		for i in range(3):
			await process_frame
		if combat.in_combat:
			combat.player_run()
			await physics_frame
		await _walk(player, "move_up", 60) # 60 ticks * ~2.67px/tick ~= 160px, well past it if unobstructed
		print("[%s] Blocks movement (player stopped short of it): " % label, player.position.y > target.position.y + 8.0)

		cam.reset_smoothing()
		for i in range(3):
			await process_frame
		root.get_texture().get_image().save_png("res://verify_outer_biome_%s.png" % label.to_lower())
		print("Saved verify_outer_biome_%s.png" % label.to_lower())

	quit()
