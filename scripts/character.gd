extends Node
# Autoload — Oliver's stats + equipment slots. Port of the `character`
# object in game.js.

signal changed

var stats: Dictionary = {
	"hp": 20, "max_hp": 20,
	"mp": 10, "max_mp": 10,
	"strength": 5, "agility": 5,
}

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

# slot -> item_id or "" (empty); one key per SLOTS entry.
var equipment: Dictionary = {}

func _init() -> void:
	for slot in SLOTS:
		equipment[slot] = ""

# Equipping consumes 1 of item_id from the backpack; any item already in
# that slot is returned to the backpack first (a swap, not a stack).
func equip(slot: String, item_id: String) -> void:
	if not SLOTS.has(slot) or not Inventory.remove_item(item_id, 1):
		return
	var previous: String = equipment[slot]
	if previous != "":
		Inventory.add_item(previous, 1)
	equipment[slot] = item_id
	changed.emit()

func unequip(slot: String) -> void:
	var item_id: String = equipment.get(slot, "")
	if item_id == "":
		return
	Inventory.add_item(item_id, 1)
	equipment[slot] = ""
	changed.emit()

# Sum of an item field over every equipped slot whose stat is that field -
# e.g. gear_total("defense") = armour + (a future helmet) + ...
func gear_total(field: String) -> int:
	var total := 0
	for slot in SLOTS:
		if SLOTS[slot].stat == field and equipment[slot] != "":
			total += int(Items.ITEMS.get(equipment[slot], {}).get(field, 0))
	return total

# Best value of a `bonus` key across the equipped "bonus" slots (max, not
# sum - stacking two 50% charms must not reach 100% resistance).
func gear_bonus(key: String) -> float:
	var best := 0.0
	for slot in SLOTS:
		if SLOTS[slot].stat == "bonus" and equipment[slot] != "":
			best = maxf(best, float(Items.ITEMS.get(equipment[slot], {}).get("bonus", {}).get(key, 0.0)))
	return best

# Names of the items equipped in every slot feeding `field`, for UI hints
# like "ATK +6 (Bone Greatsword)".
func gear_names(field: String) -> Array:
	var names: Array = []
	for slot in SLOTS:
		if SLOTS[slot].stat == field and equipment[slot] != "":
			names.append(Items.get_item_name(equipment[slot]))
	return names
