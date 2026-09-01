extends CanvasLayer
# Autoload — a dialogue box (name + text, press E to close). Plain greetings
# pass no actions and behave exactly as before; a quest offer/turn-in passes
# 1+ {"label": String, "callback": Callable} actions, which replace the
# "press E to close" hint with clickable buttons - same dynamic-row pattern
# as battle_panel.gd's submenu. E still closes either way (equivalent to
# picking no action), so it's never a dead end.

@onready var panel: Panel = $Panel
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
	for action in actions:
		var btn := Button.new()
		btn.text = action.label
		btn.pressed.connect(_on_action_pressed.bind(action.callback))
		actions_row.add_child(btn)

func _on_action_pressed(callback: Callable) -> void:
	hide_dialogue()
	if callback.is_valid():
		callback.call()

func hide_dialogue() -> void:
	panel.visible = false

func _process(_delta: float) -> void:
	if panel.visible and Input.is_action_just_pressed("interact"):
		if _ignore_close_this_frame:
			_ignore_close_this_frame = false
		else:
			hide_dialogue()
