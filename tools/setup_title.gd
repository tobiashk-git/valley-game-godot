extends SceneTree
# Builds Title.tscn - the game's front door (project main scene): a dimmed
# rendered map of the valley behind a dark vignette, the title, Oliver's
# illustration, and Continue / New Game. Skeleton only; scripts/title.gd
# fills the map, the save line, button states and the wide/phone layout.
# Run via: godot --headless --script res://tools/setup_title.gd

func _label(parent: Node, name: String, text: String, size_px: int, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.name = name
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	if variation != &"":
		l.theme_type_variation = variation
	parent.add_child(l)
	return l

func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)

func _initialize() -> void:
	print("=== Title setup starting ===")
	var root_node := Control.new()
	root_node.name = "Title"
	root_node.set_script(load("res://scripts/title.gd"))
	root_node.set_anchors_preset(Control.PRESET_FULL_RECT)

	var map := TextureRect.new()
	map.name = "MapBackground"
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.modulate = Color(0.55, 0.55, 0.55)
	root_node.add_child(map)

	var vignette := ColorRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.05, 0.04, 0.03, 0.35)
	root_node.add_child(vignette)

	var figure := TextureRect.new()
	figure.name = "Figure"
	figure.texture = load("res://assets/oliver_portrait.png")
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root_node.add_child(figure)

	var panel := Panel.new()
	panel.name = "MenuPanel"
	root_node.add_child(panel)
	var title := _label(panel, "TitleLabel", "Valley of Adventure", 32, &"PanelTitle")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tagline := _label(panel, "Tagline", "A small valley with a lot going on.", 14, &"DimLabel")
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 10)
	panel.add_child(buttons)
	for entry in [["ContinueBtn", "Continue", &"PrimaryButton"], ["NewGameBtn", "New Game", &"SecondaryButton"]]:
		var b := Button.new()
		b.name = entry[0]
		b.text = entry[1]
		b.theme_type_variation = entry[2]
		b.custom_minimum_size = Vector2(280, 52)
		b.add_theme_font_size_override("font_size", 19)
		buttons.add_child(b)
	var save_line := _label(panel, "SaveLine", "", 13, &"DimLabel")
	save_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	var version := _label(root_node, "VersionLabel", "", 11, &"DimLabel")
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_own(root_node, root_node)
	var packed := PackedScene.new()
	packed.pack(root_node)
	print("Title.tscn saved: ", ResourceSaver.save(packed, "res://scenes/Title.tscn"))
	print("=== Setup complete ===")
	quit()
