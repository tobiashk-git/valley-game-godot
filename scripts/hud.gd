extends CanvasLayer
# Autoload — always-visible top-left resource counters, port of the JS
# HUD's wood/stone counters (plus gold, which the JS HUD doesn't show but
# is useful to see here while there's no full inventory UI yet), plus a
# small "World N" indicator once World 2 exists to distinguish from.

@onready var wood_label: Label = $Panel/Margin/HBox/WoodLabel
@onready var stone_label: Label = $Panel/Margin/HBox/StoneLabel
@onready var gold_label: Label = $Panel/Margin/HBox/GoldLabel
@onready var world_label: Label = $Panel/Margin/HBox/WorldLabel

# Every World-1 scene (Overworld and all its interiors) maps to "World 1";
# only Overworld2 (and, in the future, its own interiors) is "World 2".
const WORLD_2_SCENES := {"Overworld2": true}

var _last_scene_name := ""

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	wood_label.text = "%s: %d" % [Items.get_item_name("wood"), Inventory.get_count("wood")]
	stone_label.text = "%s: %d" % [Items.get_item_name("stone"), Inventory.get_count("stone")]
	gold_label.text = "%s: %d" % [Items.get_item_name("gold"), Inventory.get_count("gold")]

func _process(_delta: float) -> void:
	var current: Node = get_tree().current_scene
	var scene_name: String = current.name if current else ""
	if scene_name == _last_scene_name:
		return
	_last_scene_name = scene_name
	world_label.text = "World 2" if WORLD_2_SCENES.get(scene_name, false) else "World 1"
