extends CanvasLayer
# Autoload — always-visible top-left resource counters, port of the JS
# HUD's wood/stone counters (plus gold, which the JS HUD doesn't show but
# is useful to see here while there's no full inventory UI yet).

@onready var wood_label: Label = $Panel/Margin/HBox/WoodLabel
@onready var stone_label: Label = $Panel/Margin/HBox/StoneLabel
@onready var gold_label: Label = $Panel/Margin/HBox/GoldLabel

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	wood_label.text = "Wood: %d" % Inventory.get_count("wood")
	stone_label.text = "Stone: %d" % Inventory.get_count("stone")
	gold_label.text = "Gold: %d" % Inventory.get_count("gold")
