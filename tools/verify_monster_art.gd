extends SceneTree
# Painted creature art verification. Run via:
# godot --script res://tools/verify_monster_art.gd (NOT --headless).
#
# Species with a file in assets/enemies/art draw that art: keyed tight
# (opaque pixels touch the top and bottom rows, corners transparent),
# smooth on the battle stage inside its 96px box, and on the overworld as
# a wild monster at a fixed 60px height with the interact area sized to
# the drawn sprite. Placeholder species keep the crisp pixel path.

# Loaded at runtime, not preloaded: a preload compiles wild_monster.gd
# before the autoloads it names exist under --script.
var WILD_SCENE: PackedScene

func _initialize() -> void:
	WILD_SCENE = load("res://scenes/props/WildMonster.tscn")
	var enemies: Node = root.get_node("Enemies")
	var combat: Node = root.get_node("Combat")
	var battle: CanvasLayer = root.get_node("BattlePanel")
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	combat._steps_since_encounter = -100000

	var with_art: Array = []
	for id in enemies.ENEMIES.keys():
		if enemies.is_art(enemies.ENEMIES[id].sprite):
			with_art.append(id)
	print("All five starters have painted art; an outer-biome species (Bandit) still uses its pixel sprite: ", with_art.has("dungeon_rat") and with_art.has("cave_bat") and with_art.has("skeleton") and with_art.has("giant_spider") and with_art.has("ghost") and not enemies.is_art(enemies.ENEMIES.bandit.sprite))

	for id in with_art:
		var path: String = enemies.ENEMIES[id].sprite
		var tex: Texture2D = load(path)
		var img: Image = tex.get_image()
		var w: int = img.get_width()
		var h: int = img.get_height()
		var top_hit := false
		var bottom_hit := false
		for x in range(w):
			if img.get_pixel(x, 0).a > 0.2:
				top_hit = true
			if img.get_pixel(x, h - 1).a > 0.2:
				bottom_hit = true
		var corners_clear: bool = img.get_pixel(0, 0).a == 0.0 and img.get_pixel(w - 1, 0).a == 0.0 and img.get_pixel(0, h - 1).a == 0.0 and img.get_pixel(w - 1, h - 1).a == 0.0
		var opaque := 0
		for y in range(0, h, 2):
			for x in range(0, w, 2):
				if img.get_pixel(x, y).a > 0.9:
					opaque += 1
		var filled: float = float(opaque) / float((w / 2) * (h / 2))
		print("%s art: %dx%d, longest side 256, cropped tight (art touches top and bottom rows), corners clear, mostly opaque (%d%%): " % [id, w, h, int(filled * 100.0)], max(w, h) == 256 and top_hit and bottom_hit and corners_clear and filled > 0.3)

	# --- Battle stage. ---
	combat.start_combat(["dungeon_rat", "skeleton", "ghost"])
	await process_frame
	await process_frame
	var rat_sprite: TextureRect = battle.enemy_slots[0].get_node("Box/Sprite")
	var ghost_sprite: TextureRect = battle.enemy_slots[2].get_node("Box/Sprite")
	print("Stage: rat, skeleton and ghost draw their painted art smooth (LINEAR) in the 96px box: ", rat_sprite.texture.resource_path.ends_with("/art/dungeon_rat.png") and rat_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and rat_sprite.size.y == 96.0 and ghost_sprite.texture.resource_path.ends_with("/art/ghost.png") and ghost_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
	# The old pixel path still works for a species without art.
	combat.fast = true
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	combat.start_combat(["bandit"])
	await process_frame
	print("A species without art keeps the crisp pixel path: ", battle.enemy_slots[0].get_node("Box/Sprite").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	root.get_texture().get_image().save_png("res://verify_monster_art_stage.png")
	print("Saved verify_monster_art_stage.png")
	combat.fast = true
	while combat.in_combat:
		combat.player_run()
		await physics_frame

	# --- Overworld wild monster. ---
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var rat: Node2D = WILD_SCENE.instantiate()
	rat.enemy_id = "dungeon_rat"
	rat.zone = -1
	rat.placement_key = "verify_rat"
	rat.position = player.position + Vector2(64, 0)
	overworld.get_node("YSort").add_child(rat)
	var skel: Node2D = WILD_SCENE.instantiate()
	skel.enemy_id = "skeleton"
	skel.zone = -1
	skel.placement_key = "verify_skel"
	skel.position = player.position + Vector2(-64, 0)
	overworld.get_node("YSort").add_child(skel)
	var bat: Node2D = WILD_SCENE.instantiate()
	bat.enemy_id = "bandit" # still on the pixel sprite
	bat.zone = -1
	bat.placement_key = "verify_bandit"
	bat.position = player.position + Vector2(-128, 0)
	overworld.get_node("YSort").add_child(bat)
	await process_frame
	await process_frame
	var drawn_h: float = rat.sprite.texture.get_size().y * rat.sprite.scale.y
	var shape: RectangleShape2D = rat.interact_shape.shape
	var skel_h: float = skel.sprite.texture.get_size().y * skel.sprite.scale.y
	print("Wild rat 40px tall, skeleton 52px (per-species art_height), smooth, interact area sized to the drawing, bandit still at pixel scale 0.8: ", absf(drawn_h - 40.0) < 0.5 and absf(skel_h - 52.0) < 0.5 and rat.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and absf(shape.size.y - (40.0 + 2.0 * rat.INTERACT_MARGIN)) < 0.5 and bat.sprite.scale == Vector2(0.8, 0.8) and bat.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var bottom: float = rat.sprite.position.y + (rat.sprite.offset.y + rat.sprite.texture.get_size().y / 2.0) * rat.sprite.scale.y
	print("Its feet sit at the node's base (bottom of the drawn sprite %.0fpx below the origin, = FEET_DROP): " % bottom, absf(bottom - rat.FEET_DROP) < 0.5)
	root.get_texture().get_image().save_png("res://verify_monster_art_overworld.png")
	print("Saved verify_monster_art_overworld.png")
	rat.queue_free()
	skel.queue_free()
	bat.queue_free()
	await process_frame
	quit()
