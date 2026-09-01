extends CanvasLayer
# Autoload — toggled with the "toggle_inventory" action (I key). A plain
# list of backpack contents for now (icons/grid/equip slots are a later
# increment) - port of inventory.js's renderInventoryPanel(), simplified.

@onready var panel: Panel = $Panel
@onready var list: VBoxContainer = $Panel/Margin/VBox/List

func _ready() -> void:
	panel.visible = false
	Inventory.changed.connect(_refresh)

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
		var row := Label.new()
		row.text = "%s x%d" % [Items.get_item_name(item_id), Inventory.backpack[item_id]]
		row.add_theme_font_size_override("font_size", 16)
		list.add_child(row)

func _process(_delta: float) -> void:
	if not Combat.in_combat and Input.is_action_just_pressed("toggle_inventory"):
		panel.visible = not panel.visible
		if panel.visible:
			_refresh()
