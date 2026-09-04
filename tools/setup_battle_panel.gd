extends SceneTree
# Builds BattlePanel.tscn — the battle screen on the character sheet's kit
# (UI redesign, combat pass): an enemy STAGE (framed strip, big sprites with
# name + HP bar, a "Choose a target" hint), a battle LOG (dimmed history,
# newest line bright), a row of styled COMMANDS (Attack gold) and a SUBMENU
# of kit-style rows (Magic / Item + Back). Node paths kept from the old
# panel where scripts and verify scripts rely on them:
# Panel/Margin/VBox/{EnemiesRow, LogPanel/LogLabel, Commands, Submenu}.
# Styling from res://resources/ui_theme.tres (tools/setup_theme.gd);
# battle_panel.gd lays out wide vs phone and drives everything. Run via:
# godot --headless --script res://tools/setup_battle_panel.gd

const MAX_ENEMY_SLOTS := 3

func _bar_with_label(name_prefix: String, variation: StringName) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = name_prefix + "Bar"
	bar.custom_minimum_size = Vector2(120, 16)
	bar.show_percentage = false
	bar.theme_type_variation = variation
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.name = name_prefix + "Label"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(label)
	return bar

# A tappable enemy slot: a PanelContainer (so it can wear a gold frame when
# targetable) holding sprite + name + HP bar. Children ignore the mouse so a
# tap reaches the slot's own gui_input (Combat.select_target).
func _build_enemy_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = "EnemySlot%d" % index
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var empty := StyleBoxEmpty.new()
	slot.add_theme_stylebox_override("panel", empty)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_END
	slot.add_child(box)

	var sprite := TextureRect.new()
	sprite.name = "Sprite"
	sprite.custom_minimum_size = Vector2(96, 96)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sprite)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.theme_type_variation = &"PanelTitle"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var bar_box := CenterContainer.new()
	bar_box.name = "BarBox"
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_box.add_child(_bar_with_label("HP", &"HPBar"))
	box.add_child(bar_box)
	return slot

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
	# 560x420, starting at y=148 in the 800x600 base viewport so the HUD's
	# HP/MP column (ends y<=143) stays uncovered; battle_panel.gd sets the
	# offsets for both layouts at runtime.
	panel.position = Vector2(-280, -152)
	panel.size = Vector2(560, 420)
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# --- Stage: framed strip with the enemies and the targeting hint. ---
	var stage := PanelContainer.new()
	stage.name = "Stage"
	stage.theme_type_variation = &"DetailPanel"
	stage.custom_minimum_size = Vector2(0, 176)
	vbox.add_child(stage)
	var stage_box := VBoxContainer.new()
	stage_box.name = "StageBox"
	stage_box.add_theme_constant_override("separation", 2)
	stage.add_child(stage_box)
	var hint := Label.new()
	hint.name = "TargetHint"
	hint.text = "Choose a target"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.theme_type_variation = &"PanelTitle"
	hint.add_theme_font_size_override("font_size", 14)
	hint.custom_minimum_size = Vector2(0, 20)
	hint.modulate.a = 0.0 # keeps its row so the stage never jumps
	stage_box.add_child(hint)
	var enemies_row := HBoxContainer.new()
	enemies_row.name = "EnemiesRow"
	enemies_row.add_theme_constant_override("separation", 8)
	enemies_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_box.add_child(enemies_row)
	for i in range(MAX_ENEMY_SLOTS):
		enemies_row.add_child(_build_enemy_slot(i))

	# --- Battle log. ---
	var log_panel := PanelContainer.new()
	log_panel.name = "LogPanel"
	log_panel.theme_type_variation = &"DetailPanel"
	log_panel.custom_minimum_size = Vector2(0, 96)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(log_panel)
	var log_margin := MarginContainer.new()
	log_margin.name = "LogMargin"
	for side in ["left", "top", "right", "bottom"]:
		log_margin.add_theme_constant_override("margin_%s" % side, 8)
	log_panel.add_child(log_margin)
	var log_label := RichTextLabel.new()
	log_label.name = "LogLabel"
	log_label.bbcode_enabled = true
	log_label.scroll_active = false
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 14)
	log_margin.add_child(log_label)

	# --- Commands. ---
	var commands := HBoxContainer.new()
	commands.name = "Commands"
	commands.add_theme_constant_override("separation", 8)
	vbox.add_child(commands)
	for entry in [["AttackBtn", "Attack", &"PrimaryButton"], ["MagicBtn", "Magic", &"SecondaryButton"], ["ItemBtn", "Item", &"SecondaryButton"], ["DefendBtn", "Defend", &"SecondaryButton"], ["RunBtn", "Run", &"SecondaryButton"]]:
		var btn := Button.new()
		btn.name = entry[0]
		btn.text = entry[1]
		btn.theme_type_variation = entry[2]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 16)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		commands.add_child(btn)

	# --- Submenu (Magic/Item rows + Back), filled by battle_panel.gd. ---
	var submenu := VBoxContainer.new()
	submenu.name = "Submenu"
	submenu.add_theme_constant_override("separation", 6)
	submenu.visible = false
	vbox.add_child(submenu)

	panel.owner = layer
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
