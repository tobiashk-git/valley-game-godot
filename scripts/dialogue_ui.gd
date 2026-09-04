extends CanvasLayer
# Autoload — a dialogue box (name + text, press E to close). Plain greetings
# pass no actions and behave exactly as before; a quest offer/turn-in passes
# 1+ {"label": String, "callback": Callable} actions, which replace the
# "press E to close" hint with clickable buttons - same dynamic-row pattern
# as battle_panel.gd's submenu. E still closes either way (equivalent to
# picking no action), so it's never a dead end.

@onready var panel: Panel = $Panel
@onready var margin: MarginContainer = $Panel/Margin
@onready var name_label: Label = $Panel/Margin/VBox/NameLabel
@onready var text_label: RichTextLabel = $Panel/Margin/VBox/TextLabel
@onready var hint_label: Label = $Panel/Margin/VBox/HintLabel
@onready var actions_row: HBoxContainer = $Panel/Margin/VBox/ActionsRow

var _ignore_close_this_frame := false

func _ready() -> void:
	panel.visible = false
	# Process after interactables (npc.gd etc, default priority 0) so a
	# close-press is seen by them as "still open" this frame and they don't
	# immediately reopen what this same press just closed.
	process_priority = 10

func is_open() -> bool:
	return panel.visible

func show_dialogue(npc_name: String, text: String, actions: Array = []) -> void:
	name_label.text = npc_name
	text_label.text = text
	panel.visible = true
	_ignore_close_this_frame = true

	for child in actions_row.get_children():
		child.queue_free()
	hint_label.visible = actions.is_empty()
	actions_row.visible = not actions.is_empty()
	# Big, clearly-styled choices in opposite corners (user feedback: the
	# old default buttons were small and side by side): the first choice
	# (Accept / Turn In) is the gold primary at the left edge, the other
	# (Not now / Not yet) a secondary at the right edge - each takes half
	# the row and aligns within its half.
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		var btn := Button.new()
		btn.text = action.label
		btn.custom_minimum_size = Vector2(150, 44)
		btn.add_theme_font_size_override("font_size", 17)
		btn.theme_type_variation = &"PrimaryButton" if i == 0 else &"SecondaryButton"
		btn.size_flags_horizontal = (Control.SIZE_EXPAND | Control.SIZE_SHRINK_BEGIN) if i == 0 else (Control.SIZE_EXPAND | Control.SIZE_SHRINK_END)
		btn.pressed.connect(_on_action_pressed.bind(action.callback))
		actions_row.add_child(btn)

func _on_action_pressed(callback: Callable) -> void:
	hide_dialogue()
	if callback.is_valid():
		callback.call()

func hide_dialogue() -> void:
	panel.visible = false

func _process(_delta: float) -> void:
	if not panel.visible:
		return
	# Fit the box to its text every frame (the wrapped text height is only
	# known after layout) - a long quest offer on a narrow phone box used to
	# run out of the bottom of the fixed-height panel.
	var wanted: float = margin.get_combined_minimum_size().y + 16.0
	if absf(panel.size.y - wanted) > 0.5:
		panel.offset_bottom = panel.offset_top + wanted
	if Input.is_action_just_pressed("interact"):
		if _ignore_close_this_frame:
			_ignore_close_this_frame = false
		else:
			hide_dialogue()
