extends SceneTree
# Builds BattlePanel.tscn — full-screen battle UI (Combat Phase 1+2: Attack/
# Magic/Item/Defend/Run). Panel background/title/bar styling come from the
# shared res://resources/ui_theme.tres (project default theme) - see
# tools/setup_theme.gd. Run via:
# godot --headless --script res://tools/setup_battle_panel.gd

func _bar_with_label(name_prefix: String, variation: StringName) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = name_prefix + "Bar"
	bar.custom_minimum_size = Vector2(0, 22)
	bar.show_percentage = false
	bar.theme_type_variation = variation
	var label := Label.new()
	label.name = name_prefix + "Label"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	bar.add_child(label)
	return bar

func _own(node: Node, layer: Node) -> void:
	for child in node.get_children():
		child.owner = layer
		_own(child, layer)

func _build_battle_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BattlePanel"
	layer.set_script(load("res://scripts/battle_panel.gd"))

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -190)
	panel.size = Vector2(440, 380)
	layer.add_child(panel)
	panel.owner = layer

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Enemy row: sprite + name/HP.
	var enemy_row := HBoxContainer.new()
	enemy_row.name = "EnemyRow"
	enemy_row.add_theme_constant_override("separation", 12)
	vbox.add_child(enemy_row)

	var enemy_sprite := TextureRect.new()
	enemy_sprite.name = "EnemySprite"
	enemy_sprite.custom_minimum_size = Vector2(64, 64)
	enemy_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_row.add_child(enemy_sprite)

	var enemy_info := VBoxContainer.new()
	enemy_info.name = "EnemyInfo"
	enemy_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_row.add_child(enemy_info)

	var enemy_name := Label.new()
	enemy_name.name = "EnemyName"
	enemy_name.theme_type_variation = &"PanelTitle"
	enemy_info.add_child(enemy_name)

	var enemy_hp_bar := _bar_with_label("EnemyHP", &"HPBar")
	enemy_info.add_child(enemy_hp_bar)

	# Player row: HP + MP bars stacked.
	var player_row := VBoxContainer.new()
	player_row.name = "PlayerRow"
	player_row.add_theme_constant_override("separation", 4)
	vbox.add_child(player_row)

	var player_hp_bar := _bar_with_label("PlayerHP", &"HPBar")
	player_row.add_child(player_hp_bar)

	var player_mp_bar := _bar_with_label("PlayerMP", &"MPBar")
	player_row.add_child(player_mp_bar)

	# Active status badges (poison/paralysis/sleep/confusion/silence) - built
	# dynamically by battle_panel.gd, empty at build time.
	var status_row := HBoxContainer.new()
	status_row.name = "StatusRow"
	status_row.add_theme_constant_override("separation", 8)
	player_row.add_child(status_row)

	# Battle log.
	var log_panel := PanelContainer.new()
	log_panel.name = "LogPanel"
	log_panel.custom_minimum_size = Vector2(0, 110)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(log_panel)

	var log_label := Label.new()
	log_label.name = "LogLabel"
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.add_theme_font_size_override("font_size", 14)
	log_panel.add_child(log_label)

	# Commands.
	var commands := HBoxContainer.new()
	commands.name = "Commands"
	commands.add_theme_constant_override("separation", 8)
	vbox.add_child(commands)

	for entry in [["AttackBtn", "Attack"], ["MagicBtn", "Magic"], ["ItemBtn", "Item"], ["DefendBtn", "Defend"], ["RunBtn", "Run"]]:
		var btn := Button.new()
		btn.name = entry[0]
		btn.text = entry[1]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		commands.add_child(btn)

	# Submenu (Magic/Item row list + Back), built dynamically by
	# battle_panel.gd - hidden and empty at build time.
	var submenu := VBoxContainer.new()
	submenu.name = "Submenu"
	submenu.add_theme_constant_override("separation", 4)
	submenu.visible = false
	vbox.add_child(submenu)

	_own(panel, layer)

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/BattlePanel.tscn")
	print("BattlePanel.tscn saved: ", err)

func _initialize() -> void:
	print("=== Battle panel setup starting ===")
	_build_battle_panel()
	print("=== Setup complete ===")
	quit()
