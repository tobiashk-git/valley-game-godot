extends SceneTree
# Builds Bed/Chair/Table/Stove/Chest.tscn — same StaticBody2D +
# bottom-anchored Sprite2D convention as tools/setup_props.gd (trees/rocks).
# Run via: godot --headless --script res://tools/setup_house_props.gd

const TILE := 32.0
const HALF := TILE / 2.0

func _build(scene_name: String, tex_path: String, src_w: float, src_h: float) -> void:
	var body := StaticBody2D.new()
	body.name = scene_name

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(tex_path)
	sprite.offset = Vector2(0, HALF - src_h / 2.0) # bottom-anchored
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

func _initialize() -> void:
	print("=== House props setup starting ===")
	_build("Bed", "res://assets/furniture/bed.png", 64.0, 128.0)
	_build("Chair", "res://assets/furniture/chair.png", 32.0, 32.0)
	_build("Table", "res://assets/furniture/table.png", 66.0, 45.0)
	_build("Stove", "res://assets/furniture/stove.png", 32.0, 36.0)
	_build("Chest", "res://assets/chest.png", 32.0, 32.0)
	print("=== House props setup complete ===")
	quit()
