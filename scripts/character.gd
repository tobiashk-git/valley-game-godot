extends Node
# Autoload — Oliver's stats + equipment slots. Port of the `character`
# object in game.js. No combat exists yet so these stats aren't consumed by
# anything mechanically yet (same starting point the JS project had before
# its own combat phase), but the data model and UI shell are worth having
# ready before that lands.

signal changed

var stats: Dictionary = {
	"hp": 20, "max_hp": 20,
	"mp": 10, "max_mp": 10,
	"strength": 5, "agility": 5,
}

# slot -> item_id or "" (empty)
var equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"accessory": "",
}

func equip(slot: String, item_id: String) -> void:
	equipment[slot] = item_id
	changed.emit()

func unequip(slot: String) -> void:
	equipment[slot] = ""
	changed.emit()
