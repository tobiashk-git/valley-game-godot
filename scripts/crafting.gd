extends Node
# Autoload — recipe registry + crafting logic, port of crafting.js. One
# recipe for now (wooden_pickaxe) to prove the pipeline; the full roster
# (potions, armor, accessories) is a later increment once those items exist.

const RECIPES := {
	"wooden_pickaxe": {
		"result": "wooden_pickaxe",
		"amount": 1,
		"cost": {"wood": 3, "stone": 2},
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
