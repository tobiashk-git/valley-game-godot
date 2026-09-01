extends CanvasLayer
# Autoload — a virtual joystick (bottom-left, drag-anywhere-in-a-zone,
# thumb-relative) plus an interact button (bottom-right, a TouchScreenButton
# bound directly to the "interact" action) for phone play. Reuses the exact
# same move_up/down/left/right actions WASD already presses via
# Input.action_press()/release() - zero changes needed anywhere else, same
# technique this project's own verify_*.gd scripts already use to simulate
# input. Only visible/active when a touchscreen is actually present, so
# desktop play (keyboard, mouse-clickable UI) is completely unaffected.

const JOYSTICK_RADIUS := 50.0
const JOYSTICK_DEADZONE := 10.0
const JOYSTICK_ANGLE_THRESHOLD := 0.35 # dot-product-ish threshold per axis, allows diagonals

# window/stretch/aspect="keep_width" keeps the horizontal FOV matching
# desktop exactly, but a portrait phone still shows a lot more world
# vertically than a 600-tall desktop view - felt "zoomed out" on a real
# device. A modest zoom-in tightens the view back up on touch devices only;
# desktop is untouched since Camera2D.zoom is never set there.
const MOBILE_ZOOM := Vector2(1.4, 1.4)

@onready var joystick_base: Control = $JoystickBase
@onready var joystick_knob: Control = $JoystickBase/Knob
@onready var interact_button: TouchScreenButton = $InteractButton

# Margin from the true bottom-right corner, matching the builder's original
# fixed position (680, 470) in the 800x600 base - 800-680=120, 600-470=130.
const INTERACT_MARGIN := Vector2(120, 130)

var _joystick_touch_index := -1
var _active_directions: Array[String] = []
var _zoomed_camera: Camera2D = null

func _ready() -> void:
	var touch_available := DisplayServer.is_touchscreen_available()
	visible = touch_available
	set_process_input(touch_available)
	set_process(touch_available)
	if touch_available:
		_position_interact_button()
		get_viewport().size_changed.connect(_position_interact_button)

# Every scene builds its own Camera2D in its own _ready() (Overworld, House,
# Dungeon, etc.) - rather than touching every one of those scripts, just
# watch for whichever camera is currently active and zoom it in once, the
# first time this sees a new one (i.e. once per scene change).
func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam != _zoomed_camera:
		_zoomed_camera = cam
		cam.zoom = MOBILE_ZOOM

# TouchScreenButton is a Node2D, not a Control - it has no anchor preset to
# lean on like the joystick's BOTTOM_LEFT-anchored base, so its bottom-right
# position has to be recomputed by hand against the actual viewport size.
# Needed because window/stretch/aspect="expand" means that size varies by
# device (a tall phone shows more world than the base 800x600) and can
# change again on an orientation flip, hence the size_changed hook too.
func _position_interact_button() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	interact_button.position = viewport_size - INTERACT_MARGIN

# Computed from the base's actual on-screen rect rather than a fixed
# constant - window/stretch/aspect="expand" means the effective viewport
# size varies by device (a tall phone shows more world than the base
# 800x600), and the joystick's BOTTOM_LEFT anchor already tracks that
# correctly, so touch-position math needs to track it too instead of
# assuming a stale fixed coordinate.
func _joystick_center() -> Vector2:
	return joystick_base.global_position + joystick_base.size / 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _joystick_touch_index == -1 and event.position.distance_to(_joystick_center()) <= JOYSTICK_RADIUS * 2.0:
				_joystick_touch_index = event.index
				_update_joystick(event.position)
		elif event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_reset_joystick()
	elif event is InputEventScreenDrag and event.index == _joystick_touch_index:
		_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var delta: Vector2 = touch_pos - _joystick_center()
	var dist: float = min(delta.length(), JOYSTICK_RADIUS)
	var dir: Vector2 = delta.normalized() if delta.length() > 0.0 else Vector2.ZERO
	joystick_knob.position = dir * dist - joystick_knob.size / 2.0

	var new_directions: Array[String] = []
	if delta.length() > JOYSTICK_DEADZONE:
		if dir.y < -JOYSTICK_ANGLE_THRESHOLD:
			new_directions.append("move_up")
		if dir.y > JOYSTICK_ANGLE_THRESHOLD:
			new_directions.append("move_down")
		if dir.x < -JOYSTICK_ANGLE_THRESHOLD:
			new_directions.append("move_left")
		if dir.x > JOYSTICK_ANGLE_THRESHOLD:
			new_directions.append("move_right")

	for action in ["move_up", "move_down", "move_left", "move_right"]:
		var now_active: bool = new_directions.has(action)
		var was_active: bool = _active_directions.has(action)
		if now_active and not was_active:
			Input.action_press(action)
		elif was_active and not now_active:
			Input.action_release(action)
	_active_directions = new_directions

func _reset_joystick() -> void:
	joystick_knob.position = -joystick_knob.size / 2.0
	for action in _active_directions:
		Input.action_release(action)
	_active_directions = []
