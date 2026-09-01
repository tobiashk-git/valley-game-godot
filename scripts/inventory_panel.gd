extends CanvasLayer
# Autoload — toggled with the "toggle_inventory" action (I key). Plain
# labels for materials/consumables; gear (has a Items.is_equippable slot)
# renders as a clickable row that equips it, or unequips if it's the item
# currently worn in that slot - port of inventory.js's renderInventoryPanel(),
# simplified to a flat list rather than an icon grid.

@onready var panel: Panel = $Panel
@onready var list: VBoxContainer = $Panel/Margin/VBox/List

func _ready() -> void:
	panel.visible = false
	Inventory.changed.connect(_refresh)
	Character.changed.connect(_refresh)

func _refresh() -> void:
	for child in list.get_children():
		child.queue_free()
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
			var row := Label.new()
			row.text = "%s x%d" % [Items.get_item_name(item_id), Inventory.backpack[item_id]]
			row.add_theme_font_size_override("font_size", 16)
			list.add_child(row)

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
	btn.clip_text = true # long gear descriptions must never overflow the panel
	btn.tooltip_text = label # full text still reachable on hover if clipped
	if equipped:
		btn.pressed.connect(Character.unequip.bind(slot))
	else:
		btn.pressed.connect(Character.equip.bind(slot, item_id))
	return btn

func _process(_delta: float) -> void:
	if not Combat.in_combat and Input.is_action_just_pressed("toggle_inventory"):
		panel.visible = not panel.visible
		if panel.visible:
			_refresh()
