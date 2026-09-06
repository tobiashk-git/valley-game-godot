extends SceneTree
# Builds TouchControls.tscn - the virtual joystick + interact button for
# phone play (see scripts/touch_controls.gd for the input logic). Generates
# 3 simple placeholder circle textures via the Image API (no external art
# needed, same "logic + placeholder, real art later" pattern used
# throughout this project). Run via:
# godot --headless --script res://tools/setup_touch_controls.gd

# Returns an in-memory ImageTexture rather than load()-ing a saved PNG - a
# freshly-written file has no .import metadata yet within this same script
# run (Godot's import pipeline is a separate pass), so load() fails with
# "No loader found for resource". Building the texture directly in memory
# and letting ResourceSaver embed it in the .tscn sidesteps that entirely -
# no external asset file needed for these placeholders.
func _make_circle_texture(radius: int, color: Color) -> ImageTexture:
	var size := radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(radius, radius)
	for y in range(size):
		for x in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

func _build_touch_controls() -> void:
	var base_tex := _make_circle_texture(75, Color(1, 1, 1, 0.25))
	var knob_tex := _make_circle_texture(32, Color(1, 1, 1, 0.5))
	var interact_tex := _make_circle_texture(40, Color(0.9, 0.75, 0.35, 0.6))

	var layer := CanvasLayer.new()
	layer.name = "TouchControls"
	layer.set_script(load("res://scripts/touch_controls.gd"))

	# Joystick base: bottom-left, matching touch_controls.gd's JOYSTICK_CENTER
	# (80, 520) and JOYSTICK_RADIUS (50) - a 100x100 box with margin from
	# the true screen corner for comfortable thumb reach.
	var joystick_base := TextureRect.new()
	joystick_base.name = "JoystickBase"
	joystick_base.texture = base_tex
	joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.position = Vector2(24, -174)
	joystick_base.size = Vector2(150, 150)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(joystick_base)
	joystick_base.owner = layer

	var joystick_knob := TextureRect.new()
	joystick_knob.name = "Knob"
	joystick_knob.texture = knob_tex
	joystick_knob.position = Vector2(43, 43) # centered within the 150x150 base at rest
	joystick_knob.size = Vector2(64, 64)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joystick_knob)
	joystick_knob.owner = layer

	# Interact button: bottom-right, a native TouchScreenButton bound
	# directly to the "interact" action - no script wiring needed for the
	# press/release itself, it does that on its own while touched.
	var interact_button := TouchScreenButton.new()
	interact_button.name = "InteractButton"
	interact_button.texture_normal = interact_tex
	interact_button.action = "interact"
	interact_button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	interact_button.position = Vector2(680, 470)
	layer.add_child(interact_button)
	interact_button.owner = layer

	var interact_label := Label.new()
	interact_label.text = "E"
	interact_label.add_theme_font_size_override("font_size", 28)
	interact_label.position = Vector2(28, 22)
	interact_button.add_child(interact_label)
	interact_label.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/TouchControls.tscn")
	print("TouchControls.tscn saved: ", err)

func _initialize() -> void:
	print("=== Touch controls setup starting ===")
	_build_touch_controls()
	print("=== Setup complete ===")
	quit()
