extends Node
# Autoload — status effect definitions, port of statuses.js. All 5 classic
# effects in one pass since they share most of their plumbing. Contained to
# combat: player_status resets whenever a fight starts or ends (see
# combat.gd) — no exploration-loop persistence this pass.

const STATUSES := {
	"poison": {"name": "Poison", "duration": 3, "dot_damage": 3},
	"paralysis": {"name": "Paralysis", "duration": 2, "act_chance": 0.5},
	"sleep": {"name": "Sleep", "duration": 3},
	"confusion": {"name": "Confusion", "duration": 2, "self_hit_chance": 0.5},
	"silence": {"name": "Silence", "duration": 2},
}
