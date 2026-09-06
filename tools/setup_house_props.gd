extends SceneTree
# Builds Bed/Chair/Table/Stove/Forge.tscn — same StaticBody2D +
# bottom-anchored Sprite2D convention as tools/setup_props.gd (trees/rocks).
# Run via: godot --headless --script res://tools/setup_house_props.gd

const TILE := 32.0
const HALF := TILE / 2.0

func _build(scene_name: String, tex_path: String, src_w: float, src_h: float, col_w: float = TILE - 4) -> void:
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
	shape.size = Vector2(col_w, TILE - 4)
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body

	var packed := PackedScene.new()
	packed.pack(body)
	var err := ResourceSaver.save(packed, "res://scenes/props/%s.tscn" % scene_name)
	print(scene_name, ".tscn saved: ", err)

func _initialize() -> void:
	print("=== House props setup starting ===")
	_build("Bed", "res://assets/furniture/bed.png", 64.0, 86.0) # Leonardo pixel bed, keyed (was the 64x128 placeholder)
	_build("Chair", "res://assets/furniture/chair.png", 32.0, 32.0)
	_build("Table", "res://assets/furniture/table.png", 70.0, 33.0, 2.0 * TILE - 4) # Leonardo pixel table, keyed; two tiles wide
	_build("Stove", "res://assets/furniture/stove.png", 32.0, 36.0)
	# Chest.tscn is NOT built here any more: tools/setup_chest_interactive.gd
	# owns it (interact area + script) and a rebuild here clobbered that.
	# The smithy's forge (Leonardo pixel prop, keyed): two tiles wide, so its
	# collider spans both.
	_build("Forge", "res://assets/furniture/forge.png", 64.0, 93.0, 2.0 * TILE - 4)
	print("=== House props setup complete ===")
	quit()
