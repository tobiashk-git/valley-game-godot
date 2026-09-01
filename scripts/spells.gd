extends Node
# Autoload — spell definitions, port of the original two-spell shape of
# spells.js (Fireball + Heal) before any later expansion.

const SPELLS := {
	"fireball": {"name": "Fireball", "kind": "damage", "mp_cost": 3, "power": 10},
	"heal": {"name": "Heal", "kind": "heal", "mp_cost": 4, "power": 15},
}
