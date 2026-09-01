extends SceneTree
# Builds Tree.tscn, Rock.tscn, HouseEntrance.tscn, DungeonEntrance.tscn,
# CastleEntrance.tscn — all StaticBody2D scenes with a full-tile collision
# shape and (except the two placeholder-shape entrances) a bottom-anchored
# Sprite2D, matching the JS game's oversized/bottom-anchor sprite convention.
# Run via: godot --headless --script res://tools/setup_props.gd

const TILE := 32.0
const HALF := TILE / 2.0

func _build_sprite_prop(scene_name: String, tex_path: String, src_w: float, src_h: float, scale: float, region: Rect2 = Rect2()) -> void:
	var body := StaticBody2D.new()
	body.name = scene_name

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(tex_path)
	if region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = region
	sprite.scale = Vector2(scale, scale)
	var drawn_h: float = src_h * scale
	sprite.offset = Vector2(0, HALF - drawn_h / 2.0) # bottom-anchored: sprite's bottom sits at the tile's bottom edge
	body.add_child(sprite)
	sprite.owner = body

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE - 4, TILE - 4) # collision stays a single tile even though the sprite overflows visually
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body

	var packed := PackedScene.new()
	packed.pack(body)
	var err := ResourceSaver.save(packed, "res://scenes/props/%s.tscn" % scene_name)
	print(scene_name, ".tscn saved: ", err)

func _build_drawn_prop(scene_name: String, script_path: String) -> void:
	var body := StaticBody2D.new()
	body.name = scene_name
	body.set_script(load(script_path))

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
	print("=== Props setup starting ===")

	DirAccess.make_dir_recursive_absolute("res://scenes/props")

	_build_sprite_prop("Tree", "res://assets/tree.png", 94.0, 80.0, 0.6)
	_build_sprite_prop("Rock", "res://assets/rock.png", 32.0, 32.0, 1.0, Rect2(0, 0, 32, 32))
	_build_sprite_prop("HouseEntrance", "res://assets/house.png", 69.0, 123.0, 0.75)
	_build_drawn_prop("DungeonEntrance", "res://scripts/dungeon_entrance.gd")
	_build_drawn_prop("CastleEntrance", "res://scripts/castle_entrance.gd")

	print("=== Props setup complete ===")
	quit()
