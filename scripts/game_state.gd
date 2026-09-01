extends Node
# Autoload singleton — carries the target spawn position across a scene
# change (change_scene_to_file() destroys the old scene tree entirely, so
# there's no other way to tell the new scene "spawn here specifically,
# not your default spot"). Port of the explicit spawnX/spawnY params
# activateLevel() takes in game.js, just needed as shared state here since
# Godot scene changes aren't a single function call with args.

const NO_OVERRIDE := Vector2(-999999, -999999)

var next_spawn_position: Vector2 = NO_OVERRIDE

# Boss checkpoints: once true, that boss stays defeated for the session (no
# save/load system exists yet, so this only persists until the game quits).
var boss_defeated: Dictionary = {"dungeon_boss": false, "castle_boss": false}

# Set once by Quests.mark_npc_met() when the meet_villagers tutorial quest
# completes. overworld.gd checks this every time it (re)builds the map, since
# the player is always inside a house interior (never the Overworld itself)
# at the exact moment this flips - see world.gd's open_gates().
var village_gates_open := false

# World Map fast-travel unlocks. House/village start known (the player
# spawns right there); the dungeon/castle unlock themselves in
# maze_interior.gd's own _ready() - in real play that only ever runs after
# walking through the relevant entrance portal, so reaching this point
# already means "discovered".
var discovered_pois: Dictionary = {"house": true, "village": true, "dungeon": false, "castle": false}

func set_next_spawn(pos: Vector2) -> void:
	next_spawn_position = pos

# Call once from the new scene's _ready(). Returns true (and applies the
# position) if an override was pending, false if the scene should use its
# own default spawn instead.
func consume_next_spawn(player: Node2D) -> bool:
	if next_spawn_position == NO_OVERRIDE:
		return false
	player.position = next_spawn_position
	next_spawn_position = NO_OVERRIDE
	return true
