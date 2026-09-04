extends CanvasLayer
# Autoload — the tabbed character-sheet window (UI redesign Phase 1). One
# window with a tab strip (Inventory · Character · Crafting · Journal · Map):
# the first two are real tabs living here, replacing the old InventoryPanel
# and CharacterPanel popups (still autoloaded, no longer opened by anything);
# the other three hand off to the existing CraftingPanel/QuestPanel/
# WorldMapPanel for now (Phases 2-4 bring them in here).
#
# Shared header: portrait, name, location, HP/MP, stats, three equipment
# icon slots. Inventory tab: backpack icon grid -> tap to select -> detail
# pane (icon, name, type, flavour text, value) with the actions that apply
# (Use / Equip / Unequip). Character tab: stats, gear bonuses, active effects.
# Scene skeleton from tools/setup_character_sheet.gd; the grid, detail pane
# contents and stats list are built here at runtime.

const SLOT_SIZE := 64
const EQUIP_SLOTS := ["weapon", "armor", "accessory"]
const TAB_BUTTONS := {"inventory": "InventoryTab", "character": "CharacterTab", "crafting": "CraftingTab", "journal": "JournalTab", "map": "MapTab"}
# Tabs that (for now) close this window and open the old standalone panel.
const EXTERNAL_TABS := {"crafting": "CraftingPanel", "journal": "QuestPanel", "map": "WorldMapPanel"}

@onready var window: Panel = $Window
@onready var tabs: HBoxContainer = $Window/Tabs
@onready var close_btn: Button = $Window/CloseBtn
@onready var portrait: TextureRect = $Window/Header/PortraitFrame/Portrait
@onready var name_label: Label = $Window/Header/NameLabel
@onready var location_label: Label = $Window/Header/LocationLabel
@onready var hp_bar: ProgressBar = $Window/Header/HPBar
@onready var hp_label: Label = $Window/Header/HPBar/HPLabel
@onready var mp_bar: ProgressBar = $Window/Header/MPBar
@onready var mp_label: Label = $Window/Header/MPBar/MPLabel
@onready var stats_label: Label = $Window/Header/StatsLabel
@onready var bonus_label: Label = $Window/Header/BonusLabel
@onready var inventory_view: Control = $Window/InventoryView
@onready var character_view: Control = $Window/CharacterView
@onready var count_label: Label = $Window/InventoryView/CountLabel
@onready var grid: GridContainer = $Window/InventoryView/GridScroll/Grid
@onready var detail_icon: TextureRect = $Window/InventoryView/DetailPane/DetailIcon
@onready var detail_name: Label = $Window/InventoryView/DetailPane/DetailName
@onready var detail_type: Label = $Window/InventoryView/DetailPane/DetailType
@onready var detail_desc: Label = $Window/InventoryView/DetailPane/DetailDesc
@onready var detail_value: Label = $Window/InventoryView/DetailPane/DetailValue
@onready var primary_action: Button = $Window/InventoryView/DetailPane/Actions/PrimaryAction
@onready var secondary_action: Button = $Window/InventoryView/DetailPane/Actions/SecondaryAction
@onready var stats_list: VBoxContainer = $Window/CharacterView/StatsList

var current_tab := "inventory"
var selected_item := ""
# Equipment slot the selection came from ("" = backpack). Lets the pane
# offer Unequip for a worn item and Equip for a carried one.
var selected_slot := ""
var _primary_kind := "" # "use" | "equip" | "unequip"

func _ready() -> void:
	window.visible = false
	$Dim.visible = false
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/player_base.png")
	atlas.region = Rect2(0, 128, 64, 64) # Player.tscn's down_idle frame
	portrait.texture = atlas
	for tab in TAB_BUTTONS:
		tabs.get_node(TAB_BUTTONS[tab]).pressed.connect(_on_tab_pressed.bind(tab))
	close_btn.pressed.connect(close)
	for slot in EQUIP_SLOTS:
		$Window/Header.get_node(slot.capitalize() + "Slot").pressed.connect(select_equipped.bind(slot))
	primary_action.pressed.connect(_on_primary_action)
	# Later autoloads (Inventory is earlier; Character/Combat aren't) - see
	# hud.gd for the same deferral.
	_connect_signals.call_deferred()

func _connect_signals() -> void:
	Inventory.changed.connect(_refresh)
	Character.changed.connect(_refresh)
	Combat.changed.connect(_refresh)

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
	window.visible = true
	$Dim.visible = true
	_refresh()

func close() -> void:
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

func select_item(item_id: String, from_slot: String = "") -> void:
	selected_item = item_id
	selected_slot = from_slot
	_refresh()

func select_equipped(slot: String) -> void:
	select_item(Character.equipment[slot], slot)

# --- refresh ---

func _refresh() -> void:
	if not window.visible:
		return
	for tab in TAB_BUTTONS:
		tabs.get_node(TAB_BUTTONS[tab]).theme_type_variation = &"TabButtonActive" if tab == current_tab else &"TabButton"
	inventory_view.visible = current_tab == "inventory"
	character_view.visible = current_tab == "character"
	_refresh_header()
	if current_tab == "inventory":
		_refresh_grid()
		_refresh_detail()
	elif current_tab == "character":
		_refresh_character()

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
	stats_label.text = "STR %d   AGI %d   DEF %d" % [stats.strength, stats.agility, _gear_stat("armor", "defense")]
	var weapon: String = Character.equipment.weapon
	bonus_label.text = "ATK +%d (%s)" % [_gear_stat("weapon", "attack"), Items.get_item_name(weapon)] if weapon != "" else "No weapon equipped"
	for slot in EQUIP_SLOTS:
		var btn: Button = $Window/Header.get_node(slot.capitalize() + "Slot")
		var item_id: String = Character.equipment[slot]
		btn.icon = Items.get_item_icon(item_id) if item_id != "" else null
		btn.tooltip_text = Items.get_item_name(item_id) if item_id != "" else "No %s equipped" % slot
		btn.theme_type_variation = &"SlotButtonSelected" if selected_slot == slot and item_id != "" and selected_item == item_id else &"SlotButton"

func _gear_stat(slot: String, key: String) -> int:
	var item_id: String = Character.equipment[slot]
	if item_id == "":
		return 0
	return int(Items.ITEMS[item_id].get(key, 0))

func _refresh_grid() -> void:
	# Hide + queue_free (not remove_child): a refresh can run from inside a
	# slot button's own pressed signal. Hidden children are skipped by the
	# GridContainer's layout, so there's no one-frame duplicate row. They're
	# renamed first: a dying "HealingPotionSlot" still in the tree would make
	# Godot auto-rename the fresh one ("@Button@123"), breaking lookups.
	var dying := 0
	for child in grid.get_children():
		child.name = "Dying%d" % dying
		dying += 1
		child.visible = false
		child.queue_free()
	var ids: Array = []
	for item_id in Inventory.backpack.keys():
		if Inventory.backpack[item_id] > 0:
			ids.append(item_id)
	# A selection that's no longer carried (used up / equipped) is dropped,
	# unless it now lives in an equipment slot and was selected from there.
	if selected_slot == "" and selected_item != "" and not (selected_item in ids):
		selected_item = ""
	for item_id in ids:
		grid.add_child(_make_slot(item_id, Inventory.backpack[item_id], selected_slot == "" and item_id == selected_item))
	count_label.text = "%d item%s" % [ids.size(), "" if ids.size() == 1 else "s"] if not ids.is_empty() else "Nothing carried yet"

func _make_slot(item_id: String, count: int, selected: bool) -> Button:
	var btn := Button.new()
	btn.name = item_id.to_pascal_case() + "Slot"
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.theme_type_variation = &"SlotButtonSelected" if selected else &"SlotButton"
	btn.icon = Items.get_item_icon(item_id)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = Items.get_item_name(item_id)
	btn.pressed.connect(select_item.bind(item_id, ""))
	if count > 1:
		var badge := Label.new()
		badge.name = "Count"
		badge.text = str(count)
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
		badge.position = Vector2(-22, -20)
		badge.add_theme_font_size_override("font_size", 12)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	return btn

func _refresh_detail() -> void:
	primary_action.visible = false
	secondary_action.visible = false
	_primary_kind = ""
	# No icon when nothing's selected, so the title starts at the pane edge
	# instead of the icon column ("No accessory equipped" clipped otherwise).
	detail_name.position.x = 68.0 if selected_item != "" else 12.0
	detail_type.position.x = detail_name.position.x
	if selected_item == "":
		detail_icon.texture = null
		detail_name.text = "No %s equipped" % selected_slot if selected_slot != "" else "Select an item"
		detail_type.text = ""
		detail_desc.text = "Tap a %s in the backpack and choose Equip." % selected_slot if selected_slot != "" else ""
		detail_value.text = ""
		return
	var def: Dictionary = Items.ITEMS[selected_item]
	var owned: int = Inventory.get_count(selected_item)
	detail_icon.texture = Items.get_item_icon(selected_item)
	detail_name.text = def.name
	if Items.is_equippable(selected_item):
		var stat_text: String = Items.describe_stats(selected_item)
		detail_type.text = "%s  -  %s%s" % [def.slot.capitalize(), stat_text, "  -  equipped" if selected_slot != "" else ""]
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
			Character.equip(slot, item_id)
			# Follow the item into its slot so the pane now offers Unequip.
			select_item(item_id, slot)
		"unequip":
			var item_id := selected_item
			Character.unequip(selected_slot)
			select_item(item_id, "")

func _refresh_character() -> void:
	for child in stats_list.get_children():
		child.visible = false
		child.queue_free()
	var stats: Dictionary = Character.stats
	_stats_title("Stats")
	_stats_line("Health  %d / %d" % [stats.hp, stats.max_hp])
	_stats_line("Mana  %d / %d" % [stats.mp, stats.max_mp])
	_stats_line("Strength  %d" % stats.strength)
	_stats_line("Agility  %d" % stats.agility)
	_stats_title("Equipment")
	for slot in EQUIP_SLOTS:
		var item_id: String = Character.equipment[slot]
		if item_id == "":
			_stats_line("%s  -  none" % slot.capitalize(), true)
		else:
			var stat_text: String = Items.describe_stats(item_id)
			_stats_line("%s  -  %s%s" % [slot.capitalize(), Items.get_item_name(item_id), "  (%s)" % stat_text if stat_text != "" else ""])
	_stats_title("Active effects")
	if Combat.player_status.is_empty():
		_stats_line("None", true)
	else:
		for status_id in Combat.player_status.keys():
			_stats_line("%s  (%d turns left)" % [Statuses.STATUSES[status_id].name, Combat.player_status[status_id].turns_left])

func _stats_title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"PanelTitle"
	l.add_theme_font_size_override("font_size", 14)
	stats_list.add_child(l)

func _stats_line(text: String, dim: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	if dim:
		l.theme_type_variation = &"DimLabel"
	stats_list.add_child(l)

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
	elif is_open() and Input.is_action_just_pressed("ui_cancel"):
		close()
