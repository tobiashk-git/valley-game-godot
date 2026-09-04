extends SceneTree
# Patches HouseEntrance.tscn's collider to cover the house's whole drawn
# footprint instead of the single tile every sprite prop gets from
# tools/setup_props.gd's _build_sprite_prop(). Fine for a narrow tree (you
# walk behind it, it hides you - expected), wrong for the new ~3-tile-wide
# cottage: the player could step into the drawn wall from the sides/back
# and get Y-sorted behind it (user report). Standalone patch rather than a
# full setup_props.gd re-run (which would regress Tree/Rock's gathering, see
# that file's own header) - setup_props.gd carries the same rule via its
# solid_footprint flag so a deliberate rebuild keeps it. Run via:
# godot --headless --script res://tools/setup_house_collision.gd

const SCENE := "res://scenes/props/HouseEntrance.tscn"
const HALF := 16.0

func _initialize() -> void:
	var packed: PackedScene = load(SCENE)
	var root: StaticBody2D = packed.instantiate()
	var sprite: Sprite2D = root.get_node("Sprite2D")
	var collision: CollisionShape2D = root.get_node("CollisionShape2D")
	var rect := solid_footprint_rect(sprite)
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.get_center()
	print("HouseEntrance collider -> size ", rect.size, " centre ", rect.get_center())
	var out := PackedScene.new()
	out.pack(root)
	print(SCENE, " saved: ", ResourceSaver.save(out, SCENE))
	quit()

# The drawn sprite's rect from its top edge down to the TILE's bottom edge
# (HALF): the sprite itself runs a few px past that (its doorstep/grass
# fringe), which stays walkable so the player still reaches the entrance
# portal's 56px zone from below exactly as before. Width trimmed by 2px so
# the block doesn't graze the neighbouring tile column.
static func solid_footprint_rect(sprite: Sprite2D) -> Rect2:
	var drawn: Vector2 = sprite.texture.get_size() * sprite.scale
	var top: float = sprite.offset.y * sprite.scale.y - drawn.y / 2.0
	return Rect2(-drawn.x / 2.0 + 1.0, top, drawn.x - 2.0, HALF - top)
