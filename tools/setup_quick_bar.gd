extends SceneTree
# Builds QuickBar.tscn - the bottom-centre quick-access row of usable
# consumables (see scripts/quick_bar.gd, which builds the slots themselves at
# runtime from Items.ITEMS so this scene only needs the anchored containers).
# Run via: godot --headless --script res://tools/setup_quick_bar.gd
# (then godot --headless --import once so the new script's .uid exists).

func _build() -> void:
	var layer := CanvasLayer.new()
	layer.name = "QuickBar"
	layer.set_script(load("res://scripts/quick_bar.gd"))

	# Anchored to the bottom-centre; quick_bar.gd offsets it left by half its
	# own width once the slots exist, so it stays centred whatever the
	# viewport width (keep_width means that's fixed at 800 anyway) and
	# tracks the bottom edge on tall phone viewports.
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hbox.add_theme_constant_override("separation", 8)
	layer.add_child(hbox)
	hbox.owner = layer

	# One-line "Oliver uses ... and recovers 15 HP!" toast above the row,
	# faded in/out by quick_bar.gd.
	var feedback := Label.new()
	feedback.name = "FeedbackLabel"
	feedback.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	feedback.add_theme_font_size_override("font_size", 14)
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(feedback)
	feedback.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/QuickBar.tscn")
	print("QuickBar.tscn saved: ", err)

func _initialize() -> void:
	print("=== Quick bar setup starting ===")
	_build()
	print("=== Setup complete ===")
	quit()
