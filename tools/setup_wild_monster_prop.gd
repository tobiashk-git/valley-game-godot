extends SceneTree
# Builds scenes/props/WildMonster.tscn from scratch via the node-creation API
# (rather than a hand-authored .tscn file) so Godot's own resource-saving
# handles unique_id/resource UID bookkeeping correctly - same reasoning as
# every other scene-authoring tool in this project. Same node shape as
# Boss.tscn/boss.gd (StaticBody2D + Sprite2D + blocking CollisionShape2D +
# InteractArea/CollisionShape2D) but with NO baked Texture2D - wild_monster.gd
# loads the correct sprite for its enemy_id at runtime, since one scene now
# needs to represent 12 different species across 5 shared sprite files.
# Run via: godot --headless --script res://tools/setup_wild_monster_prop.gd

func _initialize() -> void:
	print("=== WildMonster.tscn setup starting ===")

	var root := StaticBody2D.new()
	root.name = "WildMonster"
	root.set_script(load("res://scripts/wild_monster.gd"))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	# Same scale/offset Boss.tscn uses (proven readable for skeleton.png via
	# the Verdantwood maze guardian already) - a reasonable starting point
	# now that 4 more sprite files are in play too; flagged for a visual
	# tuning pass once instanced in-game.
	sprite.scale = Vector2(1.6, 1.6)
	sprite.offset = Vector2(0, -35.2)
	root.add_child(sprite)
	sprite.owner = root

	var body_shape := CollisionShape2D.new()
	body_shape.name = "CollisionShape2D"
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(28, 28)
	body_shape.shape = body_rect
	root.add_child(body_shape)
	body_shape.owner = root

	var interact_area := Area2D.new()
	interact_area.name = "InteractArea"
	root.add_child(interact_area)
	interact_area.owner = root

	var interact_shape := CollisionShape2D.new()
	interact_shape.name = "CollisionShape2D"
	var interact_rect := RectangleShape2D.new()
	interact_rect.size = Vector2(48, 48)
	interact_shape.shape = interact_rect
	interact_area.add_child(interact_shape)
	interact_shape.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/props/WildMonster.tscn")
	print("scenes/props/WildMonster.tscn saved: ", err)

	print("=== WildMonster.tscn setup complete ===")
	quit()
