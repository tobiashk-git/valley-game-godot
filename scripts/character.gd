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

# Equipping consumes 1 of item_id from the backpack; any item already in
# that slot is returned to the backpack first (a swap, not a stack).
func equip(slot: String, item_id: String) -> void:
	if not Inventory.remove_item(item_id, 1):
		return
	var previous: String = equipment[slot]
	if previous != "":
		Inventory.add_item(previous, 1)
	equipment[slot] = item_id
	changed.emit()

func unequip(slot: String) -> void:
	var item_id: String = equipment[slot]
	if item_id == "":
		return
	Inventory.add_item(item_id, 1)
	equipment[slot] = ""
	changed.emit()
