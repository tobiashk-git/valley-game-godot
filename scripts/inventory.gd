extends Node
# Autoload — the player's backpack. Port of the getResourceCount()/addItem()
# pattern used throughout items.js/game.js, simplified to backpack-only for
# now (no pooled storage-chest counting yet — that's a later increment).

signal changed

var backpack: Dictionary = {} # item_id -> count

func add_item(item_id: String, amount: int = 1) -> void:
	backpack[item_id] = get_count(item_id) + amount
	changed.emit()

func remove_item(item_id: String, amount: int = 1) -> bool:
	var have := get_count(item_id)
	if have < amount:
		return false
	if have == amount:
		backpack.erase(item_id)
	else:
		backpack[item_id] = have - amount
	changed.emit()
	return true

func get_count(item_id: String) -> int:
	return backpack.get(item_id, 0)
