extends SceneTree
# Rebuilds every painted entrance scene (gates and the five interiors) with
# their Leonardo art and a solid footprint from the sprite's top down to the
# tile's bottom edge - the same rule as the houses, so the 56x56 entrance
# portal stays reachable from below. Run via:
#   godot --headless --script res://tools/setup_entrance_sprites.gd
# (tools/setup_props.gd builds the same scenes when everything is rebuilt.)

const TILE := 32.0
const HALF := TILE / 2.0
const ENTRANCES := [
	{"scene": "DungeonEntrance", "tex": "res://assets/dungeon_entrance.png", "w": 176.0, "h": 134.0},
	{"scene": "CastleEntrance", "tex": "res://assets/castle_entrance.png", "w": 192.0, "h": 177.0},
	{"scene": "WatchtowerRuinEntrance", "tex": "res://assets/entrance_ice_caves.png", "w": 176.0, "h": 145.0},
	{"scene": "DruidCircleEntrance", "tex": "res://assets/entrance_grove.png", "w": 192.0, "h": 223.0},
	{"scene": "VolcanoEntrance", "tex": "res://assets/entrance_caldera.png", "w": 192.0, "h": 147.0},
	{"scene": "SubmergedTempleEntrance", "tex": "res://assets/entrance_temple.png", "w": 176.0, "h": 169.0},
	{"scene": "AncientBarrowEntrance", "tex": "res://assets/entrance_barrow.png", "w": 160.0, "h": 111.0},
]

func _initialize() -> void:
	for e in ENTRANCES:
		var body := StaticBody2D.new()
		body.name = e.scene
		body.z_index = 1
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = load(e.tex)
		sprite.offset = Vector2(0, HALF - e.h / 2.0)
		body.add_child(sprite)
		sprite.owner = body
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		var top: float = sprite.offset.y - e.h / 2.0
		shape.size = Vector2(e.w - 2.0, HALF - top)
		collision.position = Vector2(0, (top + HALF) / 2.0)
		collision.shape = shape
		body.add_child(collision)
		collision.owner = body
		var packed := PackedScene.new()
		packed.pack(body)
		print(e.scene, ".tscn saved: ", ResourceSaver.save(packed, "res://scenes/props/%s.tscn" % e.scene))
	quit()
