extends CanvasLayer
# Autoload — a minimal dialogue box (name + text, press E to close). No
# quest/shop state branching yet (that's a later phase); every NPC just
# shows its single intro/greeting line each time, matching how the JS
# game's first NPC pass worked before quests existed.

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/Margin/VBox/NameLabel
@onready var text_label: Label = $Panel/Margin/VBox/TextLabel

var _ignore_close_this_frame := false

func _ready() -> void:
	panel.visible = false
	# Process after interactables (npc.gd etc, default priority 0) so a
	# close-press is seen by them as "still open" this frame and they don't
	# immediately reopen what this same press just closed.
	process_priority = 10

func is_open() -> bool:
	return panel.visible

func show_dialogue(npc_name: String, text: String) -> void:
	name_label.text = npc_name
	text_label.text = text
	panel.visible = true
	_ignore_close_this_frame = true

func hide_dialogue() -> void:
	panel.visible = false

func _process(_delta: float) -> void:
	if panel.visible and Input.is_action_just_pressed("interact"):
		if _ignore_close_this_frame:
			_ignore_close_this_frame = false
		else:
			hide_dialogue()
