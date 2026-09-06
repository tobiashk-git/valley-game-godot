extends CharacterBody2D

const SPEED := 160.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing := "down"

# Worn gear shows on the walking sprite: one overlay AnimatedSprite2D per
# equipment slot listed here, drawn over the base with the SAME frame grid
# (the base and every armour layer come from the Universal LPC generator's
# 9x4 walk sheet, so a torso layer lines up frame for frame). An item opts
# in with a "layer" sheet path in Items.ITEMS; the overlay mirrors the
# base's animation, frame and offset every frame. Step 1 = the body slot;
# the armour-set slots (head/legs/feet) plug in here as they arrive.
const LAYER_SLOTS: Array[String] = ["legs", "feet", "armor", "head"] # draw order: greaves, boots, body, helm on top
var _layers: Dictionary = {} # slot -> AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	for slot in LAYER_SLOTS:
		var layer := AnimatedSprite2D.new()
		layer.name = slot.to_pascal_case() + "Layer"
		layer.centered = sprite.centered
		layer.position = sprite.position
		layer.texture_filter = sprite.texture_filter
		layer.visible = false
		add_child(layer)
		move_child(layer, sprite.get_index() + 1 + _layers.size())
		_layers[slot] = layer
	# Character is a later autoload than some scenes' _ready() under a verify
	# script; defer the hook-up to the end of the frame.
	_connect_layers.call_deferred()

func _connect_layers() -> void:
	Character.changed.connect(_refresh_layers)
	_refresh_layers()

func _refresh_layers() -> void:
	for slot in _layers.keys():
		var layer: AnimatedSprite2D = _layers[slot]
		var inst: Dictionary = Character.equipped(slot)
		var path: String = Items.ITEMS.get(inst.base, {}).get("layer", "") if not inst.is_empty() else ""
		if path == "" or not ResourceLoader.exists(path):
			layer.visible = false
			continue
		if layer.get_meta("layer_path", "") != path:
			layer.sprite_frames = _frames_on(load(path))
			layer.set_meta("layer_path", path)
		layer.visible = true

# The base's SpriteFrames with every atlas region pointed at another sheet.
func _frames_on(sheet: Texture2D) -> SpriteFrames:
	var base: SpriteFrames = sprite.sprite_frames
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in base.get_animation_names():
		frames.add_animation(anim)
		frames.set_animation_speed(anim, base.get_animation_speed(anim))
		frames.set_animation_loop(anim, base.get_animation_loop(anim))
		for i in range(base.get_frame_count(anim)):
			var region: AtlasTexture = base.get_frame_texture(anim, i).duplicate()
			region.atlas = sheet
			frames.add_frame(anim, region, base.get_frame_duration(anim, i))
	return frames

func _process(_delta: float) -> void:
	for layer in _layers.values():
		if not layer.visible:
			continue
		if layer.animation != sprite.animation:
			layer.animation = sprite.animation
		layer.frame = sprite.frame
		layer.offset = sprite.offset
		layer.flip_h = sprite.flip_h

func _physics_process(_delta: float) -> void:
	# Frozen mid-fight, while the defeat panel is up and during the opening.
	if Combat.in_combat or GameState.gathering or get_node("/root/DefeatPanel").is_open() or get_node("/root/Intro").is_playing():
		velocity = Vector2.ZERO
		move_and_slide()
		sprite.play(facing + "_idle")
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * SPEED
	move_and_slide()

	if input_vector.length() > 0.01:
		if abs(input_vector.x) > abs(input_vector.y):
			facing = "right" if input_vector.x > 0 else "left"
		else:
			facing = "down" if input_vector.y > 0 else "up"
		sprite.play(facing)
	else:
		sprite.play(facing + "_idle")
