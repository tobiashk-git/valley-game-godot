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
var boss_defeated: Dictionary = {"dungeon_boss": false}

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
