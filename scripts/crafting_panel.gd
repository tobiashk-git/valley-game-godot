extends CanvasLayer
# Autoload — toggled with the "toggle_crafting" action (R key). Lists every
# Crafting.RECIPES entry with a Craft button, disabled when materials are
# short - port of crafting.js's renderCraftingPanel(), simplified.

@onready var panel: Panel = $Panel
@onready var list: VBoxContainer = $Panel/Margin/VBox/List

func _ready() -> void:
	panel.visible = false
	Inventory.changed.connect(_refresh)

func _cost_text(cost: Dictionary) -> String:
	var text := ""
	var first := true
	for item_id in cost.keys():
		if not first:
			text += ", "
		text += "%d %s" % [cost[item_id], Items.get_item_name(item_id)]
		first = false
	return text

func _refresh() -> void:
	for child in list.get_children():
		child.queue_free()
	for recipe_id in Crafting.RECIPES.keys():
		var recipe: Dictionary = Crafting.RECIPES[recipe_id]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)

		var label := Label.new()
		label.text = "%s (%s)" % [Items.get_item_name(recipe.result), _cost_text(recipe.cost)]
		label.custom_minimum_size = Vector2(220, 0)
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)

		var btn := Button.new()
		btn.text = "Craft"
		btn.disabled = not Crafting.can_craft(recipe_id)
		btn.pressed.connect(_on_craft.bind(recipe_id))
		row.add_child(btn)

func _on_craft(recipe_id: String) -> void:
	Crafting.craft(recipe_id)
	_refresh()

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

func _process(_delta: float) -> void:
	if not Combat.in_combat and Input.is_action_just_pressed("toggle_crafting"):
		toggle_open()
