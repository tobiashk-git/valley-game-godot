extends CanvasLayer
# Autoload — the tabbed character-sheet window (UI redesign Phases 1-2). One
# window with a tab strip (Inventory · Character · Crafting · Journal · Map):
# the first three are real tabs living here (the old InventoryPanel /
# CharacterPanel / CraftingPanel popups are deleted); Journal and Map hand
# off to the existing QuestPanel/WorldMapPanel for now (later phases bring
# them in here).
#
# Shared header: portrait, name, location, HP/MP, stats, three equipment
# icon slots. Inventory tab: backpack icon grid -> tap to select -> detail
# pane (icon, name, type, flavour text, value) with the actions that apply
# (Use / Equip / Unequip). Character tab: stats, gear bonuses, active effects.
# Scene skeleton from tools/setup_character_sheet.gd; the grid, detail pane
# contents and stats list are built here at runtime.
#
# Two layouts (see _apply_layout()): the 800-wide one the builder draws, and
# a stacked phone layout for Layout.is_narrow() screens (360-480 units) -
# window fills the width, header grows downwards (slot row under the bars),
# grid above its detail pane instead of beside it, the Character tab stacks
# doll / slot cards / stats and scrolls, and the tab strip uses short names.

const SLOT_SIZE := 64
# Equipment slots come from Character.SLOTS (the one slot table); the
# header/doll slot nodes are named <PascalCaseSlotId>Slot by the builder.
const TAB_BUTTONS := {"inventory": "InventoryTab", "character": "CharacterTab", "crafting": "CraftingTab", "journal": "JournalTab", "map": "MapTab"}
# [wide label, narrow label] - the five full names don't fit a phone-width strip.
const TAB_LABELS := {"inventory": ["Inventory", "Items"], "character": ["Character", "Hero"], "crafting": ["Crafting", "Craft"], "journal": ["Journal", "Quests"], "map": ["Map", "Map"]}
# Every tab is a real tab now. (Journal and Map used to close this window
# and open standalone panels - the strip vanished, "can't switch back to
# inventory" - so they moved in as views; QuestPanel/WorldMapPanel are
# aliases.)
const EXTERNAL_TABS := {}
# Tabs that hide the header (their content needs the height).
const HEADERLESS_TABS := ["map", "journal"]

# Crafting feedback (user feedback: "on crafting an item it's not obvious
# that something has happened"). Recipes are drawn as blueprints - icons
# tinted cyanotype-blue - and crafting one "makes it real": the pane's icon
# pops and fades to full colour, the button reads Crafted! for a moment and
# a line says what you now have. Enhancing gets the same pop in gold.
const BLUEPRINT_TINT := Color(0.62, 0.8, 1.0)
const ENHANCE_GLOW := Color(1.8, 1.5, 0.9)
const FLASH_SECONDS := 1.4

@onready var window: Panel = $Window
@onready var tabs: HBoxContainer = $Window/Tabs
@onready var close_btn: Button = $Window/CloseBtn
@onready var header: Control = $Window/Header
@onready var portrait: TextureRect = $Window/Header/PortraitFrame/Portrait
@onready var name_label: Label = $Window/Header/NameLabel
@onready var location_label: Label = $Window/Header/LocationLabel
@onready var hp_bar: ProgressBar = $Window/Header/HPBar
@onready var hp_label: Label = $Window/Header/HPBar/HPLabel
@onready var mp_bar: ProgressBar = $Window/Header/MPBar
@onready var mp_label: Label = $Window/Header/MPBar/MPLabel
@onready var stats_label: Label = $Window/Header/StatsLabel
@onready var bonus_label: Label = $Window/Header/BonusLabel
@onready var separator: ColorRect = $Window/Separator
@onready var inventory_view: Control = $Window/InventoryView
@onready var character_scroll: ScrollContainer = $Window/CharacterScroll
@onready var character_view: Control = $Window/CharacterScroll/CharacterView
@onready var count_label: Label = $Window/InventoryView/CountLabel
@onready var grid_scroll: ScrollContainer = $Window/InventoryView/GridScroll
@onready var grid: GridContainer = $Window/InventoryView/GridScroll/Grid
@onready var detail_pane: Panel = $Window/InventoryView/DetailPane
@onready var detail_icon: TextureRect = $Window/InventoryView/DetailPane/DetailIcon
@onready var detail_name: Label = $Window/InventoryView/DetailPane/DetailName
@onready var detail_type: Label = $Window/InventoryView/DetailPane/DetailType
@onready var detail_desc: Label = $Window/InventoryView/DetailPane/DetailDesc
@onready var detail_value: Label = $Window/InventoryView/DetailPane/DetailValue
@onready var detail_actions: VBoxContainer = $Window/InventoryView/DetailPane/Actions
@onready var primary_action: Button = $Window/InventoryView/DetailPane/Actions/PrimaryAction
@onready var secondary_action: Button = $Window/InventoryView/DetailPane/Actions/SecondaryAction
@onready var inventory_hint: Label = $Window/InventoryView/HintLabel
@onready var stats_list: VBoxContainer = $Window/CharacterScroll/CharacterView/StatsList
@onready var crafting_view: Control = $Window/CraftingView
@onready var map_view: Control = $Window/MapView
@onready var journal_view: Control = $Window/JournalView
@onready var craft_mode_btn: Button = $Window/CraftingView/Modes/CraftMode
@onready var enhance_mode_btn: Button = $Window/CraftingView/Modes/EnhanceMode
@onready var craft_count_label: Label = $Window/CraftingView/CraftCountLabel
@onready var craft_scroll: ScrollContainer = $Window/CraftingView/CraftScroll
@onready var craft_groups: VBoxContainer = $Window/CraftingView/CraftScroll/CraftGroups
@onready var craft_pane: Panel = $Window/CraftingView/CraftPane
@onready var craft_icon: TextureRect = $Window/CraftingView/CraftPane/CraftIcon
@onready var craft_name: Label = $Window/CraftingView/CraftPane/CraftName
@onready var craft_type: Label = $Window/CraftingView/CraftPane/CraftType
@onready var craft_desc: Label = $Window/CraftingView/CraftPane/CraftDesc
@onready var craft_rows_scroll: ScrollContainer = $Window/CraftingView/CraftPane/CraftRowsScroll
@onready var craft_rows: VBoxContainer = $Window/CraftingView/CraftPane/CraftRowsScroll/CraftRows
@onready var craft_action: Button = $Window/CraftingView/CraftPane/CraftAction
@onready var craft_hint: Label = $Window/CraftingView/CraftHint
@onready var figure: TextureRect = $Window/CharacterScroll/CharacterView/Figure
@onready var figure_shadow: ColorRect = $Window/CharacterScroll/CharacterView/FigureShadow
@onready var equipment_title: Label = $Window/CharacterScroll/CharacterView/EquipmentTitle
@onready var doll_hint: Label = $Window/CharacterScroll/CharacterView/DollHint
@onready var slot_pane: Panel = $Window/CharacterScroll/CharacterView/SlotPane
@onready var slot_pane_title: Label = $Window/CharacterScroll/CharacterView/SlotPane/SlotPaneTitle
@onready var slot_scroll: ScrollContainer = $Window/CharacterScroll/CharacterView/SlotPane/SlotScroll
@onready var slot_list: BoxContainer = $Window/CharacterScroll/CharacterView/SlotPane/SlotScroll/SlotList

# Optional keyed full-body illustration for the paper doll (Leonardo
# track); the player sprite's idle frame at 3x stands in until it exists.
const PORTRAIT_ILLUSTRATION := "res://assets/oliver_portrait.png"

var current_tab := "inventory"
# Which fitting slot the paper doll's right-hand pane is showing (first
# slot in the table by default).
var doll_slot := ""
var selected_item := "" # item id (stackable) or a gear instance's base id
var selected_uid := 0 # the gear instance's uid (0 for stackables)
# Equipment slot the selection came from ("" = backpack). Lets the pane
# offer Unequip for a worn item and Equip for a carried one.
var selected_slot := ""
var _primary_kind := "" # "use" | "equip" | "unequip"
# Crafting tab state.
var craft_mode := "craft" # "craft" | "enhance"
var selected_recipe := ""
var enhance_uid := 0 # gear instance picked in Enhance mode
var enhance_worn_slot := "" # "" if carried, else the slot it's worn in
var selected_enhancement := ""
# Crafting feedback state: "" | "craft" | "enhance" while the pop is showing.
var flash_kind := ""
var flash_label: Label = null
var _flash_id := 0
var _flash_tween: Tween = null
# Layout state (see _apply_layout()).
var narrow := false
var grid_columns := 6
var craft_columns := 6
# Craft mode sections, in display order, by what the recipe makes.
const CRAFT_GROUPS := ["Potions & Food", "Equipment", "Materials"]
# Enhance mode sections: one per equipment slot (Character.SLOTS order).
const SLOT_GROUP_NAMES := {"weapon": "Weapons", "armor": "Armour", "accessory": "Accessories"}

func _ready() -> void:
	window.visible = false
	$Dim.visible = false
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/player_base.png")
	atlas.region = Rect2(0, 128, 64, 64) # Player.tscn's down_idle frame
	portrait.texture = atlas
	if ResourceLoader.exists(PORTRAIT_ILLUSTRATION):
		figure.texture = load(PORTRAIT_ILLUSTRATION)
		# The illustration is stored at 2x its drawn height - smooth it down
		# (the scene's NEAREST filter is for the pixel-sprite fallback).
		figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		figure.texture = atlas
	doll_slot = Character.SLOTS.keys()[0]
	for slot in Character.SLOTS:
		_doll_slot_button(slot).pressed.connect(_on_doll_slot.bind(slot))
	for tab in TAB_BUTTONS:
		tabs.get_node(TAB_BUTTONS[tab]).pressed.connect(_on_tab_pressed.bind(tab))
	close_btn.pressed.connect(close)
	for slot in Character.SLOTS:
		_header_slot_button(slot).pressed.connect(select_equipped.bind(slot))
	primary_action.pressed.connect(_on_primary_action)
	craft_mode_btn.pressed.connect(_set_craft_mode.bind("craft"))
	enhance_mode_btn.pressed.connect(_set_craft_mode.bind("enhance"))
	craft_action.pressed.connect(_on_craft_action)
	# The crafting feedback line sits over the ingredient checklist while a
	# Crafted!/Enhanced! pop is showing (built here, not in the scene, so the
	# builder's node set is unchanged).
	flash_label = Label.new()
	flash_label.name = "CraftFlash"
	flash_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flash_label.add_theme_font_size_override("font_size", 14)
	flash_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	flash_label.visible = false
	craft_pane.add_child(flash_label)
	craft_icon.pivot_offset = craft_icon.size / 2.0
	Layout.changed.connect(_on_layout_changed)
	_apply_layout()
	# Later autoloads (Inventory is earlier; Character/Combat aren't) - see
	# hud.gd for the same deferral.
	_connect_signals.call_deferred()

func _header_slot_button(slot: String) -> Button:
	return header.get_node(slot.to_pascal_case() + "Slot")

func _header_slot_label(slot: String) -> Label:
	return header.get_node(slot.to_pascal_case() + "SlotLabel")

func _doll_slot_button(slot: String) -> Button:
	return character_view.get_node("Doll%sSlot" % slot.to_pascal_case())

func _connect_signals() -> void:
	Quests.changed.connect(_refresh)
	Inventory.changed.connect(_refresh)
	Character.changed.connect(_refresh)
	Combat.changed.connect(_refresh)

# --- layout ---

func _on_layout_changed() -> void:
	_apply_layout()
	_refresh()

# Positions every node for the current Layout.width. Wide = exactly what
# tools/setup_character_sheet.gd draws (kept here too so a phone rotated
# back to a wide shape restores it); narrow = the stacked phone layout.
func _apply_layout() -> void:
	narrow = Layout.is_narrow()
	var slots: Dictionary = Character.SLOTS
	# The Map tab hides the header (the 408px map frame needs the height);
	# the views then start right under the tab strip.
	var map_tab: bool = current_tab in HEADERLESS_TABS
	header.visible = not map_tab
	separator.visible = not map_tab
	if not narrow:
		window.position = Vector2(40, 56)
		window.size = Vector2(720, 530)
		for tab in TAB_BUTTONS:
			var b: Button = tabs.get_node(TAB_BUTTONS[tab])
			b.text = TAB_LABELS[tab][0]
			b.custom_minimum_size = Vector2(118, 32)
			b.add_theme_font_size_override("font_size", 14)
		close_btn.position = Vector2(676, 10)
		header.position = Vector2(0, 54)
		header.size = Vector2(720, 92)
		_place(hp_bar, Vector2(112, 42), Vector2(220, 16))
		_place(mp_bar, Vector2(112, 62), Vector2(220, 16))
		stats_label.position = Vector2(350, 45)
		_place(bonus_label, Vector2(350, 64), Vector2(165, 16))
		var x := 712.0 - slots.size() * 64.0
		for slot_id in slots:
			_place(_header_slot_button(slot_id), Vector2(x, 0), Vector2(56, 56))
			_place(_header_slot_label(slot_id), Vector2(x, 60), Vector2(56, 14))
			x += 64.0
		_place(separator, Vector2(20, 150), Vector2(680, 1))
		_layout_inventory(Vector2(0, 158), Vector2(720, 360))
		_layout_character(Vector2(0, 158), Vector2(720, 360))
		_layout_crafting(Vector2(0, 158), Vector2(720, 360))
		_place(map_view, Vector2(0, 66), Vector2(720, 452))
		map_view.apply_layout(false, map_view.size)
		_place(journal_view, Vector2(0, 66), Vector2(720, 452))
		journal_view.apply_layout(false, journal_view.size)
		return

	var iw: float = Layout.width - 24.0
	var wh: float = Layout.size().y - 56.0 - 12.0
	window.position = Vector2(12, 56)
	window.size = Vector2(iw, wh)
	# 12 left, X (32) + 12 gap + 12 right, four 6px separations, five tabs.
	var tab_w: float = floorf((iw - 68.0 - 24.0) / 5.0)
	for tab in TAB_BUTTONS:
		var b: Button = tabs.get_node(TAB_BUTTONS[tab])
		b.text = TAB_LABELS[tab][1]
		b.custom_minimum_size = Vector2(tab_w, 36)
		b.add_theme_font_size_override("font_size", 12)
	close_btn.position = Vector2(iw - 44.0, 10)
	# Header grows downwards: bars beside the portrait, stats + bonus lines
	# under them, then the equipment slot row - which the Hero tab hides (the
	# doll shows the slots), so that tab's header stops above it.
	var header_h: float = 206.0 if current_tab != "character" else 126.0
	if map_tab:
		header_h = -12.0 # no header: views start right under the tab strip
	header.position = Vector2(0, 54)
	header.size = Vector2(iw, header_h)
	_place(hp_bar, Vector2(112, 42), Vector2(iw - 132.0, 16))
	_place(mp_bar, Vector2(112, 62), Vector2(iw - 132.0, 16))
	stats_label.position = Vector2(112, 84)
	_place(bonus_label, Vector2(112, 102), Vector2(iw - 124.0, 16))
	var sx := 20.0
	for slot_id in slots:
		_place(_header_slot_button(slot_id), Vector2(sx, 126), Vector2(SLOT_SIZE, SLOT_SIZE))
		_place(_header_slot_label(slot_id), Vector2(sx, 126 + SLOT_SIZE + 2), Vector2(SLOT_SIZE, 14))
		sx += SLOT_SIZE + 8.0
	_place(separator, Vector2(20, 54.0 + header_h + 4.0), Vector2(iw - 40.0, 1))
	var view_pos := Vector2(0, 54.0 + header_h + 12.0)
	var view_size := Vector2(iw, wh - view_pos.y - 12.0)
	_layout_inventory(view_pos, view_size)
	_layout_character(view_pos, view_size)
	_layout_crafting(view_pos, view_size)
	_place(map_view, view_pos, view_size)
	map_view.apply_layout(true, view_size)
	_place(journal_view, view_pos, view_size)
	journal_view.apply_layout(true, view_size)

func _place(c: Control, pos: Vector2, size: Vector2) -> void:
	c.position = pos
	c.size = size

func _columns_for(width: float) -> int:
	return maxi(1, floori((width + 6.0) / (SLOT_SIZE + 6.0)))

func _layout_inventory(pos: Vector2, size: Vector2) -> void:
	inventory_view.position = pos
	inventory_view.size = size
	# Columns BEFORE the scroll size: with horizontal scrolling disabled a
	# ScrollContainer can't be narrower than its grid, so a 6-column grid
	# would pin the scroll at 414px however small the size set here.
	if not narrow:
		grid_columns = 6
		grid.columns = grid_columns
		count_label.position = Vector2(300, 3)
		_place(grid_scroll, Vector2(20, 24), Vector2(424, 296))
		_place(detail_pane, Vector2(452, 0), Vector2(248, 320))
		_place(detail_type, Vector2(68, 34), Vector2(170, 32))
		_place(detail_desc, Vector2(12, 72), Vector2(224, 96))
		detail_value.position = Vector2(12, 174)
		_place(detail_actions, Vector2(12, 220), Vector2(224, 88))
		for b in [primary_action, secondary_action]:
			b.custom_minimum_size = Vector2(224, 40)
		inventory_hint.visible = true
	else:
		var iw: float = size.x
		var pane_h := 212.0
		var grid_h: float = minf(3 * SLOT_SIZE + 12.0, size.y - 24.0 - pane_h - 8.0)
		grid_columns = _columns_for(iw - 40.0)
		grid.columns = grid_columns
		count_label.position = Vector2(iw - 160.0, 3)
		_place(grid_scroll, Vector2(20, 24), Vector2(iw - 40.0, grid_h))
		var pw: float = iw - 40.0
		_place(detail_pane, Vector2(20, 24.0 + grid_h + 8.0), Vector2(pw, pane_h))
		_place(detail_type, Vector2(68, 34), Vector2(pw - 80.0, 32))
		_place(detail_desc, Vector2(12, 72), Vector2(pw - 24.0, 60))
		detail_value.position = Vector2(12, 136)
		_place(detail_actions, Vector2(12, 160), Vector2(pw - 24.0, 40))
		for b in [primary_action, secondary_action]:
			b.custom_minimum_size = Vector2(pw - 24.0, 40)
		inventory_hint.visible = false

func _layout_character(pos: Vector2, size: Vector2) -> void:
	character_scroll.position = pos
	character_scroll.size = size
	var div1: ColorRect = character_view.get_node("Divider1")
	var div2: ColorRect = character_view.get_node("Divider2")
	if not narrow:
		character_view.custom_minimum_size = Vector2(720, 360)
		_place(stats_list, Vector2(20, 0), Vector2(200, 340))
		div1.visible = true
		div2.visible = true
		_place(equipment_title, Vector2(250, 0), Vector2(300, 20))
		figure.position = Vector2(300, 22)
		figure_shadow.position = Vector2(352, 248)
		_place_doll(300.0)
		_place(doll_hint, Vector2(250, 262), Vector2(300, 20))
		_place(slot_pane, Vector2(594, 0), Vector2(106, 342))
		_place(slot_pane_title, Vector2(0, 6), Vector2(106, 20))
		_place(slot_scroll, Vector2(6, 30), Vector2(94, 306))
		slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		slot_list.vertical = true
	else:
		# Stacked: doll block (0..284) / slot cards in a horizontal strip /
		# the stats column; the view scrolls when that is taller than the tab.
		var iw: float = size.x
		var fig_x: float = floorf((iw - 204.0) / 2.0)
		div1.visible = false
		div2.visible = false
		_place(equipment_title, Vector2(0, 0), Vector2(iw, 20))
		figure.position = Vector2(fig_x, 22)
		figure_shadow.position = Vector2(fig_x + 52.0, 248)
		_place_doll(fig_x)
		_place(doll_hint, Vector2(0, 262), Vector2(iw, 20))
		_place(slot_pane, Vector2(20, 284), Vector2(iw - 40.0, 160))
		_place(slot_pane_title, Vector2(0, 6), Vector2(iw - 40.0, 20))
		_place(slot_scroll, Vector2(6, 30), Vector2(iw - 52.0, 124))
		slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		slot_list.vertical = false
		_place(stats_list, Vector2(20, 456), Vector2(iw - 40.0, 0))
		character_view.custom_minimum_size = Vector2(iw, 456.0 + 300.0)

# Doll slots / labels / connector lines from the Character.SLOTS table. The
# table's positions are for the figure at x=300 (wide); a figure elsewhere
# shifts the whole rig with it: left-column slots keep their 50px overlap
# with the figure's left edge, right-column slots start at its right edge.
func _place_doll(fig_x: float) -> void:
	var slots: Dictionary = Character.SLOTS
	for slot_id in slots:
		var def: Dictionary = slots[slot_id]
		var pascal: String = slot_id.to_pascal_case()
		var left: bool = def.doll.x < 400.0
		var pos := Vector2(def.doll.x - 300.0 + fig_x, def.doll.y)
		_place(_doll_slot_button(slot_id), pos, Vector2(64, 64))
		_place(character_view.get_node("Doll%sSlotLabel" % pascal), pos + Vector2(0, 66), Vector2(64, 14))
		var line: Line2D = character_view.get_node(pascal + "Line")
		var from: Vector2 = pos + (Vector2(66, 32) if left else Vector2(-4, 32))
		var to: Vector2 = def.line_to - Vector2(300, 0) + Vector2(fig_x, 0)
		line.points = PackedVector2Array([from, to])

func _layout_crafting(pos: Vector2, size: Vector2) -> void:
	crafting_view.position = pos
	crafting_view.size = size
	var pw: float
	var pane_h: float
	# Columns before the scroll size - see _layout_inventory().
	if not narrow:
		craft_columns = 6
		_apply_craft_columns()
		craft_count_label.position = Vector2(300, 8)
		_place(craft_scroll, Vector2(20, 36), Vector2(424, 284))
		pw = 248.0
		pane_h = 320.0
		_place(craft_pane, Vector2(452, 0), Vector2(pw, pane_h))
		craft_hint.visible = true
	else:
		var iw: float = size.x
		craft_columns = _columns_for(iw - 40.0)
		_apply_craft_columns()
		craft_count_label.position = Vector2(iw - 160.0, 8)
		# Three rows' worth: two sections with a title each fit without a scroll.
		var grid_h: float = 3 * SLOT_SIZE + 12.0
		_place(craft_scroll, Vector2(20, 36), Vector2(iw - 40.0, grid_h))
		pw = iw - 40.0
		pane_h = maxf(240.0, size.y - 36.0 - grid_h - 8.0 - 4.0)
		_place(craft_pane, Vector2(20, 36.0 + grid_h + 8.0), Vector2(pw, pane_h))
		craft_hint.visible = false
	_place(craft_name, Vector2(68, 8), Vector2(pw - 78.0, 42))
	_place(craft_type, Vector2(68, 52), Vector2(pw - 78.0, 30))
	_place(craft_desc, Vector2(12, 88), Vector2(pw - 24.0, 44))
	_place(craft_rows_scroll, Vector2(12, 136), Vector2(pw - 24.0, pane_h - 136.0 - 52.0))
	_place(flash_label, craft_rows_scroll.position, craft_rows_scroll.size)
	_place(craft_action, Vector2(12, pane_h - 52.0), Vector2(pw - 24.0, 40))

# --- open / close ---

func is_open() -> bool:
	return window.visible

func open(tab: String = "") -> void:
	if tab in EXTERNAL_TABS:
		close()
		get_node("/root/" + EXTERNAL_TABS[tab]).open()
		return
	if tab != "":
		current_tab = tab
	_clear_flash()
	_apply_layout() # the header (phone height; hidden on Map) depends on the tab
	if current_tab == "map":
		map_view.select_default()
	window.visible = true
	$Dim.visible = true
	_refresh()

func close() -> void:
	_clear_flash()
	window.visible = false
	$Dim.visible = false

# Same tab again closes; a different tab switches (so I while on Character
# jumps to Inventory instead of closing).
func toggle(tab: String) -> void:
	if is_open() and current_tab == tab:
		close()
	else:
		open(tab)

func _on_tab_pressed(tab: String) -> void:
	open(tab)

# --- selection ---

func select_item(item_id: String, from_slot: String = "", uid: int = 0) -> void:
	selected_item = item_id
	selected_slot = from_slot
	selected_uid = uid
	_refresh()

func select_equipped(slot: String) -> void:
	var inst: Dictionary = Character.equipped(slot)
	select_item(inst.base if not inst.is_empty() else "", slot, inst.uid if not inst.is_empty() else 0)

# The gear instance behind the current selection ({} for stackables).
func _selected_instance() -> Dictionary:
	if selected_slot != "":
		return Character.equipped(selected_slot)
	return Inventory.find_gear(selected_uid) if selected_uid != 0 else {}

# --- refresh ---

func _refresh() -> void:
	if not window.visible:
		return
	for tab in TAB_BUTTONS:
		tabs.get_node(TAB_BUTTONS[tab]).theme_type_variation = &"TabButtonActive" if tab == current_tab else &"TabButton"
	inventory_view.visible = current_tab == "inventory"
	character_scroll.visible = current_tab == "character"
	crafting_view.visible = current_tab == "crafting"
	map_view.visible = current_tab == "map"
	journal_view.visible = current_tab == "journal"
	# The paper doll shows the equipment itself, so the header's three slot
	# buttons would be duplicates on that tab.
	for slot in Character.SLOTS:
		_header_slot_button(slot).visible = current_tab != "character"
		_header_slot_label(slot).visible = current_tab != "character"
	_refresh_header()
	if current_tab == "inventory":
		_refresh_grid()
		_refresh_detail()
	elif current_tab == "character":
		_refresh_character()
	elif current_tab == "crafting":
		_refresh_crafting()
	elif current_tab == "map":
		map_view.refresh()
	elif current_tab == "journal":
		journal_view.refresh()

func _refresh_header() -> void:
	var stats: Dictionary = Character.stats
	name_label.text = "Oliver"
	location_label.text = "Adventurer  -  " + HUD.location_name()
	hp_bar.max_value = stats.max_hp
	hp_bar.value = stats.hp
	hp_label.text = "HP %d / %d" % [stats.hp, stats.max_hp]
	mp_bar.max_value = stats.max_mp
	mp_bar.value = stats.mp
	mp_label.text = "MP %d / %d" % [stats.mp, stats.max_mp]
	stats_label.text = "STR %d   AGI %d   DEF %d" % [stats.strength, stats.agility, Character.gear_total("defense")]
	var attack_names: Array = Character.gear_names("attack")
	bonus_label.text = "ATK +%d (%s)" % [Character.gear_total("attack"), ", ".join(attack_names)] if not attack_names.is_empty() else "No weapon equipped"
	for slot in Character.SLOTS:
		var btn: Button = _header_slot_button(slot)
		var inst: Dictionary = Character.equipped(slot)
		btn.icon = Items.get_item_icon(inst.base) if not inst.is_empty() else null
		btn.tooltip_text = Items.instance_name(inst) if not inst.is_empty() else "No %s equipped" % Character.SLOTS[slot].label.to_lower()
		btn.theme_type_variation = &"SlotButtonSelected" if selected_slot == slot and not inst.is_empty() and selected_uid == inst.uid else &"SlotButton"

func _refresh_grid() -> void:
	# Hide + queue_free (not remove_child): a refresh can run from inside a
	# slot button's own pressed signal. Hidden children are skipped by the
	# GridContainer's layout, so there's no one-frame duplicate row. They're
	# renamed first: a dying "HealingPotionSlot" still in the tree would make
	# Godot auto-rename the fresh one ("@Button@123"), breaking lookups.
	_clear(grid)
	var ids: Array = []
	for item_id in Inventory.backpack.keys():
		if Inventory.backpack[item_id] > 0:
			ids.append(item_id)
	# A selection that's no longer carried (used up / equipped) is dropped,
	# unless it now lives in an equipment slot and was selected from there.
	if selected_slot == "" and selected_item != "":
		var still_here: bool = (selected_uid == 0 and selected_item in ids) or (selected_uid != 0 and not Inventory.find_gear(selected_uid).is_empty())
		if not still_here:
			selected_item = ""
			selected_uid = 0
	for item_id in ids:
		grid.add_child(_make_slot(item_id, Inventory.backpack[item_id], selected_slot == "" and selected_uid == 0 and item_id == selected_item, {}))
	# One slot per gear INSTANCE (an enhanced pickaxe is its own thing);
	# node names stay <PascalBase>Slot for the first of a kind, then
	# <PascalBase>Slot2... so lookups by base keep working.
	var seen: Dictionary = {}
	for inst in Inventory.gear:
		seen[inst.base] = seen.get(inst.base, 0) + 1
		var btn: Button = _make_slot(inst.base, 1, selected_slot == "" and selected_uid == inst.uid, inst)
		if seen[inst.base] > 1:
			btn.name = "%sSlot%d" % [inst.base.to_pascal_case(), seen[inst.base]]
		grid.add_child(btn)
	var total: int = ids.size() + Inventory.gear.size()
	count_label.text = "%d item%s" % [total, "" if total == 1 else "s"] if total > 0 else "Nothing carried yet"

# connect_select=false for callers that wire their own pressed handler
# (the Crafting tab's recipe / enhance-target grids).
func _make_slot(item_id: String, count: int, selected: bool, inst: Dictionary, connect_select: bool = true) -> Button:
	# The slot itself is the kit's shared one (kit_window.gd), also used by
	# the shop and chest windows: icon, count badge, gold * on enhanced gear.
	return KitWindow.make_slot(item_id, count, selected, inst, connect_select, "", select_item.bind(item_id, "", inst.uid if not inst.is_empty() else 0))

func _refresh_detail() -> void:
	primary_action.visible = false
	secondary_action.visible = false
	_primary_kind = ""
	# No icon when nothing's selected, so the title starts at the pane edge
	# instead of the icon column ("No accessory equipped" clipped otherwise).
	detail_name.position.x = 68.0 if selected_item != "" else 12.0
	detail_type.position.x = detail_name.position.x
	if selected_item == "":
		var slot_word: String = Character.SLOTS[selected_slot].label.to_lower() if selected_slot != "" else ""
		detail_icon.texture = null
		detail_name.text = "No %s equipped" % slot_word if selected_slot != "" else "Select an item"
		detail_type.text = ""
		detail_desc.text = "Tap a %s in the backpack and choose Equip." % slot_word if selected_slot != "" else ""
		detail_value.text = ""
		return
	var def: Dictionary = Items.ITEMS[selected_item]
	var owned: int = Inventory.get_count(selected_item)
	var inst: Dictionary = _selected_instance()
	detail_icon.texture = Items.get_item_icon(selected_item)
	detail_name.text = Items.instance_name(inst) if not inst.is_empty() else def.name
	if Items.is_equippable(selected_item):
		var stat_text: String = Items.describe_instance(inst) if not inst.is_empty() else Items.describe_stats(selected_item)
		detail_type.text = "%s  -  %s%s" % [Character.SLOTS[def.slot].label, stat_text, "  -  equipped" if selected_slot != "" else ""]
	elif Items.is_usable(selected_item):
		detail_type.text = "Consumable  -  you have %d" % owned
	elif selected_item == "magic_crystal":
		detail_type.text = "Quest item  -  you have %d" % owned
	else:
		detail_type.text = "Material  -  you have %d" % owned
	detail_desc.text = def.get("desc", "")
	detail_value.text = "Sells for %d gold" % def.value if def.has("value") else "Cannot be sold"

	if Items.is_equippable(selected_item):
		primary_action.visible = true
		if selected_slot != "":
			primary_action.text = "Unequip"
			_primary_kind = "unequip"
		else:
			primary_action.text = "Equip"
			_primary_kind = "equip"
	elif Items.is_usable(selected_item):
		primary_action.visible = true
		primary_action.text = "Use"
		primary_action.disabled = Combat.in_combat or owned <= 0
		_primary_kind = "use"

func _on_primary_action() -> void:
	match _primary_kind:
		"use":
			if Combat.in_combat or Inventory.get_count(selected_item) <= 0:
				return
			# Same field-use rule as the quick bar: only consumed when it
			# actually did something.
			var result: Dictionary = Items.apply_effect(selected_item)
			if result.applied:
				Inventory.remove_item(selected_item, 1)
				Character.changed.emit()
			else:
				_refresh()
		"equip":
			var slot: String = Items.ITEMS[selected_item].slot
			var item_id := selected_item
			var uid := selected_uid
			Character.equip(slot, uid if uid != 0 else item_id)
			# Follow the item into its slot so the pane now offers Unequip.
			select_item(item_id, slot, Character.equipped(slot).get("uid", 0))
		"unequip":
			var item_id := selected_item
			var uid := selected_uid
			Character.unequip(selected_slot)
			select_item(item_id, "", uid)

func _on_doll_slot(slot: String) -> void:
	doll_slot = slot
	_refresh()

func _refresh_character() -> void:
	# --- Left: stats column ---
	_clear(stats_list)
	var stats: Dictionary = Character.stats
	_stats_title("Attributes")
	_stat_row("Strength", str(stats.strength))
	_stat_row("Agility", str(stats.agility))
	_stats_title("Core stats")
	_stat_row("Health", "%d / %d" % [stats.hp, stats.max_hp])
	_stat_row("Mana", "%d / %d" % [stats.mp, stats.max_mp])
	_stat_row("Attack", "+%d" % Character.gear_total("attack"))
	_stat_row("Defense", str(Character.gear_total("defense")))
	_stat_row("Status resist", "%d%%" % int(round(Character.gear_bonus("status_resistance") * 100.0)))
	_stats_title("Active effects")
	if Combat.player_status.is_empty():
		_stats_line("None", true)
	else:
		for status_id in Combat.player_status.keys():
			_stat_row(Statuses.STATUSES[status_id].name, "%d turns" % Combat.player_status[status_id].turns_left)

	# --- Centre: the doll's slots ---
	for slot in Character.SLOTS:
		var btn: Button = _doll_slot_button(slot)
		var inst: Dictionary = Character.equipped(slot)
		btn.icon = Items.get_item_icon(inst.base) if not inst.is_empty() else null
		btn.tooltip_text = Items.instance_name(inst) if not inst.is_empty() else "No %s equipped" % Character.SLOTS[slot].label.to_lower()
		btn.theme_type_variation = &"SlotButtonSelected" if slot == doll_slot else &"SlotButton"

	# --- Right (below, on a phone): what's worn in the tapped slot, and what
	# carried gear fits ---
	slot_pane_title.text = Character.SLOTS[doll_slot].label
	_clear(slot_list)
	_pane_label("Worn", true)
	var worn: Dictionary = Character.equipped(doll_slot)
	if worn.is_empty():
		_pane_label("- none -", true)
	else:
		_pane_item(worn, "Unequip", Callable(Character, "unequip").bind(doll_slot), &"SecondaryButton")
	_pane_label("Carried", true)
	var any_fit := false
	for inst in Inventory.gear:
		if Items.ITEMS[inst.base].slot == doll_slot:
			any_fit = true
			_pane_item(inst, "Equip", Callable(Character, "equip").bind(doll_slot, inst.uid), &"PrimaryButton")
	if not any_fit:
		_pane_label("- nothing fits -", true)

func _clear(container: Node) -> void:
	var dying := 0
	for child in container.get_children():
		child.name = "Dying%d" % dying
		dying += 1
		child.visible = false
		child.queue_free()

func _stats_title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"PanelTitle"
	l.add_theme_font_size_override("font_size", 14)
	stats_list.add_child(l)

func _stats_line(text: String, dim: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	if dim:
		l.theme_type_variation = &"DimLabel"
	stats_list.add_child(l)

# "Name ......... value" - two labels in a row, value right-aligned.
func _stat_row(name: String, value: String) -> void:
	var row := HBoxContainer.new()
	var n := Label.new()
	n.text = name
	n.add_theme_font_size_override("font_size", 13)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 13)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	stats_list.add_child(row)

func _pane_label(text: String, dim: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.custom_minimum_size = Vector2(94, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if dim:
		l.theme_type_variation = &"DimLabel"
	slot_list.add_child(l)

# One 94px-wide card per item: icon + "name / stat" + one action button,
# stacked compactly so a worn item plus one carried alternative fit the
# wide layout's 94px-wide pane without scrolling (a clipped Equip button
# read as broken). Cards flow vertically there and sideways on a phone.
func _pane_item(inst: Dictionary, action_text: String, action: Callable, variation: StringName) -> void:
	var item_id: String = inst.base
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(94, 0)
	card.add_theme_constant_override("separation", 4)
	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(94, 48)
	var icon_panel := Panel.new()
	icon_panel.custom_minimum_size = Vector2(48, 48)
	icon_panel.theme_type_variation = &"DetailPanel"
	var icon := TextureRect.new()
	icon.texture = Items.get_item_icon(item_id)
	icon.position = Vector2(6, 6)
	icon.size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_panel.add_child(icon)
	icon_box.add_child(icon_panel)
	card.add_child(icon_box)
	var name_label := Label.new()
	var stat_text: String = Items.describe_instance(inst)
	name_label.text = Items.instance_name(inst) + ("\n" + stat_text if stat_text != "" else "")
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.custom_minimum_size = Vector2(94, 0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)
	var btn := Button.new()
	btn.text = action_text
	btn.custom_minimum_size = Vector2(90, 32)
	btn.theme_type_variation = variation
	btn.add_theme_font_size_override("font_size", 13)
	btn.set_meta("item_id", item_id)
	btn.set_meta("uid", inst.uid)
	btn.pressed.connect(action)
	card.add_child(btn)
	slot_list.add_child(card)

# --- Crafting tab ---

func _set_craft_mode(mode: String) -> void:
	craft_mode = mode
	_clear_flash()
	_refresh()

func _apply_craft_columns() -> void:
	for section in craft_groups.get_children():
		if section is GridContainer:
			section.columns = craft_columns

# A titled section in the crafting grid area: a small gold title and a
# grid of slots under it. Returns the grid to add slots to.
func _craft_section(title: String) -> GridContainer:
	var l := Label.new()
	l.name = title.to_pascal_case().replace("&", "And") + "Title"
	l.text = title
	l.theme_type_variation = &"PanelTitle"
	l.add_theme_font_size_override("font_size", 13)
	craft_groups.add_child(l)
	var g := GridContainer.new()
	g.name = title.to_pascal_case().replace("&", "And") + "Grid"
	g.columns = craft_columns
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	craft_groups.add_child(g)
	return g

# Which Craft-mode section an item belongs in.
func _craft_group_of(item_id: String) -> String:
	if Items.is_usable(item_id):
		return CRAFT_GROUPS[0]
	if Items.is_equippable(item_id):
		return CRAFT_GROUPS[1]
	return CRAFT_GROUPS[2]

# Every slot button across the sections (order: section by section).
func craft_slots() -> Array:
	var out: Array = []
	for section in craft_groups.get_children():
		if section is GridContainer and section.visible:
			for child in section.get_children():
				if child is Button and child.visible:
					out.append(child)
	return out

# A slot by node name, e.g. "RecipeHealingPotionSlot" / "EnhanceLeatherArmorSlot2".
func craft_slot(node_name: String) -> Button:
	for btn in craft_slots():
		if btn.name == node_name:
			return btn
	return null

func _refresh_crafting() -> void:
	craft_mode_btn.theme_type_variation = &"TabButtonActive" if craft_mode == "craft" else &"TabButton"
	enhance_mode_btn.theme_type_variation = &"TabButtonActive" if craft_mode == "enhance" else &"TabButton"
	_clear(craft_groups)
	_clear(craft_rows)
	craft_action.visible = false
	craft_rows_scroll.visible = flash_kind == ""
	flash_label.visible = flash_kind != ""
	if craft_mode == "craft":
		_refresh_craft_mode()
	else:
		_refresh_enhance_mode()

# Blueprint look for a recipe slot: the result's icon tinted blue (Button's
# icon colour, so the parchment slot itself is untouched).
func _blueprint(btn: Button) -> void:
	for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		btn.add_theme_color_override(key, BLUEPRINT_TINT)

# One slot per recipe (the result's icon, as a blueprint); recipes you can't
# afford yet are dimmed. The pane shows the selected recipe's ingredient
# checklist and how many of the result you already carry.
func _refresh_craft_mode() -> void:
	if selected_recipe == "" or not Crafting.RECIPES.has(selected_recipe):
		selected_recipe = Crafting.RECIPES.keys()[0]
	var craftable := 0
	# Recipes bucketed by what they make, sections in CRAFT_GROUPS order
	# (a section only appears once something is in it).
	var groups: Dictionary = {}
	for recipe_id in Crafting.RECIPES:
		var group: String = _craft_group_of(Crafting.RECIPES[recipe_id].result)
		if not groups.has(group):
			groups[group] = []
		groups[group].append(recipe_id)
	for group in CRAFT_GROUPS:
		if not groups.has(group):
			continue
		var section: GridContainer = _craft_section(group)
		for recipe_id in groups[group]:
			var recipe: Dictionary = Crafting.RECIPES[recipe_id]
			var can: bool = Crafting.can_craft(recipe_id)
			if can:
				craftable += 1
			var btn: Button = _make_slot(recipe.result, 1, recipe_id == selected_recipe, {}, false)
			btn.name = "Recipe" + recipe_id.to_pascal_case() + "Slot"
			btn.pressed.connect(_select_recipe.bind(recipe_id))
			_blueprint(btn)
			if not can:
				btn.modulate.a = 0.55
			section.add_child(btn)
	craft_count_label.text = "%d of %d craftable" % [craftable, Crafting.RECIPES.size()]
	craft_hint.text = "Blueprints: tap one to see what it needs. Dimmed ones are missing ingredients."

	var recipe: Dictionary = Crafting.RECIPES[selected_recipe]
	var result: String = recipe.result
	var def: Dictionary = Items.ITEMS[result]
	craft_icon.texture = Items.get_item_icon(result)
	if flash_kind == "":
		craft_icon.modulate = BLUEPRINT_TINT
	craft_name.text = def.name
	var owned: int = Inventory.get_count(result)
	if Items.is_equippable(result):
		craft_type.text = "%s  -  %s  -  you have %d" % [Character.SLOTS[def.slot].label, Items.describe_stats(result), owned]
	elif Items.is_usable(result):
		craft_type.text = "Consumable  -  you have %d" % owned
	else:
		craft_type.text = "Material  -  you have %d" % owned
	craft_desc.text = def.get("desc", "")
	for item_id in recipe.cost.keys():
		_ingredient_row(item_id, recipe.cost[item_id])
	craft_action.visible = true
	if flash_kind != "":
		craft_action.text = "Crafted!"
		craft_action.disabled = true
	else:
		craft_action.text = "Craft"
		craft_action.disabled = not Crafting.can_craft(selected_recipe)

func _select_recipe(recipe_id: String) -> void:
	selected_recipe = recipe_id
	_clear_flash()
	_refresh()

# Every gear instance, carried or worn (worn ones badged), as a slot; the
# pane lists the enhancements that fit the picked one with their own
# ingredient checklists.
func _refresh_enhance_mode() -> void:
	var entries: Array = [] # [inst, worn_slot]
	for inst in Inventory.gear:
		entries.append([inst, ""])
	for slot in Character.SLOTS:
		var worn: Dictionary = Character.equipped(slot)
		if not worn.is_empty():
			entries.append([worn, slot])
	var still_there := false
	for entry in entries:
		if entry[0].uid == enhance_uid:
			still_there = true
			enhance_worn_slot = entry[1]
	if not still_there:
		enhance_uid = entries[0][0].uid if not entries.is_empty() else 0
		enhance_worn_slot = entries[0][1] if not entries.is_empty() else ""
	var seen: Dictionary = {}
	# One section per equipment slot that has any gear (Weapons / Armour /
	# Accessories), in Character.SLOTS order.
	for slot_id in Character.SLOTS:
		var in_slot: Array = entries.filter(func(e): return Items.ITEMS[e[0].base].get("slot", "") == slot_id)
		if in_slot.is_empty():
			continue
		var section: GridContainer = _craft_section(SLOT_GROUP_NAMES.get(slot_id, Character.SLOTS[slot_id].label))
		for entry in in_slot:
			var inst: Dictionary = entry[0]
			seen[inst.base] = seen.get(inst.base, 0) + 1
			var btn: Button = _make_slot(inst.base, 1, inst.uid == enhance_uid, inst, false)
			btn.name = "Enhance%sSlot%s" % [inst.base.to_pascal_case(), "" if seen[inst.base] == 1 else str(seen[inst.base])]
			btn.pressed.connect(_select_enhance_target.bind(inst.uid, entry[1]))
			if entry[1] != "":
				var worn_badge := Label.new()
				worn_badge.name = "Worn"
				worn_badge.text = "worn"
				worn_badge.position = Vector2(4, SLOT_SIZE - 18)
				worn_badge.add_theme_font_size_override("font_size", 10)
				worn_badge.theme_type_variation = &"DimLabel"
				worn_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(worn_badge)
			section.add_child(btn)
	craft_count_label.text = "%d piece%s of gear" % [entries.size(), "" if entries.size() == 1 else "s"] if not entries.is_empty() else "No gear to enhance"
	craft_hint.text = "Tap a piece of gear. Enhancing again replaces its current enhancement."
	if flash_kind == "":
		craft_icon.modulate = Color.WHITE

	if enhance_uid == 0:
		craft_icon.texture = null
		craft_name.text = "Nothing to enhance"
		craft_type.text = ""
		craft_desc.text = "Craft or find some gear first."
		return
	var inst: Dictionary = Crafting.find_instance(enhance_uid)
	var def: Dictionary = Items.ITEMS[inst.base]
	craft_icon.texture = Items.get_item_icon(inst.base)
	craft_name.text = Items.instance_name(inst)
	craft_type.text = "%s  -  %s%s" % [Character.SLOTS[def.slot].label, Items.describe_instance(inst), "  -  worn" if enhance_worn_slot != "" else ""]
	craft_desc.text = "Current: %s" % inst.mods[0].label if not inst.mods.is_empty() else "No enhancement yet."
	var options: Array = Crafting.enhancements_for(inst)
	if options.is_empty():
		_craft_row_label("Nothing fits this slot yet.", true)
		return
	if selected_enhancement == "" or not (selected_enhancement in options):
		selected_enhancement = options[0]
	var enh: Dictionary = Crafting.ENHANCEMENTS[selected_enhancement]
	_craft_row_label("%s  -  %s" % [enh.name, enh.desc], false)
	for item_id in enh.cost.keys():
		_ingredient_row(item_id, enh.cost[item_id])
	if not inst.mods.is_empty():
		_craft_row_label("Replaces %s." % inst.mods[0].label, true)
	craft_action.visible = true
	if flash_kind != "":
		craft_action.text = "Enhanced!"
		craft_action.disabled = true
	else:
		craft_action.text = "Enhance"
		craft_action.disabled = not Crafting.can_enhance(inst, selected_enhancement)

func _select_enhance_target(uid: int, worn_slot: String) -> void:
	enhance_uid = uid
	enhance_worn_slot = worn_slot
	_clear_flash()
	_refresh()

# "[icon] Wood   3 / 14" - green when you have enough, red when short.
func _ingredient_row(item_id: String, need: int) -> void:
	var row := HBoxContainer.new()
	row.name = "Ingredient" + item_id.to_pascal_case()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = Items.get_item_icon(item_id)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var name_label := Label.new()
	name_label.text = Items.get_item_name(item_id)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var have: int = Inventory.get_count(item_id)
	var count := Label.new()
	count.name = "Count"
	count.text = "%d / %d" % [have, need]
	count.add_theme_font_size_override("font_size", 13)
	count.add_theme_color_override("font_color", Color(0.55, 0.9, 0.5) if have >= need else Color(0.95, 0.45, 0.4))
	row.add_child(count)
	craft_rows.add_child(row)

func _craft_row_label(text: String, dim: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.custom_minimum_size = Vector2(craft_rows_scroll.size.x, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	if dim:
		l.theme_type_variation = &"DimLabel"
	craft_rows.add_child(l)

func _on_craft_action() -> void:
	if craft_mode == "craft":
		var result: String = Crafting.RECIPES[selected_recipe].result
		if Crafting.craft(selected_recipe):
			var owned: int = Inventory.get_count(result)
			_start_flash("craft", "Crafted %s!\nIt's in your backpack - you now have %d." % [Items.get_item_name(result), owned])
	else:
		var inst: Dictionary = Crafting.find_instance(enhance_uid)
		var before: String = Items.instance_name(inst) if not inst.is_empty() else ""
		if Crafting.enhance(enhance_uid, selected_enhancement):
			_start_flash("enhance", "Enhanced!\n%s is now %s." % [before, Items.instance_name(inst)])
	_refresh()

# The blueprint-becomes-real moment: the pane icon pops and fades from the
# blueprint tint (or a gold glow, for enhancing) to full colour, the button
# reads Crafted!/Enhanced! and the checklist is replaced by a line saying
# what happened - all for FLASH_SECONDS, or until another recipe/mode/tab
# is picked. The Inventory.changed refresh the craft itself triggers keeps
# the state (only _clear_flash() ends it early).
func _start_flash(kind: String, message: String) -> void:
	flash_kind = kind
	flash_label.text = message
	if _flash_tween != null:
		_flash_tween.kill()
	craft_icon.pivot_offset = craft_icon.size / 2.0
	craft_icon.scale = Vector2.ONE
	craft_icon.modulate = BLUEPRINT_TINT if kind == "craft" else ENHANCE_GLOW
	_flash_tween = create_tween()
	_flash_tween.tween_property(craft_icon, "scale", Vector2(1.4, 1.4), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween.parallel().tween_property(craft_icon, "modulate", Color.WHITE, 0.4)
	_flash_tween.tween_property(craft_icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_flash_id += 1
	var my_id: int = _flash_id
	get_tree().create_timer(FLASH_SECONDS).timeout.connect(func() -> void:
		if flash_kind != "" and _flash_id == my_id:
			_clear_flash()
			_refresh())

func _clear_flash() -> void:
	if flash_kind == "":
		return
	flash_kind = ""
	if _flash_tween != null:
		_flash_tween.kill()
		_flash_tween = null
	craft_icon.scale = Vector2.ONE
	craft_icon.modulate = Color.WHITE

# --- input ---

func _process(_delta: float) -> void:
	if Combat.in_combat:
		if is_open():
			close()
		return
	if Input.is_action_just_pressed("toggle_inventory"):
		toggle("inventory")
	elif Input.is_action_just_pressed("toggle_character"):
		toggle("character")
	elif Input.is_action_just_pressed("toggle_crafting"):
		toggle("crafting")
	elif Input.is_action_just_pressed("toggle_map"):
		toggle("map")
	elif Input.is_action_just_pressed("toggle_quests"):
		toggle("journal")
	elif is_open() and Input.is_action_just_pressed("ui_cancel"):
		close()
