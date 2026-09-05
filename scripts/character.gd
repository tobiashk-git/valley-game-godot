extends Node
# Autoload — Oliver's stats + equipment slots. Port of the `character`
# object in game.js.

signal changed

var stats: Dictionary = {
	"hp": 20, "max_hp": 20,
	"mp": 10, "max_mp": 10,
	"strength": 5, "agility": 5,
	"level": 1, "xp": 0, # xp counts within the current level (see gain_xp)
}

# Levelling: every fight pays XP (Enemies.xp_for()); a level costs
# xp_to_next(level) and each one raises the caps and strength, agility on
# even levels, with a full heal - the classic feel. Agility only does
# something above its starting value (dodge_chance()), so the verifies that
# assume every enemy hit lands keep holding at level 1.
const MAX_LEVEL := 30
const LEVEL_UP_HP := 4
const LEVEL_UP_MP := 2
const LEVEL_UP_STR := 1
const BASE_AGILITY := 5
const DODGE_PER_AGILITY := 0.02
const DODGE_MAX := 0.3

signal levelled_up(new_level: int)

static func xp_to_next(level: int) -> int:
	return 30 * level

# Adds XP, applies every level reached, returns how many levels were gained.
func gain_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var gained := 0
	stats.xp += amount
	while stats.level < MAX_LEVEL and stats.xp >= xp_to_next(stats.level):
		stats.xp -= xp_to_next(stats.level)
		stats.level += 1
		gained += 1
		stats.max_hp += LEVEL_UP_HP
		stats.max_mp += LEVEL_UP_MP
		stats.strength += LEVEL_UP_STR
		if stats.level % 2 == 0:
			stats.agility += 1
		stats.hp = stats.max_hp
		stats.mp = stats.max_mp
		levelled_up.emit(stats.level)
	if stats.level >= MAX_LEVEL:
		stats.xp = 0
	changed.emit()
	return gained

# What one level brings, for the battle log / sheet.
static func level_up_text(new_level: int) -> String:
	var parts: Array[String] = ["+%d HP" % LEVEL_UP_HP, "+%d MP" % LEVEL_UP_MP, "+%d STR" % LEVEL_UP_STR]
	if new_level % 2 == 0:
		parts.append("+1 AGI")
	return ", ".join(parts)

# Chance an enemy's attack misses Oliver outright - grows with agility.
func dodge_chance() -> float:
	return clampf((stats.agility - BASE_AGILITY) * DODGE_PER_AGILITY, 0.0, DODGE_MAX)

# THE single source of truth for equipment slots. Adding a slot = one entry
# here + items carrying "slot": "<id>" in Items.ITEMS. Everything else is
# derived: the `equipment` dict, the character sheet's header slot row and
# paper-doll slots/connector lines (tools/setup_character_sheet.gd builds
# them from this table), the sheet's stat lines, and combat's attack /
# defence / bonus totals (gear_total()/gear_bonus() below).
#   label   - shown under the slot buttons
#   doll    - slot position on the paper doll (CharacterView-local px)
#   line_to - where its connector line meets the figure
#   stat    - the item field this slot contributes: "attack" and "defense"
#             are SUMMED across every slot that has them (so a future helmet
#             stacks with armour); "bonus" slots contribute the best value
#             per key from their `bonus` dict (two charms don't stack).
# Reserved doll positions for likely future slots, so they drop in without
# re-laying-out the figure: head Vector2(250, 30) (left column, above the
# weapon), off-hand Vector2(250, 210) (left column, below it), feet
# Vector2(504, 202) (right column, below the armour). Deliberately NOT
# shown until there's loot to fill them - an always-empty slot reads as
# missing content.
const SLOTS := {
	"weapon": {"label": "Weapon", "doll": Vector2(250, 120), "line_to": Vector2(348, 150), "stat": "attack"},
	"armor": {"label": "Armor", "doll": Vector2(504, 108), "line_to": Vector2(452, 142), "stat": "defense"},
	"accessory": {"label": "Accessory", "doll": Vector2(504, 14), "line_to": Vector2(420, 84), "stat": "bonus"},
}

# slot -> gear INSTANCE ({"uid", "base", "mods"}, see inventory.gd) or {}
# when empty; one key per SLOTS entry.
var equipment: Dictionary = {}

func _init() -> void:
	for slot in SLOTS:
		equipment[slot] = {}

func equipped(slot: String) -> Dictionary:
	return equipment.get(slot, {})

# The worn item's base id ("" if the slot is empty) - for callers that only
# care what kind of thing is worn.
func equipped_id(slot: String) -> String:
	var inst: Dictionary = equipped(slot)
	return inst.base if not inst.is_empty() else ""

# Equips a carried instance - by uid (int), or by base id (String: the first
# carried instance of that kind, plain ones first). Anything already in the
# slot goes back to the backpack (a swap, not a stack).
func equip(slot: String, what) -> void:
	if not SLOTS.has(slot):
		return
	var inst: Dictionary
	if what is int:
		inst = Inventory.take_gear(what)
	else:
		var candidates: Array = Inventory.gear_of(str(what))
		if candidates.is_empty():
			return
		candidates.sort_custom(func(a, b): return a.mods.size() < b.mods.size())
		inst = Inventory.take_gear(candidates[0].uid)
	if inst.is_empty():
		return
	var previous: Dictionary = equipment[slot]
	if not previous.is_empty():
		Inventory.add_gear_instance(previous)
	equipment[slot] = inst
	changed.emit()

func unequip(slot: String) -> void:
	var inst: Dictionary = equipped(slot)
	if inst.is_empty():
		return
	Inventory.add_gear_instance(inst)
	equipment[slot] = {}
	changed.emit()

# Sum of an item field over every equipped slot whose stat is that field,
# base stats plus enhancement mods - e.g. gear_total("defense") = armour 3
# + Fur-lined 1 + (a future helmet) + ...
func gear_total(field: String) -> int:
	var total := 0
	for slot in SLOTS:
		if SLOTS[slot].stat == field and not equipment[slot].is_empty():
			total += Items.instance_stat(equipment[slot], field)
	return total

# Best value of a `bonus` key across the equipped "bonus" slots (max, not
# sum - stacking two 50% charms must not reach 100% resistance).
func gear_bonus(key: String) -> float:
	var best := 0.0
	for slot in SLOTS:
		if SLOTS[slot].stat == "bonus" and not equipment[slot].is_empty():
			best = maxf(best, float(Items.ITEMS.get(equipment[slot].base, {}).get("bonus", {}).get(key, 0.0)))
	return best

# Names of the items equipped in every slot feeding `field`, for UI hints
# like "ATK +6 (Bone Greatsword)".
func gear_names(field: String) -> Array:
	var names: Array = []
	for slot in SLOTS:
		if SLOTS[slot].stat == field and not equipment[slot].is_empty():
			names.append(Items.instance_name(equipment[slot]))
	return names

const DEFAULT_STATS := {"hp": 20, "max_hp": 20, "mp": 10, "max_mp": 10, "strength": 5, "agility": 5, "level": 1, "xp": 0}

func reset() -> void:
	for key in DEFAULT_STATS:
		stats[key] = DEFAULT_STATS[key]
	for slot in SLOTS:
		equipment[slot] = {}
	changed.emit()
