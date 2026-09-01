extends Node
# Autoload — enemy definitions, port of enemies.js through its boss-battle
# phase. BOSSES is a deliberately separate dict from ENEMIES (mirrors the
# JS reference) so pick_random_id()/Combat's group-picker — which only ever
# read ENEMIES — can never accidentally roll a boss into a random encounter.

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

# One boss per location, each reusing an existing enemy sprite with a tint
# (both battle_panel.gd and tools/setup_boss.gd apply the same per-boss tint
# - kept as plain literals in both rather than adding a shared-constant
# indirection for three colors) rather than sourcing new boss-specific art.
# drop_item_ids is a list (not a single id) since the two Guardians each
# also drop a Magic Crystal alongside their usual gear - see altar.gd.
const BOSSES := {
	"dungeon_boss": {
		"name": "Bone Lord", "sprite": "res://assets/enemies/skeleton.png",
		"tint": Color(0.55, 0.35, 0.75, 1.0),
		"max_hp": 60, "attack": 8, "defense": 3, "gold_min": 40, "gold_max": 60,
		"status_attack": {"status": "paralysis", "chance": 0.2},
		"drop_item_ids": ["bone_greatsword", "magic_crystal"],
	},
	"castle_boss": {
		"name": "Royal Wraith", "sprite": "res://assets/enemies/ghost.png",
		"tint": Color(0.85, 0.7, 0.25, 1.0),
		"max_hp": 80, "attack": 9, "defense": 4, "gold_min": 60, "gold_max": 90,
		"status_attack": {"status": "silence", "chance": 0.25},
		"drop_item_ids": ["royal_plate", "magic_crystal"],
	},
	# The two Guardians' crystals reveal this one's hiding place (see
	# altar.gd); roughly double their stats, per the plan's own first-pass
	# tuning note. Reuses the Giant Spider sprite, tinted dark red/black -
	# distinct from both Guardians' purple/gold.
	"final_boss": {
		"name": "The Ancient Warden", "sprite": "res://assets/enemies/spider.png",
		"tint": Color(0.5, 0.1, 0.1, 1.0),
		"max_hp": 150, "attack": 17, "defense": 7, "gold_min": 150, "gold_max": 200,
		"status_attack": {"status": "paralysis", "chance": 0.3},
		"drop_item_ids": ["magic_crystal"],
	},
}
