extends SceneTree
# Builds Bed/Chair/ChairBack/Table/Stove/Bookshelf/Barrel/Cabinet/Forge.tscn — same StaticBody2D +
# bottom-anchored Sprite2D convention as tools/setup_props.gd (trees/rocks).
# Run via: godot --headless --script res://tools/setup_house_props.gd

const TILE := 32.0
const HALF := TILE / 2.0

func _build(scene_name: String, tex_path: String, src_w: float, src_h: float, col_w: float = TILE - 4, script_path: String = "") -> void:
	var body := StaticBody2D.new()
	body.name = scene_name
	if script_path != "":
		body.set_script(load(script_path))

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

	# Interactive props (the bed): an area covering the drawn sprite plus a
	# margin, so E works from beside it - same convention as the chest.
	if script_path != "":
		var interact_area := Area2D.new()
		interact_area.name = "InteractArea"
		body.add_child(interact_area)
		interact_area.owner = body
		var interact_shape := CollisionShape2D.new()
		interact_shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(src_w + 40.0, src_h + 40.0)
		interact_shape.shape = rect
		interact_shape.position = Vector2(0, HALF - src_h / 2.0)
		interact_area.add_child(interact_shape)
		interact_shape.owner = body

	var packed := PackedScene.new()
	packed.pack(body)
	var err := ResourceSaver.save(packed, "res://scenes/props/%s.tscn" % scene_name)
	print(scene_name, ".tscn saved: ", err)

func _initialize() -> void:
	print("=== House props setup starting ===")
	_build("Bed", "res://assets/furniture/bed.png", 64.0, 86.0, TILE - 4, "res://scripts/bed.gd") # Leonardo pixel bed, keyed; E = rest (bed.gd)
	_build("Chair", "res://assets/furniture/chair.png", 30.0, 56.0) # Leonardo pixel chair (front view: faces down/toward the viewer)
	_build("Table", "res://assets/furniture/table.png", 70.0, 33.0, 2.0 * TILE - 4) # Leonardo pixel table, keyed; two tiles wide
	_build("Stove", "res://assets/furniture/stove.png", 32.0, 55.0) # Leonardo pixel props, keyed (all of these)
	_build("Bookshelf", "res://assets/furniture/bookshelf.png", 34.0, 72.0)
	_build("Barrel", "res://assets/furniture/barrel.png", 32.0, 40.0)
	_build("Cabinet", "res://assets/furniture/cabinet.png", 40.0, 58.0)
	# Chest.tscn is NOT built here any more: tools/setup_chest_interactive.gd
	# owns it (interact area + script) and a rebuild here clobbered that.
	# The smithy's forge (Leonardo pixel prop, keyed): two tiles wide, so its
	# collider spans both.
	_build("ChairBack", "res://assets/furniture/chair_back.png", 30.0, 45.0) # the same chair seen from behind (faces up/away)
	_build("Forge", "res://assets/furniture/forge.png", 64.0, 93.0, 2.0 * TILE - 4)
	print("=== House props setup complete ===")
	quit()
