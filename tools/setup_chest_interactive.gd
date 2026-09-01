extends SceneTree
# Rebuilds Chest.tscn with an added InteractArea + chest.gd so it opens
# StoragePanel (walk near, press E) — same construction as
# tools/setup_gatherables.gd, just pointed at chest.gd/chest.png.
# Run via: godot --headless --script res://tools/setup_chest_interactive.gd

const TILE := 32.0
const HALF := TILE / 2.0

func _build() -> void:
	var body := StaticBody2D.new()
	body.name = "Chest"
	body.set_script(load("res://scripts/chest.gd"))

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/chest.png")
	sprite.offset = Vector2(0, HALF - 32.0 / 2.0)
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
	var err := ResourceSaver.save(packed, "res://scenes/props/Chest.tscn")
	print("Chest.tscn saved: ", err)

func _initialize() -> void:
	print("=== Interactive chest setup starting ===")
	_build()
	print("=== Setup complete ===")
	quit()
