extends SceneTree
# Builds DefeatPanel.tscn - the death sequence overlay (see
# scripts/defeat_panel.gd): a full-screen black ColorRect for the fade and
# a centred kit panel with title, story text and a Wake up button.
# Positions are placeholders; the script lays out wide/phone at runtime.
# Run via: godot --headless --script res://tools/setup_defeat_panel.gd

func _initialize() -> void:
	print("=== Defeat panel setup starting ===")
	var layer := CanvasLayer.new()
	layer.name = "DefeatPanel"
	layer.set_script(load("res://scripts/defeat_panel.gd"))

	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(black)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -130)
	panel.size = Vector2(440, 260)
	layer.add_child(panel)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "You were defeated"
	title.theme_type_variation = &"PanelTitle"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 16)
	title.size = Vector2(440, 30)
	panel.add_child(title)

	var body := Label.new()
	body.name = "BodyLabel"
	body.add_theme_font_size_override("font_size", 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.position = Vector2(20, 54)
	body.size = Vector2(400, 120)
	panel.add_child(body)

	var wake := Button.new()
	wake.name = "WakeBtn"
	wake.text = "Wake up"
	wake.theme_type_variation = &"PrimaryButton"
	wake.add_theme_font_size_override("font_size", 17)
	wake.position = Vector2(110, 196)
	wake.size = Vector2(220, 44)
	panel.add_child(wake)

	for child in [black, panel, title, body, wake]:
		child.owner = layer
	var packed := PackedScene.new()
	packed.pack(layer)
	print("DefeatPanel.tscn saved: ", ResourceSaver.save(packed, "res://scenes/DefeatPanel.tscn"))
	print("=== Setup complete ===")
	quit()
