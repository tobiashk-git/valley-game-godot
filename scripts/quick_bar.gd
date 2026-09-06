extends CanvasLayer
# Autoload — a quick-access row of the usable consumables (healing potion,
# mana potion, antidote - every Items.ITEMS entry with an "effect"), pinned
# bottom-centre between the touch joystick (bottom-left) and interact
# button (bottom-right). Tapping a slot uses one in the field, no menu
# needed (user request). Every slot is always shown so the layout never
# shifts; a slot with nothing in the backpack is just disabled. Hidden
# while a fight is on (the battle screen's own Item submenu covers that,
# and the bar would sit under the battle panel's bottom edge anyway) and
# while any full-screen panel/shop/storage is open (it would otherwise
# draw over that panel's bottom edge, being a later autoload).

const SLOT_SIZE := 48
const BOTTOM_MARGIN := 20.0
# On a phone (Layout.is_narrow()) the joystick (x 30..130) and interact
# button (right 120px) leave no clear band between them at the bottom, so
# the row lifts above both (their zones end 130px up).
const NARROW_BOTTOM_MARGIN := 150.0
# Panels whose open state hides the bar - each has an is_open().
const OVERLAY_AUTOLOADS := ["CharacterSheet", "QuestPanel", "WorldMapPanel", "ShopPanel", "StoragePanel", "SettingsPanel"]

@onready var hbox: HBoxContainer = $HBox
@onready var feedback_label: Label = $FeedbackLabel

var item_ids: Array[String] = []
var _slots: Dictionary = {} # item_id -> {"button": Button, "count": Label}
var _feedback_tween: Tween = null

func _ready() -> void:
	for item_id in Items.ITEMS.keys():
		if Items.is_usable(item_id):
			item_ids.append(item_id)
	for item_id in item_ids:
		_add_slot(item_id)
	# Centre the row on its bottom-centre anchor now that its width is known.
	# Offsets, not `position`: at runtime (parent CanvasLayer already in the
	# tree with a real viewport) Control.position is parent-origin-relative,
	# so position = (-80, -68) would land the row off the top-left of the
	# screen. The setup_*.gd builders only get away with setting `position`
	# on anchored controls because their parent has no size yet when they
	# run, so it degenerates to the same thing as setting offsets.
	_apply_layout()
	feedback_label.modulate.a = 0.0
	Inventory.changed.connect(_refresh)
	_refresh()
	Layout.changed.connect(_apply_layout)

func _bottom_margin() -> float:
	return NARROW_BOTTOM_MARGIN if Layout.is_narrow() else BOTTOM_MARGIN

func _apply_layout() -> void:
	hbox.reset_size()
	_place_bottom_centre(hbox, hbox.size, _bottom_margin())
	_place_bottom_centre(feedback_label, feedback_label.size, _bottom_margin() + hbox.size.y + 6.0)

# For a control anchored PRESET_CENTER_BOTTOM: offsets are relative to that
# anchor point, so this centres it horizontally and lifts it `bottom` px
# off the bottom edge.
func _place_bottom_centre(control: Control, size: Vector2, bottom: float) -> void:
	control.offset_left = -size.x / 2.0
	control.offset_right = size.x / 2.0
	control.offset_top = -(size.y + bottom)
	control.offset_bottom = -bottom

func _add_slot(item_id: String) -> void:
	var btn := Button.new()
	btn.name = item_id.to_pascal_case() + "Slot"
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.icon = Items.get_item_icon(item_id)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = Items.get_item_name(item_id)
	btn.pressed.connect(use_item.bind(item_id))
	# Light parchment slots with the theme's gold border - Godot's default
	# dark-grey Button vanished against grass/dirt on the phone (user
	# feedback). Empty slots keep a muted version of the same look so the
	# row still reads as one unit.
	btn.add_theme_stylebox_override("normal", _slot_style(Color(0.9, 0.84, 0.68, 0.94)))
	btn.add_theme_stylebox_override("hover", _slot_style(Color(0.97, 0.92, 0.78, 0.97)))
	btn.add_theme_stylebox_override("pressed", _slot_style(Color(0.76, 0.68, 0.5, 0.97)))
	btn.add_theme_stylebox_override("disabled", _slot_style(Color(0.62, 0.58, 0.5, 0.6), Color(0.5, 0.42, 0.25, 0.8)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hbox.add_child(btn)

	var count := Label.new()
	count.name = "Count"
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count.position = Vector2(-18, -18)
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", Color(0.12, 0.09, 0.05)) # dark on the light slot
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(count)
	_slots[item_id] = {"button": btn, "count": count}

func _slot_style(bg: Color, border: Color = Color(0.7, 0.55, 0.2, 1.0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border # matches the theme's panel border gold
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func _refresh() -> void:
	for item_id in item_ids:
		var n: int = Inventory.get_count(item_id)
		var slot: Dictionary = _slots[item_id]
		slot.count.text = str(n)
		slot.button.disabled = n <= 0

# Field use of a consumable. Unlike Combat.use_item() (where the turn is
# spent either way), the item is only consumed if it actually did something
# - a mis-tap at full HP shouldn't eat a potion.
func use_item(item_id: String) -> void:
	if Combat.in_combat or Inventory.get_count(item_id) <= 0 or not Items.is_usable(item_id):
		return
	var result: Dictionary = Items.apply_effect(item_id)
	if result.applied:
		Inventory.remove_item(item_id, 1)
		Character.changed.emit()
	_show_feedback(result.message)

func _show_feedback(text: String) -> void:
	feedback_label.text = text
	feedback_label.reset_size()
	_place_bottom_centre(feedback_label, feedback_label.size, _bottom_margin() + hbox.size.y + 6.0)
	if _feedback_tween != null:
		_feedback_tween.kill()
	feedback_label.modulate.a = 1.0
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(1.4)
	_feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.4)

func _overlay_open() -> bool:
	for autoload_name in OVERLAY_AUTOLOADS:
		var node: Node = get_node_or_null("/root/" + autoload_name)
		if node != null and node.has_method("is_open") and node.is_open():
			return true
	return false

func _process(_delta: float) -> void:
	visible = GameState.is_gameplay() and not Combat.in_combat and not _overlay_open()
