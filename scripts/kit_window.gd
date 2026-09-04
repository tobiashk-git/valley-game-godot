class_name KitWindow
extends CanvasLayer
# Base for the contextual item windows (ShopPanel, StoragePanel - UI redesign
# Phase 3) built on the character sheet's kit: dimmed world, one window with
# a title row, two tab buttons, a 64px slot grid and a detail pane whose
# actions depend on the tab (Buy / Sell / Take out / Put in). Scene
# skeletons come from tools/setup_kit_windows.gd; subclasses supply the
# entries per tab and the detail pane's value line + actions.
#
# Two layouts, same as character_sheet.gd: the 800-wide one (grid left, pane
# right) and the phone one for Layout.is_narrow() (window fills the width,
# grid above a full-width pane). Every node keeps its name in both.
#
# Closing: the X button, Esc, or another E press (the same press that opened
# it is ignored for one frame, and process_priority 10 runs after the
# chest/NPC interactables so a close-press isn't seen as a re-open).

const SLOT_SIZE := 64

@onready var window: Panel = $Window
@onready var title_label: Label = $Window/TitleLabel
@onready var subtitle_label: Label = $Window/SubtitleLabel
@onready var tabs: HBoxContainer = $Window/Tabs
@onready var tab_a: Button = $Window/Tabs/TabA
@onready var tab_b: Button = $Window/Tabs/TabB
@onready var close_btn: Button = $Window/CloseBtn
@onready var count_label: Label = $Window/CountLabel
@onready var grid_scroll: ScrollContainer = $Window/GridScroll
@onready var grid: GridContainer = $Window/GridScroll/Grid
@onready var detail_pane: Panel = $Window/DetailPane
@onready var detail_icon: TextureRect = $Window/DetailPane/DetailIcon
@onready var detail_name: Label = $Window/DetailPane/DetailName
@onready var detail_type: Label = $Window/DetailPane/DetailType
@onready var detail_desc: Label = $Window/DetailPane/DetailDesc
@onready var detail_value: Label = $Window/DetailPane/DetailValue
@onready var detail_actions: VBoxContainer = $Window/DetailPane/Actions
@onready var primary_action: Button = $Window/DetailPane/Actions/PrimaryAction
@onready var secondary_action: Button = $Window/DetailPane/Actions/SecondaryAction
@onready var hint_label: Label = $Window/HintLabel

# 0 = TabA, 1 = TabB.
var tab := 0
# Selection: a stackable's item id, or a gear instance's uid (item id kept
# alongside so the pane can describe it even after it moved).
var selected_item := ""
var selected_uid := 0
var narrow := false
var _ignore_close_this_frame := false

func _ready() -> void:
	window.visible = false
	$Dim.visible = false
	process_priority = 10
	tab_a.pressed.connect(set_tab.bind(0))
	tab_b.pressed.connect(set_tab.bind(1))
	close_btn.pressed.connect(close)
	primary_action.pressed.connect(_on_primary)
	secondary_action.pressed.connect(_on_secondary)
	Layout.changed.connect(_on_layout_changed)
	_apply_layout()

# --- subclass hooks ---

# Entries for the current tab: [{"id": item_id, "count": int, "inst": {}}],
# gear as one entry per instance (inst non-empty, count 1).
func _entries() -> Array:
	return []

# Fills detail_value and the two action buttons for the selected entry
# (already-visible name/type/desc are done by the base).
func _detail_actions(_entry: Dictionary) -> void:
	pass

func _on_primary() -> void:
	pass

func _on_secondary() -> void:
	pass

# Title-row subtitle ("Gold on hand: 12" / "Chest: 3 items - Backpack: 5").
func _subtitle() -> String:
	return ""

func _hint() -> String:
	return ""

# Optional slot badge override (the shop's buy tab shows the price).
func _badge(_entry: Dictionary) -> String:
	return ""

# --- open / close ---

func is_open() -> bool:
	return window.visible

func _open_window() -> void:
	selected_item = ""
	selected_uid = 0
	window.visible = true
	$Dim.visible = true
	_ignore_close_this_frame = true
	_apply_layout()
	_refresh()

func close() -> void:
	window.visible = false
	$Dim.visible = false

func set_tab(index: int) -> void:
	tab = index
	selected_item = ""
	selected_uid = 0
	_refresh()

func select_entry(item_id: String, uid: int) -> void:
	selected_item = item_id
	selected_uid = uid
	_refresh()

func _process(_delta: float) -> void:
	if not window.visible:
		return
	if _ignore_close_this_frame:
		_ignore_close_this_frame = false
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel"):
		close()

# --- layout ---

func _on_layout_changed() -> void:
	_apply_layout()
	if window.visible:
		_refresh()

func _place(c: Control, pos: Vector2, size: Vector2) -> void:
	c.position = pos
	c.size = size

static func columns_for(width: float) -> int:
	return maxi(1, floori((width + 6.0) / (SLOT_SIZE + 6.0)))

func _apply_layout() -> void:
	narrow = Layout.is_narrow()
	var pw: float
	var pane_h: float
	# Columns BEFORE the scroll size (a scroll with horizontal scrolling
	# disabled can't be narrower than its grid - see character_sheet.gd).
	if not narrow:
		window.position = Vector2(40, 56)
		window.size = Vector2(720, 530)
		title_label.position = Vector2(20, 12)
		_place(subtitle_label, Vector2(360, 18), Vector2(300, 18))
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		close_btn.position = Vector2(676, 10)
		tabs.position = Vector2(20, 52)
		for b in [tab_a, tab_b]:
			b.custom_minimum_size = Vector2(118, 32)
		_place(count_label, Vector2(300, 60), Vector2(144, 16))
		grid.columns = 6
		_place(grid_scroll, Vector2(20, 96), Vector2(424, 394))
		pw = 248.0
		pane_h = 394.0
		_place(detail_pane, Vector2(452, 96), Vector2(pw, pane_h))
		hint_label.position = Vector2(20, 500)
		hint_label.visible = true
	else:
		var iw: float = Layout.width - 24.0
		var wh: float = Layout.size().y - 56.0 - 12.0
		window.position = Vector2(12, 56)
		window.size = Vector2(iw, wh)
		title_label.position = Vector2(20, 10)
		_place(subtitle_label, Vector2(20, 38), Vector2(iw - 40.0, 18))
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		close_btn.position = Vector2(iw - 44.0, 10)
		tabs.position = Vector2(20, 62)
		for b in [tab_a, tab_b]:
			b.custom_minimum_size = Vector2(floorf((iw - 40.0 - 6.0) / 2.0), 36)
		_place(count_label, Vector2(iw - 164.0, 108), Vector2(144, 16))
		grid.columns = columns_for(iw - 40.0)
		var grid_h: float = 3 * SLOT_SIZE + 12.0
		_place(grid_scroll, Vector2(20, 126), Vector2(iw - 40.0, grid_h))
		pw = iw - 40.0
		pane_h = minf(300.0, wh - 126.0 - grid_h - 8.0 - 12.0)
		_place(detail_pane, Vector2(20, 126.0 + grid_h + 8.0), Vector2(pw, pane_h))
		hint_label.visible = false
	_place(detail_type, Vector2(68, 34), Vector2(pw - 80.0, 32))
	_place(detail_desc, Vector2(12, 72), Vector2(pw - 24.0, 60 if narrow else 80))
	_place(detail_value, Vector2(12, 136 if narrow else 158), Vector2(pw - 24.0, 40))
	_place(detail_actions, Vector2(12, 184 if narrow else 206), Vector2(pw - 24.0, 88))
	for b in [primary_action, secondary_action]:
		b.custom_minimum_size = Vector2(pw - 24.0, 40)

# --- refresh ---

func _refresh() -> void:
	if not window.visible:
		return
	tab_a.theme_type_variation = &"TabButtonActive" if tab == 0 else &"TabButton"
	tab_b.theme_type_variation = &"TabButtonActive" if tab == 1 else &"TabButton"
	subtitle_label.text = _subtitle()
	hint_label.text = _hint()
	var entries: Array = _entries()
	_clear(grid)
	# Drop a selection that's no longer listed (sold / moved).
	var selected_entry: Dictionary = {}
	for entry in entries:
		if (selected_uid != 0 and not entry.inst.is_empty() and entry.inst.uid == selected_uid) or (selected_uid == 0 and entry.inst.is_empty() and entry.id == selected_item):
			selected_entry = entry
	if selected_entry.is_empty():
		selected_item = ""
		selected_uid = 0
	var seen: Dictionary = {}
	for entry in entries:
		var uid: int = entry.inst.uid if not entry.inst.is_empty() else 0
		var btn: Button = make_slot(entry.id, entry.count, entry == selected_entry, entry.inst, false, _badge(entry))
		seen[entry.id] = seen.get(entry.id, 0) + 1
		if seen[entry.id] > 1:
			btn.name = "%sSlot%d" % [entry.id.to_pascal_case(), seen[entry.id]]
		btn.pressed.connect(select_entry.bind(entry.id, uid))
		grid.add_child(btn)
	count_label.text = "%d item%s" % [entries.size(), "" if entries.size() == 1 else "s"] if not entries.is_empty() else "Nothing here"
	_refresh_detail(selected_entry)

func _refresh_detail(entry: Dictionary) -> void:
	primary_action.visible = false
	secondary_action.visible = false
	primary_action.disabled = false
	secondary_action.disabled = false
	detail_name.position.x = 68.0 if not entry.is_empty() else 12.0
	detail_type.position.x = detail_name.position.x
	if entry.is_empty():
		detail_icon.texture = null
		detail_name.text = "Select an item"
		detail_type.text = ""
		detail_desc.text = ""
		detail_value.text = ""
		return
	var def: Dictionary = Items.ITEMS[entry.id]
	detail_icon.texture = Items.get_item_icon(entry.id)
	detail_name.text = Items.instance_name(entry.inst) if not entry.inst.is_empty() else def.name
	if Items.is_equippable(entry.id):
		var stat_text: String = Items.describe_instance(entry.inst) if not entry.inst.is_empty() else Items.describe_stats(entry.id)
		detail_type.text = "%s  -  %s" % [Character.SLOTS[def.slot].label, stat_text]
	elif Items.is_usable(entry.id):
		detail_type.text = "Consumable"
	elif entry.id == "magic_crystal":
		detail_type.text = "Quest item"
	elif entry.id == "gold":
		detail_type.text = "Currency"
	else:
		detail_type.text = "Material"
	detail_desc.text = def.get("desc", "")
	_detail_actions(entry)

func _clear(container: Node) -> void:
	var dying := 0
	for child in container.get_children():
		child.name = "Dying%d" % dying
		dying += 1
		child.visible = false
		child.queue_free()

# The kit's item slot (shared with character_sheet.gd): 64px SlotButton
# with the item's icon, a count badge for stacks (or `badge` text, e.g. a
# price), a gold * on enhanced gear. connect_select=false leaves the
# pressed signal to the caller.
static func make_slot(item_id: String, count: int, selected: bool, inst: Dictionary, connect_select: bool = true, badge: String = "", on_select: Callable = Callable()) -> Button:
	var btn := Button.new()
	btn.name = item_id.to_pascal_case() + "Slot"
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.theme_type_variation = &"SlotButtonSelected" if selected else &"SlotButton"
	btn.icon = Items.get_item_icon(item_id)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = Items.instance_name(inst) if not inst.is_empty() else Items.get_item_name(item_id)
	if connect_select and on_select.is_valid():
		btn.pressed.connect(on_select)
	if not inst.is_empty() and not inst.mods.is_empty():
		var star := Label.new()
		star.name = "Enhanced"
		star.text = "*"
		star.position = Vector2(4, -2)
		star.add_theme_font_size_override("font_size", 18)
		star.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(star)
	var badge_text: String = badge if badge != "" else (str(count) if count > 1 else "")
	if badge_text != "":
		var label := Label.new()
		label.name = "Count"
		label.text = badge_text
		label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		label.position = Vector2(-22, -20)
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(label)
	return btn

# Backpack contents as entries: stackables (optionally filtered) then one
# entry per gear instance - the shape both the shop's Sell tab and the
# chest's Backpack tab list.
static func backpack_entries(skip: Array = []) -> Array:
	var out: Array = []
	for item_id in Inventory.backpack.keys():
		if Inventory.backpack[item_id] > 0 and not (item_id in skip):
			out.append({"id": item_id, "count": Inventory.backpack[item_id], "inst": {}})
	for inst in Inventory.gear:
		out.append({"id": inst.base, "count": 1, "inst": inst})
	return out
