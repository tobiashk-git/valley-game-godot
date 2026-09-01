extends Node
# Autoload — enemy definitions, port of enemies.js through its Phase 3
# (status-attack enemies). Combat is single-enemy only; groups are a later
# increment.

const ENEMIES := {
	"dungeon_rat": {
		"name": "Dungeon Rat", "sprite": "res://assets/enemies/rat.png",
		"max_hp": 12, "attack": 3, "defense": 0, "gold_min": 3, "gold_max": 6,
		"status_attack": {"status": "poison", "chance": 0.25},
	},
	"cave_bat": {
		"name": "Cave Bat", "sprite": "res://assets/enemies/bat.png",
		"max_hp": 8, "attack": 4, "defense": 0, "gold_min": 2, "gold_max": 4,
		"status_attack": {"status": "confusion", "chance": 0.25},
	},
	"skeleton": {
		"name": "Skeleton", "sprite": "res://assets/enemies/skeleton.png",
		"max_hp": 18, "attack": 5, "defense": 2, "gold_min": 8, "gold_max": 12,
		"status_attack": {"status": "paralysis", "chance": 0.25},
	},
	"giant_spider": {
		"name": "Giant Spider", "sprite": "res://assets/enemies/spider.png",
		"max_hp": 14, "attack": 4, "defense": 1, "gold_min": 5, "gold_max": 8,
		"status_attack": {"status": "sleep", "chance": 0.3},
	},
	"ghost": {
		"name": "Ghost", "sprite": "res://assets/enemies/ghost.png",
		"max_hp": 10, "attack": 3, "defense": 0, "gold_min": 6, "gold_max": 10,
		"status_attack": {"status": "silence", "chance": 0.3},
	},
}

func pick_random_id() -> String:
	var keys := ENEMIES.keys()
	return keys[randi() % keys.size()]
