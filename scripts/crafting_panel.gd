extends CanvasLayer
# Autoload — toggled with the "toggle_crafting" action (R key). Lists every
# Crafting.RECIPES entry with a Craft button, disabled when materials are
# short - port of crafting.js's renderCraftingPanel(), simplified.

@onready var panel: Panel = $Panel
@onready var list: VBoxContainer = $Panel/Margin/VBox/List

func _ready() -> void:
	panel.visible = false
	Inventory.changed.connect(_refresh)

func _cost_text_bbcode(cost: Dictionary) -> String:
	var text := ""
	var first := true
	for item_id in cost.keys():
		if not first:
			text += ", "
		text += "%d %s" % [cost[item_id], Items.get_item_name_bbcode(item_id)]
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

		# RichTextLabel (not Label) so the result's and each cost material's
		# icon can be embedded inline via BBCode - a single line can name
		# more than one item ("Axe (3 Wood, 2 Stone)"), which a plain
		# Label+TextureRect pair can't express for more than one icon.
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.text = "%s (%s)" % [Items.get_item_name_bbcode(recipe.result), _cost_text_bbcode(recipe.cost)]
		# Wider than the old plain-Label version (220) - inline icons eat
		# horizontal space BBCode text alone didn't need, and were wrapping
		# every recipe onto 2 lines even though the panel has plenty of
		# room to spare to the right of these rows.
		label.custom_minimum_size = Vector2(480, 0)
		label.add_theme_font_size_override("normal_font_size", 14)
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
