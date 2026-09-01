extends SceneTree
# Verifies the virtual joystick presses/releases the right move_* actions
# as it's dragged, and that the interact TouchScreenButton presses
# "interact" while held. Run via:
# godot --script res://tools/verify_touch_controls.gd (NOT --headless -
# DisplayServer.is_touchscreen_available() and real rendering both need it).

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var touch_controls: Node = root.get_node("TouchControls")
	print("Touchscreen available on this dev machine (expected false): ", DisplayServer.is_touchscreen_available())
	# This machine has no touchscreen, so _ready() already hid/disabled input
	# processing - force it on to exercise the joystick/button logic anyway,
	# same as every other verify script bypasses auto-derived state to test
	# a specific path directly.
	touch_controls.visible = true
	touch_controls.set_process_input(true)
	touch_controls.set_process(true)

	# --- Camera zoom-in on touch devices (the "felt zoomed out" fix). ---
	var cam: Camera2D = overworld.get_node("YSort/Player/Camera2D")
	await process_frame
	print("Camera zoomed in once touch controls are active: ", cam.zoom == touch_controls.MOBILE_ZOOM)

	# --- Drag the joystick straight down - should press move_down only. ---
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.position = touch_controls._joystick_center()
	touch_down.pressed = true
	Input.parse_input_event(touch_down)
	await process_frame
	print("move_down NOT pressed yet (joystick centered): ", not Input.is_action_pressed("move_down"))

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = touch_controls._joystick_center() + Vector2(0, 45)
	Input.parse_input_event(drag)
	await process_frame
	print("move_down pressed after dragging down: ", Input.is_action_pressed("move_down"))
	print("move_up/left/right NOT pressed: ", not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"))

	# --- Diagonal drag (down-right) - should press both move_down and move_right. ---
	var drag_diag := InputEventScreenDrag.new()
	drag_diag.index = 0
	drag_diag.position = touch_controls._joystick_center() + Vector2(35, 35)
	Input.parse_input_event(drag_diag)
	await process_frame
	print("Diagonal drag presses both move_down and move_right: ", Input.is_action_pressed("move_down") and Input.is_action_pressed("move_right"))

	# --- Release - all directions should clear. ---
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.position = touch_controls._joystick_center() + Vector2(35, 35)
	touch_up.pressed = false
	Input.parse_input_event(touch_up)
	await process_frame
	print("Releasing clears all movement: ", not Input.is_action_pressed("move_down") and not Input.is_action_pressed("move_right"))

	# --- Interact button position tracks the actual viewport (the
	# window/stretch/aspect="expand" fix) rather than a stale fixed spot. ---
	var interact_button: TouchScreenButton = touch_controls.get_node("InteractButton")
	touch_controls._position_interact_button()
	var expected_pos: Vector2 = root.get_visible_rect().size - touch_controls.INTERACT_MARGIN
	print("Interact button repositions against the real viewport size: ", interact_button.position == expected_pos)

	# --- Interact button: press and hold via its own touch point. ---
	var interact_pos: Vector2 = interact_button.position + Vector2(40, 40) # texture is 80x80, roughly centered
	var touch_interact_down := InputEventScreenTouch.new()
	touch_interact_down.index = 1
	touch_interact_down.position = interact_pos
	touch_interact_down.pressed = true
	Input.parse_input_event(touch_interact_down)
	await process_frame
	print("Interact button press activates the 'interact' action: ", Input.is_action_pressed("interact"))

	var touch_interact_up := InputEventScreenTouch.new()
	touch_interact_up.index = 1
	touch_interact_up.position = interact_pos
	touch_interact_up.pressed = false
	Input.parse_input_event(touch_interact_up)
	await process_frame
	print("Releasing the interact button clears it: ", not Input.is_action_pressed("interact"))

	quit()
