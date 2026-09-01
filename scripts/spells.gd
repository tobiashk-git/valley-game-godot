extends Node
# Autoload — spell definitions, port of the original two-spell shape of
# spells.js (Fireball + Heal) before any later expansion.

const SPELLS := {
	"fireball": {"name": "Fireball", "icon": "🔥", "kind": "damage", "mp_cost": 3, "power": 10},
	"heal": {"name": "Heal", "icon": "✨", "kind": "heal", "mp_cost": 4, "power": 15},
}

# Real generated texture (res://assets/icons/, see tools/setup_item_icons.gd)
# standing in for the emoji "icon" field above, which Web export can't
# render - same reasoning as Items.get_item_icon().
func get_spell_icon(spell_id: String) -> Texture2D:
	if SPELLS.has(spell_id):
		return load("res://assets/icons/%s.png" % spell_id)
	return null
