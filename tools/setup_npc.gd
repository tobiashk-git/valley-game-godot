extends SceneTree
# Builds NPC.tscn (solid StaticBody2D + a bigger InteractArea for E-press
# dialogue range) and the remaining village-house furniture props
# (Bookshelf, Barrel, Cabinet) using the same bottom-anchored convention.
# Run via: godot --headless --script res://tools/setup_npc.gd

const TILE := 32.0
const HALF := TILE / 2.0

func _build_prop(scene_name: String, tex_path: String, src_w: float, src_h: float) -> void:
	var body := StaticBody2D.new()
	body.name = scene_name

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(tex_path)
	sprite.offset = Vector2(0, HALF - src_h / 2.0)
	body.add_child(sprite)
	sprite.owner = body

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE - 4, TILE - 4)
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body

	var packed := PackedScene.new()
	packed.pack(body)
	var err := ResourceSaver.save(packed, "res://scenes/props/%s.tscn" % scene_name)
	print(scene_name, ".tscn saved: ", err)

func _build_npc() -> void:
	var body := StaticBody2D.new()
	body.name = "NPC"
	body.set_script(load("res://scripts/npc.gd"))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	# offset set at runtime once npc.gd loads the right texture per-instance;
	# NPC art (elder.png/trader.png) is a single 64x64 static frame, same
	# bottom-anchor math as everything else.
	sprite.offset = Vector2(0, HALF - 64.0 / 2.0)
	body.add_child(sprite)
	sprite.owner = body

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE - 4, TILE - 4)
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body

	var interact_area := Area2D.new()
	interact_area.name = "InteractArea"
	body.add_child(interact_area)
	interact_area.owner = body

	var interact_shape := CollisionShape2D.new()
	interact_shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 48)
	interact_shape.shape = rect
	interact_area.add_child(interact_shape)
	interact_shape.owner = body

	var packed := PackedScene.new()
	packed.pack(body)
	var err := ResourceSaver.save(packed, "res://scenes/props/NPC.tscn")
	print("NPC.tscn saved: ", err)

func _initialize() -> void:
	print("=== NPC + village furniture setup starting ===")
	_build_npc()
	_build_prop("Bookshelf", "res://assets/furniture/bookshelf.png", 32.0, 64.0)
	_build_prop("Barrel", "res://assets/furniture/barrel.png", 32.0, 64.0)
	_build_prop("Cabinet", "res://assets/furniture/cabinet.png", 32.0, 42.0)
	print("=== Setup complete ===")
	quit()
