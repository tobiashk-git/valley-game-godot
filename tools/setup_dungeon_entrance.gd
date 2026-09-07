extends SceneTree
# Rebuilds only scenes/props/DungeonEntrance.tscn with the real gate art
# (assets/dungeon_entrance.png, 176x134) and a solid footprint from the
# rock top down to the tile's bottom edge - the same rule as the houses, so
# the 56x56 entrance portal stays reachable from below. Run via:
#   godot --headless --script res://tools/setup_dungeon_entrance.gd
# (tools/setup_props.gd builds the same thing when everything is rebuilt.)

const TILE := 32.0
const HALF := TILE / 2.0

func _initialize() -> void:
	var src_w := 176.0
	var src_h := 134.0
	var body := StaticBody2D.new()
	body.name = "DungeonEntrance"
	body.z_index = 1
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/dungeon_entrance.png")
	sprite.offset = Vector2(0, HALF - src_h / 2.0)
	body.add_child(sprite)
	sprite.owner = body
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	var top: float = sprite.offset.y - src_h / 2.0
	shape.size = Vector2(src_w - 2.0, HALF - top)
	collision.position = Vector2(0, (top + HALF) / 2.0)
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body
	var packed := PackedScene.new()
	packed.pack(body)
	print("DungeonEntrance.tscn saved: ", ResourceSaver.save(packed, "res://scenes/props/DungeonEntrance.tscn"))
	quit()
