extends SceneTree
# Rebuilds Tree.tscn and Rock.tscn with an added InteractArea + gatherable.gd
# so they can be gathered (walk near, press E) — same bottom-anchored sprite
# construction as tools/setup_props.gd, just with the extra interaction bits.
# Run via: godot --headless --script res://tools/setup_gatherables.gd

const TILE := 32.0
const HALF := TILE / 2.0

func _build(scene_name: String, tex_path: String, src_w: float, src_h: float, scale: float, item_id: String, amount: int, region: Rect2 = Rect2()) -> void:
	var body := StaticBody2D.new()
	body.name = scene_name
	body.z_index = 1 # matches setup_props.gd's default for every prop that stands
	# proud of the ground (see tools/setup_props.gd) - Tree/Rock need the same
	# explicit value here since this script rebuilds them independently rather
	# than layering on top of setup_props.gd's output.
	body.set_script(load("res://scripts/gatherable.gd"))
	body.item_id = item_id
	body.amount = amount

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(tex_path)
	if region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = region
	sprite.scale = Vector2(scale, scale)
	var drawn_h: float = src_h * scale
	sprite.offset = Vector2(0, HALF - drawn_h / 2.0)
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
	var err := ResourceSaver.save(packed, "res://scenes/props/%s.tscn" % scene_name)
	print(scene_name, ".tscn saved: ", err)

func _initialize() -> void:
	print("=== Gatherables setup starting ===")
	_build("Tree", "res://assets/tree.png", 94.0, 80.0, 0.6, "wood", 3)
	_build("Rock", "res://assets/rock.png", 32.0, 32.0, 1.0, "stone", 3, Rect2(0, 0, 32, 32))
	print("=== Gatherables setup complete ===")
	quit()
