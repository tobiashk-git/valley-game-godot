extends Node
# Autoload — enemy definitions, port of enemies.js through its boss-battle
# phase. BOSSES is a deliberately separate dict from ENEMIES (mirrors the
# JS reference) so pick_random_id()/Combat's group-picker — which only ever
# read ENEMIES — can never accidentally roll a boss into a random encounter.
#
# Every entry has a "zones" field for the biome revamp's per-biome encounter
# pools (see pick_random_id_for_zone()). The original 5 (dungeon-only) get
# "zones": [] - empty means "the interior/dungeon pool", never picked for an
# overworld biome, and pick_random_id() (used by every existing maze_
# interior.gd call site, unchanged) filters to exactly that empty-zones set,
# so those 5 keep behaving byte-for-byte as before. The 12 new ones below
# are each tagged with exactly one outer biome's Zone, reusing the 5
# existing sprite files with a distinct tint - the exact technique already
# used for all 3 bosses - so this needs zero new art assets.

const ENEMIES := {
	"dungeon_rat": {
		"name": "Dungeon Rat", "sprite": "res://assets/enemies/rat.png",
		"max_hp": 12, "attack": 3, "defense": 0, "gold_min": 3, "gold_max": 6,
		"status_attack": {"status": "poison", "chance": 0.25}, "zones": [],
	},
	"cave_bat": {
		"name": "Cave Bat", "sprite": "res://assets/enemies/bat.png",
		"max_hp": 8, "attack": 4, "defense": 0, "gold_min": 2, "gold_max": 4,
		"status_attack": {"status": "confusion", "chance": 0.25}, "zones": [],
	},
	"skeleton": {
		"name": "Skeleton", "sprite": "res://assets/enemies/skeleton.png",
		"max_hp": 18, "attack": 5, "defense": 2, "gold_min": 8, "gold_max": 12,
		"status_attack": {"status": "paralysis", "chance": 0.25}, "zones": [],
	},
	"giant_spider": {
		"name": "Giant Spider", "sprite": "res://assets/enemies/spider.png",
		"max_hp": 14, "attack": 4, "defense": 1, "gold_min": 5, "gold_max": 8,
		"status_attack": {"status": "sleep", "chance": 0.3}, "zones": [],
	},
	"ghost": {
		"name": "Ghost", "sprite": "res://assets/enemies/ghost.png",
		"max_hp": 10, "attack": 3, "defense": 0, "gold_min": 6, "gold_max": 10,
		"status_attack": {"status": "silence", "chance": 0.3}, "zones": [],
	},

	# --- Frostpeak Ridge (north) ---
	"ice_wraith": {
		"name": "Ice Wraith", "sprite": "res://assets/enemies/ghost.png", "tint": Color(0.55, 0.8, 0.95, 1.0),
		"max_hp": 16, "attack": 5, "defense": 1, "gold_min": 6, "gold_max": 10,
		"status_attack": {"status": "paralysis", "chance": 0.25}, "zones": [World.Zone.FROSTPEAK],
		"drop_item_ids": ["monster_fur"],
	},
	"frost_wolf": {
		"name": "Frost Wolf", "sprite": "res://assets/enemies/spider.png", "tint": Color(0.75, 0.85, 0.95, 1.0),
		"max_hp": 14, "attack": 6, "defense": 0, "gold_min": 5, "gold_max": 9,
		"status_attack": {"status": "sleep", "chance": 0.2}, "zones": [World.Zone.FROSTPEAK],
		"drop_item_ids": ["monster_fur"],
	},
	"stone_sentinel": {
		"name": "Stone Sentinel", "sprite": "res://assets/enemies/skeleton.png", "tint": Color(0.5, 0.5, 0.52, 1.0),
		"max_hp": 22, "attack": 5, "defense": 4, "gold_min": 8, "gold_max": 14, "zones": [World.Zone.FROSTPEAK],
		"drop_item_ids": ["monster_fur"],
	},

	# --- Verdantwood Forest (east) ---
	"forest_spirit": {
		"name": "Forest Spirit", "sprite": "res://assets/enemies/ghost.png", "tint": Color(0.3, 0.75, 0.35, 1.0),
		"max_hp": 15, "attack": 4, "defense": 1, "gold_min": 6, "gold_max": 10,
		"status_attack": {"status": "confusion", "chance": 0.25}, "zones": [World.Zone.VERDANTWOOD],
		"drop_item_ids": ["monster_fur"],
	},
	"bandit": {
		"name": "Bandit", "sprite": "res://assets/enemies/skeleton.png", "tint": Color(0.55, 0.4, 0.25, 1.0),
		"max_hp": 18, "attack": 6, "defense": 2, "gold_min": 10, "gold_max": 16, "zones": [World.Zone.VERDANTWOOD],
		"drop_item_ids": ["monster_fur"],
	},
	"corrupted_fauna": {
		"name": "Corrupted Fauna", "sprite": "res://assets/enemies/spider.png", "tint": Color(0.35, 0.15, 0.4, 1.0),
		"max_hp": 16, "attack": 5, "defense": 1, "gold_min": 6, "gold_max": 11,
		"status_attack": {"status": "poison", "chance": 0.25}, "zones": [World.Zone.VERDANTWOOD],
		"drop_item_ids": ["monster_fur"],
	},

	# --- Emberfall Badlands (south) ---
	"magma_slime": {
		"name": "Magma Slime", "sprite": "res://assets/enemies/rat.png", "tint": Color(0.9, 0.35, 0.1, 1.0),
		"max_hp": 16, "attack": 5, "defense": 0, "gold_min": 6, "gold_max": 10,
		"status_attack": {"status": "poison", "chance": 0.2}, "zones": [World.Zone.BADLANDS],
		# Ember Core (Crafting's Ember-forged enhancement) is a Badlands-only
		# chance drop - the Fire Drake is the best source, so it's worth
		# hunting specifically.
		"drop_item_ids": ["monster_fur", {"item": "ember_core", "chance": 0.3}],
	},
	"fire_drake": {
		"name": "Fire Drake", "sprite": "res://assets/enemies/bat.png", "tint": Color(0.85, 0.3, 0.1, 1.0),
		"max_hp": 18, "attack": 7, "defense": 1, "gold_min": 9, "gold_max": 15, "zones": [World.Zone.BADLANDS],
		"drop_item_ids": ["monster_fur", {"item": "ember_core", "chance": 0.5}],
	},
	"ash_golem": {
		"name": "Ash Golem", "sprite": "res://assets/enemies/skeleton.png", "tint": Color(0.25, 0.22, 0.2, 1.0),
		"max_hp": 24, "attack": 6, "defense": 4, "gold_min": 10, "gold_max": 16, "zones": [World.Zone.BADLANDS],
		"drop_item_ids": ["monster_fur", {"item": "ember_core", "chance": 0.3}],
	},

	# --- Gloomfen Marsh (west) ---
	"swamp_hag": {
		"name": "Swamp Hag", "sprite": "res://assets/enemies/skeleton.png", "tint": Color(0.35, 0.45, 0.3, 1.0),
		"max_hp": 17, "attack": 5, "defense": 2, "gold_min": 7, "gold_max": 12,
		"status_attack": {"status": "silence", "chance": 0.25}, "zones": [World.Zone.GLOOMFEN],
		"drop_item_ids": ["monster_fur"],
	},
	"giant_insect": {
		"name": "Giant Insect", "sprite": "res://assets/enemies/spider.png", "tint": Color(0.4, 0.55, 0.25, 1.0),
		"max_hp": 15, "attack": 5, "defense": 1, "gold_min": 6, "gold_max": 10,
		"status_attack": {"status": "poison", "chance": 0.3}, "zones": [World.Zone.GLOOMFEN],
		"drop_item_ids": ["monster_fur"],
	},
	"spectral_undead": {
		"name": "Spectral Undead", "sprite": "res://assets/enemies/ghost.png", "tint": Color(0.55, 0.6, 0.55, 1.0),
		"max_hp": 19, "attack": 6, "defense": 1, "gold_min": 8, "gold_max": 13,
		"status_attack": {"status": "sleep", "chance": 0.25}, "zones": [World.Zone.GLOOMFEN],
		"drop_item_ids": ["monster_fur"],
	},
}

# The dungeon/castle/final-boss interior pool - unchanged behavior, still a
# uniform pick over exactly the same 5 ids as before the biome revamp.
func pick_random_id() -> String:
	var keys: Array = ENEMIES.keys().filter(func(id): return ENEMIES[id].zones.is_empty())
	return keys[randi() % keys.size()]

# The biome revamp's per-outer-biome pool (Golden Plains/VALLEY has no
# entries and is never passed here - see overworld.gd's zone != VALLEY guard).
func pick_random_id_for_zone(zone: int) -> String:
	var keys: Array = ENEMIES.keys().filter(func(id): return ENEMIES[id].zones.has(zone))
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
	# Frostpeak Ridge's own interior boss (Phase 2 of the biome revamp) - no
	# magic_crystal drop deliberately. altar.gd only checks the *count* of
	# magic_crystal in inventory, not its source, so adding a third crystal
	# source would let a third boss substitute for either of the two
	# Guardians (dungeon_boss/castle_boss), which the altar's reveal
	# condition is written around as a fixed pair. Reuses the Ghost sprite,
	# tinted pale icy blue.
	"frostpeak_boss": {
		"name": "Glacial Revenant", "sprite": "res://assets/enemies/ghost.png",
		"tint": Color(0.65, 0.85, 1.0, 1.0),
		"max_hp": 70, "attack": 8, "defense": 4, "gold_min": 45, "gold_max": 65,
		"status_attack": {"status": "paralysis", "chance": 0.25},
		"drop_item_ids": ["healing_potion"],
	},
	# Verdantwood Forest's own interior boss (Phase 3) - same no-magic_crystal
	# reasoning as frostpeak_boss above. Reuses the Giant Spider sprite,
	# tinted deep forest green - distinct from final_boss's dark red/black
	# tint on the same base sprite.
	"verdantwood_boss": {
		"name": "Elder Bramblewood", "sprite": "res://assets/enemies/spider.png",
		"tint": Color(0.2, 0.45, 0.15, 1.0),
		"max_hp": 75, "attack": 8, "defense": 4, "gold_min": 45, "gold_max": 65,
		"status_attack": {"status": "sleep", "chance": 0.25},
		"drop_item_ids": ["healing_potion"],
	},
	# Guards the one gated glade in the Verdantwood overland maze (Phase 1
	# prototype, see World.carve_verdantwood_maze()) - an overworld "mini
	# guardian", not a dungeon final boss, so stats are scaled down from
	# verdantwood_boss (roughly half HP/gold) rather than reusing them
	# outright. Distinct id from verdantwood_boss, already claimed by
	# VerdantwoodInterior.tscn's own dungeon boss.
	"verdantwood_maze_guardian_1": {
		"name": "Thornback Warden", "sprite": "res://assets/enemies/skeleton.png",
		"tint": Color(0.35, 0.5, 0.25, 1.0),
		"max_hp": 38, "attack": 7, "defense": 3, "gold_min": 20, "gold_max": 35,
		"status_attack": {"status": "sleep", "chance": 0.2},
		"drop_item_ids": ["healing_potion"],
	},
	# Emberfall Badlands' own interior boss (Phase 4) - same no-magic_crystal
	# reasoning as frostpeak_boss/verdantwood_boss above. Reuses the Rat
	# sprite (not yet used for a biome boss), tinted volcanic orange/red.
	"badlands_boss": {
		"name": "Cinderjaw", "sprite": "res://assets/enemies/rat.png",
		"tint": Color(0.75, 0.25, 0.1, 1.0),
		"max_hp": 78, "attack": 9, "defense": 3, "gold_min": 45, "gold_max": 65,
		"status_attack": {"status": "poison", "chance": 0.25},
		"drop_item_ids": ["healing_potion"],
	},
	# Gloomfen Marsh's own interior boss (Phase 5) - same no-magic_crystal
	# reasoning as frostpeak_boss/verdantwood_boss/badlands_boss above. Reuses
	# the Bat sprite (not yet used for a biome boss), tinted murky purple-green.
	"gloomfen_boss": {
		"name": "The Bogmaw", "sprite": "res://assets/enemies/bat.png",
		"tint": Color(0.4, 0.3, 0.45, 1.0),
		"max_hp": 80, "attack": 9, "defense": 4, "gold_min": 45, "gold_max": 65,
		"status_attack": {"status": "silence", "chance": 0.25},
		"drop_item_ids": ["healing_potion"],
	},
	# Golden Plains' own interior boss (Phase 6) - unlike the 4 outer-biome
	# bosses above, this one is deliberately weak (below even dungeon_boss'
	# tier): the roadmap frames Golden Plains as low-danger/story-forward, a
	# "guardian spirit" testing the player rather than threatening them, not
	# a combat gauntlet. Reuses the Skeleton sprite (already used once for
	# dungeon_boss, tinted purple there) with a warm gold/tan tint instead.
	# No magic_crystal drop, same rule as every non-Guardian boss.
	"golden_plains_boss": {
		"name": "The Barrow Warden", "sprite": "res://assets/enemies/skeleton.png",
		"tint": Color(0.8, 0.7, 0.45, 1.0),
		"max_hp": 40, "attack": 5, "defense": 2, "gold_min": 25, "gold_max": 40,
		"drop_item_ids": ["healing_potion"],
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

# XP a beaten enemy is worth: half its HP plus its attack and twice its
# defence (a tough, hard-hitting thing pays more), doubled for a boss.
# Derived rather than stored so every existing entry pays out without a
# per-enemy field.
static func xp_for(def: Dictionary, is_boss: bool = false) -> int:
	var base: int = int(ceil(float(def.max_hp) / 2.0)) + int(def.attack) + 2 * int(def.defense)
	return base * 2 if is_boss else base
