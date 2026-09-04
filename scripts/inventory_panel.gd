extends CanvasLayer
# Autoload — toggled with the "toggle_inventory" action (I key). An
# Equipment section (Weapon/Armor/Accessory slots) up top, then the
# backpack below: plain labels for materials/consumables; gear (has a
# Items.is_equippable slot) renders as a clickable row that equips it, or
# unequips if it's the item currently worn in that slot - port of
# inventory.js's renderInventoryPanel(), simplified to a flat list rather
# than an icon grid.
#
# The Equipment section exists so equipping is visible in-place: Character.
# equip() consumes the item from the backpack (a single-copy gear model, not
# a stack), so a click on a gear row with only 1 owned makes that row
# vanish from the backpack list with nothing else to show where it went -
# reported as "it just disappears and you don't know where its gone".

@onready var panel: Panel = $Panel
@onready var list: VBoxContainer = $Panel/Margin/VBox/List

const SLOTS := ["weapon", "armor", "accessory"]

func _ready() -> void:
	panel.visible = false
	Inventory.changed.connect(_refresh)
	Character.changed.connect(_refresh)

func _refresh() -> void:
	for child in list.get_children():
		child.queue_free()

	var equip_title := Label.new()
	equip_title.text = "Equipment"
	equip_title.theme_type_variation = &"PanelTitle"
	equip_title.add_theme_font_size_override("font_size", 14)
	list.add_child(equip_title)
	for slot in SLOTS:
		list.add_child(_build_equipment_row(slot))

	var sep := HSeparator.new()
	list.add_child(sep)

	var backpack_title := Label.new()
	backpack_title.text = "Backpack"
	backpack_title.theme_type_variation = &"PanelTitle"
	backpack_title.add_theme_font_size_override("font_size", 14)
	list.add_child(backpack_title)

	if Inventory.backpack.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		empty_label.theme_type_variation = &"DimLabel"
		list.add_child(empty_label)
		return
	for item_id in Inventory.backpack.keys():
		if Items.is_equippable(item_id):
			list.add_child(_build_gear_row(item_id))
		else:
			# RichTextLabel (not Label) - embeds an inline item icon via
			# BBCode (Items.get_item_name_bbcode()).
			var row := RichTextLabel.new()
			row.bbcode_enabled = true
			row.fit_content = true
			row.scroll_active = false
			row.text = "%s x%d" % [Items.get_item_name_bbcode(item_id), Inventory.backpack[item_id]]
			row.add_theme_font_size_override("normal_font_size", 16)
			list.add_child(row)

# Empty slot: plain (non-interactive) label. Filled slot: a button, click
# to unequip - matching the same click-to-toggle model the backpack's own
# gear rows already use, so an equipped item can be sent back to the
# backpack from either place it's shown.
func _build_equipment_row(slot: String) -> Control:
	var item_id: String = Character.equipment[slot]
	var slot_name: String = slot.capitalize()
	if item_id == "":
		var row := Label.new()
		row.text = "%s: (empty)" % slot_name
		row.theme_type_variation = &"DimLabel"
		row.add_theme_font_size_override("font_size", 14)
		return row

	var stats := Items.describe_stats(item_id)
	var label := "%s: %s (%s)" % [slot_name, Items.get_item_name(item_id), stats] if stats != "" else "%s: %s" % [slot_name, Items.get_item_name(item_id)]
	var btn := Button.new()
	btn.text = label
	btn.icon = Items.get_item_icon(item_id)
	btn.clip_text = true
	btn.tooltip_text = label
	btn.pressed.connect(Character.unequip.bind(slot))
	return btn

func _build_gear_row(item_id: String) -> Button:
	var slot: String = Items.ITEMS[item_id].slot
	var equipped: bool = Character.equipment[slot] == item_id
	var stats := Items.describe_stats(item_id)
	var label := "%s x%d (%s)%s" % [
		Items.get_item_name(item_id), Inventory.backpack[item_id], stats,
		" [Equipped]" if equipped else "",
	]
	var btn := Button.new()
	btn.text = label
	btn.icon = Items.get_item_icon(item_id)
	btn.clip_text = true # long gear descriptions must never overflow the panel
	btn.tooltip_text = label # full text still reachable on hover if clipped
	if equipped:
		btn.pressed.connect(Character.unequip.bind(slot))
	else:
		btn.pressed.connect(Character.equip.bind(slot, item_id))
	return btn

func is_open() -> bool:
	return panel.visible

func open() -> void:
	panel.visible = true
	_refresh()

func close() -> void:
	panel.visible = false

func toggle_open() -> void:
	if panel.visible:
		close()
	else:
		open()

# The I key now opens the Inventory tab of the CharacterSheet window (UI
# redesign Phase 1); this panel stays autoloaded but nothing opens it any
# more. Removed entirely in a later phase.
