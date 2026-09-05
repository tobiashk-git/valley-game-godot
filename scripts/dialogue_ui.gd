extends CanvasLayer
# Autoload — a dialogue box (name + text, press E to close). Plain greetings
# pass no actions and behave exactly as before; a quest offer/turn-in passes
# 1+ {"label": String, "callback": Callable} actions, which replace the
# "press E to close" hint with clickable buttons - same dynamic-row pattern
# as battle_panel.gd's submenu. E still closes either way (equivalent to
# picking no action), so it's never a dead end.

@onready var panel: Panel = $Panel
@onready var margin: MarginContainer = $Panel/Margin
@onready var portrait_frame: Panel = $Panel/Margin/VBox/Row/PortraitFrame
@onready var portrait: TextureRect = $Panel/Margin/VBox/Row/PortraitFrame/Portrait
@onready var name_label: Label = $Panel/Margin/VBox/Row/Head/NameLabel
@onready var tagline_label: Label = $Panel/Margin/VBox/Row/Head/TaglineLabel
@onready var text_label: RichTextLabel = $Panel/Margin/VBox/TextLabel
@onready var hint_label: Label = $Panel/Margin/VBox/HintLabel
@onready var actions_row: HBoxContainer = $Panel/Margin/VBox/ActionsRow

# One line about the speaker, under the name in the header row.
const TAGLINES := {
	"Oliver": "New to the valley, first morning",
	"Village Elder": "Looks after the village",
	"Village Trader": "Buys and sells most anything",
	"Frostpeak Ranger": "Knows the northern ridge",
	"Village Blacksmith": "Keeps the forge lit",
	"Forest Druid": "Warden of Verdantwood",
	"Badlands Prospector": "Digs the Emberfall wastes",
	"Marsh Guide": "Knows every board of Gloomfen",
}

# Speaker name -> bust portrait (assets/portraits/, painterly busts in the
# Oliver-illustration style, keyed from a magenta background). A speaker
# without a file here, or whose file is missing, gets no frame and the text
# spans the whole box - so NPCs can gain portraits one at a time.
const PORTRAITS := {
	"Oliver": "res://assets/portraits/oliver.png",
	"Village Elder": "res://assets/portraits/village_elder.png",
	"Village Trader": "res://assets/portraits/village_trader.png",
	"Frostpeak Ranger": "res://assets/portraits/frostpeak_ranger.png",
	"Village Blacksmith": "res://assets/portraits/village_blacksmith.png",
	"Forest Druid": "res://assets/portraits/forest_druid.png",
	"Badlands Prospector": "res://assets/portraits/badlands_prospector.png",
	"Marsh Guide": "res://assets/portraits/marsh_guide.png",
}
const PORTRAIT_SIZE_WIDE := 96.0
const PORTRAIT_SIZE_NARROW := 72.0

var _ignore_close_this_frame := false

func _ready() -> void:
	panel.visible = false
	# Process after interactables (npc.gd etc, default priority 0) so a
	# close-press is seen by them as "still open" this frame and they don't
	# immediately reopen what this same press just closed.
	process_priority = 10
	Layout.changed.connect(_apply_layout)
	_apply_layout()

func _apply_layout() -> void:
	# Phones: the box takes nearly the full width (the portrait needs the
	# room) and the bust is a little smaller.
	var narrow: bool = Layout.is_narrow()
	panel.offset_left = 12 if narrow else 40
	panel.offset_right = -12 if narrow else -40
	var s: float = PORTRAIT_SIZE_NARROW if narrow else PORTRAIT_SIZE_WIDE
	portrait_frame.custom_minimum_size = Vector2(s, s)

# The portrait texture for a speaker, or null when there isn't one (yet).
static func portrait_for(speaker: String) -> Texture2D:
	var path: String = PORTRAITS.get(speaker, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)

func is_open() -> bool:
	return panel.visible

func show_dialogue(npc_name: String, text: String, actions: Array = []) -> void:
	name_label.text = npc_name
	text_label.text = text
	var tex: Texture2D = portrait_for(npc_name)
	portrait.texture = tex
	portrait_frame.visible = tex != null
	var tag: String = TAGLINES.get(npc_name, "")
	tagline_label.text = tag
	tagline_label.visible = tag != ""
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
	# The press that opened the box (npc.gd, same frame, lower priority)
	# must not close it; the guard lasts exactly one frame, so a box opened
	# by a button or a script closes on the very next E rather than the
	# second one.
	if Input.is_action_just_pressed("interact") and not _ignore_close_this_frame:
		hide_dialogue()
	_ignore_close_this_frame = false
