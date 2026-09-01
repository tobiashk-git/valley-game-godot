extends CanvasLayer
# Autoload — a virtual joystick (bottom-left, drag-anywhere-in-a-zone,
# thumb-relative) plus an interact button (bottom-right, a TouchScreenButton
# bound directly to the "interact" action) for phone play. Reuses the exact
# same move_up/down/left/right actions WASD already presses via
# Input.action_press()/release() - zero changes needed anywhere else, same
# technique this project's own verify_*.gd scripts already use to simulate
# input. Only visible/active when a touchscreen is actually present, so
# desktop play (keyboard, mouse-clickable UI) is completely unaffected.

const JOYSTICK_CENTER := Vector2(80, 520)
const JOYSTICK_RADIUS := 50.0
const JOYSTICK_DEADZONE := 10.0
const JOYSTICK_ANGLE_THRESHOLD := 0.35 # dot-product-ish threshold per axis, allows diagonals

@onready var joystick_base: Control = $JoystickBase
@onready var joystick_knob: Control = $JoystickBase/Knob

var _joystick_touch_index := -1
var _active_directions: Array[String] = []

func _ready() -> void:
	var touch_available := DisplayServer.is_touchscreen_available()
	visible = touch_available
	set_process_input(touch_available)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _joystick_touch_index == -1 and event.position.distance_to(JOYSTICK_CENTER) <= JOYSTICK_RADIUS * 2.0:
				_joystick_touch_index = event.index
				_update_joystick(event.position)
		elif event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_reset_joystick()
	elif event is InputEventScreenDrag and event.index == _joystick_touch_index:
		_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var delta: Vector2 = touch_pos - JOYSTICK_CENTER
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
