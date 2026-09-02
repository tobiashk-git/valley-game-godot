extends "res://scripts/maze_interior.gd"
# Golden Plains' own interior (Phase 6a) - the simplest biome interior yet.
# No hazard tiles at all: the roadmap frames this one as low-danger and
# story-forward, not a combat gauntlet, so unlike every other biome interior
# it has zero random encounters during exploration (matching Golden Plains/
# Zone.VALLEY's existing zero-encounter design - see overworld.gd). _ready()
# is NOT overridden - the inherited boss-spawn still happens, just an easy
# "guardian spirit" tier boss (golden_plains_boss in enemies.gd) rather than
# a threat.

func _process(_delta: float) -> void:
	# Deliberately does NOT call super._process() - that method bundles
	# fog-reveal together with Combat.check_random_encounter(encounter_zone).
	# Duplicates just the fog-reveal half of the tile-change check.
	var current_tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if current_tile != _last_revealed_tile:
		_last_revealed_tile = current_tile
		_reveal_around(current_tile)
