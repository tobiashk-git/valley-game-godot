extends Node
# Autoload — enemy definitions, port of the original (pre-groups, pre-status)
# ENEMY_DEFS in enemies.js. Combat Phase 1 is single-enemy only; groups are
# a later increment.

const ENEMIES := {
	"dungeon_rat": {
		"name": "Dungeon Rat", "sprite": "res://assets/enemies/rat.png",
		"max_hp": 12, "attack": 3, "defense": 0, "gold_min": 3, "gold_max": 6,
	},
	"cave_bat": {
		"name": "Cave Bat", "sprite": "res://assets/enemies/bat.png",
		"max_hp": 8, "attack": 4, "defense": 0, "gold_min": 2, "gold_max": 4,
	},
	"skeleton": {
		"name": "Skeleton", "sprite": "res://assets/enemies/skeleton.png",
		"max_hp": 18, "attack": 5, "defense": 2, "gold_min": 8, "gold_max": 12,
	},
}

func pick_random_id() -> String:
	var keys := ENEMIES.keys()
	return keys[randi() % keys.size()]
