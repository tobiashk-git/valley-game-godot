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

const SLOT_SIZE := 64
# Equipment slots come from Character.SLOTS (the one slot table); the
# header/doll slot nodes are named <PascalCaseSlotId>Slot by the builder.
const TAB_BUTTONS := {"inventory": "InventoryTab", "character": "CharacterTab", "crafting": "CraftingTab", "journal": "JournalTab", "map": "MapTab"}
# Tabs that (for now) close this window and open the old standalone panel.
const EXTERNAL_TABS := {"journal": "QuestPanel", "map": "WorldMapPanel"}

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
@onready var crafting_view: Control = $Window/CraftingView
@onready var craft_mode_btn: Button = $Window/CraftingView/Modes/CraftMode
@onready var enhance_mode_btn: Button = $Window/CraftingView/Modes/EnhanceMode
@onready var craft_count_label: Label = $Window/CraftingView/CraftCountLabel
@onready var craft_grid: GridContainer = $Window/CraftingView/CraftScroll/CraftGrid
@onready var craft_icon: TextureRect = $Window/CraftingView/CraftPane/CraftIcon
@onready var craft_name: Label = $Window/CraftingView/CraftPane/CraftName
@onready var craft_type: Label = $Window/CraftingView/CraftPane/CraftType
@onready var craft_desc: Label = $Window/CraftingView/CraftPane/CraftDesc
@onready var craft_rows: VBoxContainer = $Window/CraftingView/CraftPane/CraftRowsScroll/CraftRows
@onready var craft_action: Button = $Window/CraftingView/CraftPane/CraftAction
@onready var craft_hint: Label = $Window/CraftingView/CraftHint
@onready var figure: TextureRect = $Window/CharacterView/Figure
@onready var slot_pane_title: Label = $Window/CharacterView/SlotPane/SlotPaneTitle
@onready var slot_list: VBoxContainer = $Window/CharacterView/SlotPane/SlotScroll/SlotList

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
	# Later autoloads (Inventory is earlier; Character/Combat aren't) - see
	# hud.gd for the same deferral.
	_connect_signals.call_deferred()

func _header_slot_button(slot: String) -> Button:
	return $Window/Header.get_node(slot.to_pascal_case() + "Slot")

func _header_slot_label(slot: String) -> Label:
	return $Window/Header.get_node(slot.to_pascal_case() + "SlotLabel")

func _doll_slot_button(slot: String) -> Button:
	return $Window/CharacterView.get_node("Doll%sSlot" % slot.to_pascal_case())

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
	character_view.visible = current_tab == "character"
	crafting_view.visible = current_tab == "crafting"
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
	var btn := Button.new()
	btn.name = item_id.to_pascal_case() + "Slot"
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.theme_type_variation = &"SlotButtonSelected" if selected else &"SlotButton"
	btn.icon = Items.get_item_icon(item_id)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = Items.instance_name(inst) if not inst.is_empty() else Items.get_item_name(item_id)
	if connect_select:
		btn.pressed.connect(select_item.bind(item_id, "", inst.uid if not inst.is_empty() else 0))
	if not inst.is_empty() and not inst.mods.is_empty():
		# Enhanced gear gets a small gold star so it stands out in the grid.
		var star := Label.new()
		star.name = "Enhanced"
		star.text = "*"
		star.position = Vector2(4, -2)
		star.add_theme_font_size_override("font_size", 18)
		star.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(star)
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

	# --- Right: what's worn in the tapped slot, and what carried gear fits ---
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
	if dim:
		l.theme_type_variation = &"DimLabel"
	slot_list.add_child(l)

# Icon + "name / stat" + one action button, stacked compactly so a worn
# item plus one carried alternative fit the 94px-wide pane without
# scrolling (a clipped Equip button read as broken).
func _pane_item(inst: Dictionary, action_text: String, action: Callable, variation: StringName) -> void:
	var item_id: String = inst.base
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
	slot_list.add_child(icon_box)
	var name_label := Label.new()
	var stat_text: String = Items.describe_instance(inst)
	name_label.text = Items.instance_name(inst) + ("\n" + stat_text if stat_text != "" else "")
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.custom_minimum_size = Vector2(94, 0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_list.add_child(name_label)
	var btn := Button.new()
	btn.text = action_text
	btn.custom_minimum_size = Vector2(90, 32)
	btn.theme_type_variation = variation
	btn.add_theme_font_size_override("font_size", 13)
	btn.set_meta("item_id", item_id)
	btn.set_meta("uid", inst.uid)
	btn.pressed.connect(action)
	slot_list.add_child(btn)

# --- Crafting tab ---

func _set_craft_mode(mode: String) -> void:
	craft_mode = mode
	_refresh()

func _refresh_crafting() -> void:
	craft_mode_btn.theme_type_variation = &"TabButtonActive" if craft_mode == "craft" else &"TabButton"
	enhance_mode_btn.theme_type_variation = &"TabButtonActive" if craft_mode == "enhance" else &"TabButton"
	_clear(craft_grid)
	_clear(craft_rows)
	craft_action.visible = false
	if craft_mode == "craft":
		_refresh_craft_mode()
	else:
		_refresh_enhance_mode()

# One slot per recipe (the result's icon); recipes you can't afford yet are
# dimmed. The pane shows the selected recipe's ingredient checklist.
func _refresh_craft_mode() -> void:
	if selected_recipe == "" or not Crafting.RECIPES.has(selected_recipe):
		selected_recipe = Crafting.RECIPES.keys()[0]
	var craftable := 0
	for recipe_id in Crafting.RECIPES:
		var recipe: Dictionary = Crafting.RECIPES[recipe_id]
		var can: bool = Crafting.can_craft(recipe_id)
		if can:
			craftable += 1
		var btn: Button = _make_slot(recipe.result, 1, recipe_id == selected_recipe, {}, false)
		btn.name = "Recipe" + recipe_id.to_pascal_case() + "Slot"
		btn.pressed.connect(_select_recipe.bind(recipe_id))
		if not can:
			btn.modulate.a = 0.55
		craft_grid.add_child(btn)
	craft_count_label.text = "%d of %d craftable" % [craftable, Crafting.RECIPES.size()]
	craft_hint.text = "Tap a recipe to see what it needs. Dimmed ones are missing ingredients."

	var recipe: Dictionary = Crafting.RECIPES[selected_recipe]
	var result: String = recipe.result
	var def: Dictionary = Items.ITEMS[result]
	craft_icon.texture = Items.get_item_icon(result)
	craft_name.text = def.name
	if Items.is_equippable(result):
		craft_type.text = "%s  -  %s" % [Character.SLOTS[def.slot].label, Items.describe_stats(result)]
	elif Items.is_usable(result):
		craft_type.text = "Consumable"
	else:
		craft_type.text = "Material"
	craft_desc.text = def.get("desc", "")
	for item_id in recipe.cost.keys():
		_ingredient_row(item_id, recipe.cost[item_id])
	craft_action.visible = true
	craft_action.text = "Craft"
	craft_action.disabled = not Crafting.can_craft(selected_recipe)

func _select_recipe(recipe_id: String) -> void:
	selected_recipe = recipe_id
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
	for entry in entries:
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
		craft_grid.add_child(btn)
	craft_count_label.text = "%d piece%s of gear" % [entries.size(), "" if entries.size() == 1 else "s"] if not entries.is_empty() else "No gear to enhance"
	craft_hint.text = "Tap a piece of gear. Enhancing again replaces its current enhancement."

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
	craft_action.text = "Enhance"
	craft_action.disabled = not Crafting.can_enhance(inst, selected_enhancement)

func _select_enhance_target(uid: int, worn_slot: String) -> void:
	enhance_uid = uid
	enhance_worn_slot = worn_slot
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
	l.custom_minimum_size = Vector2(224, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	if dim:
		l.theme_type_variation = &"DimLabel"
	craft_rows.add_child(l)

func _on_craft_action() -> void:
	if craft_mode == "craft":
		Crafting.craft(selected_recipe)
	else:
		Crafting.enhance(enhance_uid, selected_enhancement)
	_refresh()

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
	elif is_open() and Input.is_action_just_pressed("ui_cancel"):
		close()
