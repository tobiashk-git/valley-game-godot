extends Node
# Autoload — recipe registry + crafting logic, port of crafting.js. Recipes
# stick to existing materials (wood/stone) since no herb-gathering exists
# yet; armor/accessory recipes are a later increment once those items exist.

const RECIPES := {
	"wooden_pickaxe": {
		"result": "wooden_pickaxe",
		"amount": 1,
		"cost": {"wood": 3, "stone": 2},
	},
	"healing_potion": {
		"result": "healing_potion",
		"amount": 1,
		"cost": {"wood": 2, "stone": 1},
	},
	"mana_potion": {
		"result": "mana_potion",
		"amount": 1,
		"cost": {"wood": 1, "stone": 2},
	},
	"antidote": {
		"result": "antidote",
		"amount": 1,
		"cost": {"wood": 2, "stone": 2},
	},
}

func can_craft(recipe_id: String) -> bool:
	var recipe: Dictionary = RECIPES[recipe_id]
	var cost: Dictionary = recipe.cost
	for item_id in cost.keys():
		if Inventory.get_count(item_id) < cost[item_id]:
			return false
	return true

func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	var cost: Dictionary = recipe.cost
	for item_id in cost.keys():
		Inventory.remove_item(item_id, cost[item_id])
	Inventory.add_item(recipe.result, recipe.amount)
	return true
