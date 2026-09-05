extends StaticBody2D
# Attached to Tree/Rock — port of tryGather()/nearestResourceTile() in
# game.js: walk near, press E, grants 1 of the resource, depletes after
# `amount` taps and removes itself.
#
# Gathering is a short ACTION now, not a silent counter tick (user: "not
# obvious anything happened"): Oliver turns to face the prop and lunges at
# it twice, the prop shakes on each hit and sheds a few chips (brown for
# wood, grey for stone), and when the swing ends the resource lands with a
# "+1 Wood" popup floating up off the prop. Oliver is held still for the
# swing (GameState.gathering, see player.gd) and a second E during it does
# nothing. A depleted prop shrinks away. Under a verify script (`animated`
# off) the whole thing resolves instantly, popup included, so the older
# verifies' press-E-then-check flow still holds.

@export var item_id := ""
@export var amount := 3

const SWING_SECONDS := 0.5
const LUNGE_PX := 6.0
const CHIP_COLORS := {"wood": Color(0.62, 0.42, 0.22), "stone": Color(0.64, 0.64, 0.66)}

@onready var interact_area: Area2D = $InteractArea
@onready var sprite: Sprite2D = $Sprite2D

var animated := true
var _player_inside := false
var _player: Node2D = null
var _busy := false

func _ready() -> void:
	animated = get_tree().get_script() == null
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_player = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	if _player_inside and not _busy and not GameState.gathering and not Combat.in_combat and not GameState.interact_blocked() and Input.is_action_just_pressed("interact"):
		gather()

func is_busy() -> bool:
	return _busy

# The whole gather: swing (if animated) then the payout.
func gather() -> void:
	_busy = true
	GameState.gathering = true
	if animated and _player != null:
		_face_player()
		_swing()
		await get_tree().create_timer(SWING_SECONDS).timeout
		if not is_inside_tree():
			GameState.gathering = false
			return
	_grant()
	GameState.gathering = false
	_busy = false

# Oliver turns toward the prop.
func _face_player() -> void:
	var d: Vector2 = global_position - _player.global_position
	var facing: String
	if absf(d.x) > absf(d.y):
		facing = "right" if d.x > 0.0 else "left"
	else:
		facing = "down" if d.y > 0.0 else "up"
	_player.facing = facing
	_player.sprite.play(facing + "_idle")

# Two chops: Oliver lunges at the prop, the prop shakes and sheds chips.
func _swing() -> void:
	var dir: Vector2 = (global_position - _player.global_position).normalized()
	var psprite: AnimatedSprite2D = _player.sprite
	var base: Vector2 = psprite.offset
	var lunge := create_tween()
	lunge.tween_property(psprite, "offset", base + dir * LUNGE_PX, 0.1)
	lunge.tween_property(psprite, "offset", base, 0.1)
	lunge.tween_property(psprite, "offset", base + dir * LUNGE_PX, 0.1)
	lunge.tween_property(psprite, "offset", base, 0.1)
	lunge.tween_callback(func() -> void: psprite.offset = base)
	var shake := create_tween()
	shake.tween_interval(0.1)
	for hit in range(2):
		shake.tween_callback(_chips)
		shake.tween_property(sprite, "position:x", 3.0, 0.04)
		shake.tween_property(sprite, "position:x", -3.0, 0.04)
		shake.tween_property(sprite, "position:x", 0.0, 0.04)
		shake.tween_interval(0.08)

# One hit's worth of feedback: the sound and the chips.
func _hit_sound() -> void:
	Audio.play_sfx("chop" if item_id == "wood" else "mine")

func _chips() -> void:
	_hit_sound()
	var p := CPUParticles2D.new()
	p.name = "Chips"
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 120.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = CHIP_COLORS.get(item_id, Color(0.7, 0.7, 0.7))
	p.position = sprite.position + sprite.offset
	p.z_index = 1
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())

func _grant() -> void:
	if not animated:
		_hit_sound() # no swing to carry it
	Inventory.add_item(item_id, 1)
	amount -= 1
	_popup()
	if amount <= 0:
		_deplete()

# "+1 [icon] Wood" rising off the prop; parented beside the prop so it
# outlives a depleted one.
func _popup() -> void:
	var node := Node2D.new()
	node.name = "GatherPopup"
	node.z_index = 20
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Items.get_item_icon(item_id)
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.name = "Text"
	label.text = "+1 %s" % Items.get_item_name(item_id)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	row.position = Vector2(-30, -12)
	node.add_child(row)
	var home: Node = get_parent() if get_parent() != null else self
	home.add_child(node)
	node.global_position = global_position + sprite.offset + Vector2(0, -20)
	var t := node.create_tween()
	t.tween_property(node, "position:y", node.position.y - 28.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "modulate:a", 0.0, 1.0).set_delay(0.4)
	t.tween_callback(node.queue_free)

func _deplete() -> void:
	interact_area.set_deferred("monitoring", false)
	_player_inside = false
	if not animated:
		queue_free()
		return
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2(0.05, 0.05), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
