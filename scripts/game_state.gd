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
var boss_defeated: Dictionary = {"dungeon_boss": false, "castle_boss": false, "final_boss": false, "frostpeak_boss": false, "verdantwood_boss": false, "badlands_boss": false, "gloomfen_boss": false, "golden_plains_boss": false, "verdantwood_maze_guardian_1": false}

# Static farmable overworld monsters (see wild_monster.gd/World.scatter_wild_
# monsters()) - a separate dict from boss_defeated so real bosses and
# farmable wildlife stay conceptually distinct. Keyed by "<tile_x>_<tile_y>"
# (the placement's world tile position, deterministic across reloads - see
# scatter_wild_monsters()'s seed bracketing) rather than an enemy id, since
# many placements share the same species per biome. Empty until populated by
# World.scatter_wild_monsters() at world-gen time - unlike boss_defeated,
# there's no fixed list of ids known ahead of time.
# Value = the unix time the monster wakes up (nothing dies in the valley:
# a beaten wild monster dozes off, you take its things, and it's back on
# its feet WILD_MONSTER_SLEEP_SECONDS later). A plain `true` (older saves,
# test fixtures) means "asleep, no wake time".
var wild_monsters_defeated: Dictionary = {}
const WILD_MONSTER_SLEEP_SECONDS := 600

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
var discovered_pois: Dictionary = {"house": true, "village": true, "dungeon": false, "castle": false, "frostpeak_interior": false, "verdantwood_interior": false, "badlands_interior": false, "gloomfen_interior": false, "golden_plains_interior": false}

# The altar/world-advance loop: 2 Magic Crystals (from the two Guardians)
# reveal a hidden final boss; its own crystal drop, returned to the altar,
# opens the portal to World 2. See altar.gd. golden_plains_revealed is a
# similar one-time reveal flag (not a ford - Golden Plains IS the valley,
# there's no river to cross) flipped by the "open_ancient_barrow" quest; see
# world.gd's GOLDEN_PLAINS_INTERIOR_ENTRANCE and overworld.gd's
# reveal_golden_plains_entrance().
var world_progress: Dictionary = {"final_boss_revealed": false, "world2_unlocked": false, "golden_plains_revealed": false}

# The biome revamp's river dividers - each outer biome starts blocked by a
# river with one ford (see world.gd's _paint_river_ring()/open_biome_path()).
# No quest sets any of these true yet in this phase (geometry now, quests
# later, matching how village_gates_open existed before meet_villagers) -
# these are here purely so the mechanism exists and is independently
# flippable/verifiable.
var biome_paths_open: Dictionary = {"frostpeak": false, "verdantwood": false, "badlands": false, "gloomfen": false}

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

# Back to a fresh game's values (SaveSystem.new_game()).
func reset() -> void:
	next_spawn_position = NO_OVERRIDE
	for key in boss_defeated.keys():
		boss_defeated[key] = false
	wild_monsters_defeated.clear()
	village_gates_open = false
	for key in discovered_pois.keys():
		discovered_pois[key] = key == "house" or key == "village"
	for key in world_progress.keys():
		world_progress[key] = false
	for key in biome_paths_open.keys():
		biome_paths_open[key] = false

# True on any scene with a player (overworld, houses, interiors); false on
# the title screen. The always-on overlays (HUD, toolbar, quick bar,
# tracker, touch controls) and the sheet's shortcuts key off this.
func is_gameplay() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.has_node("YSort/Player")

func put_wild_monster_to_sleep(key: String) -> void:
	wild_monsters_defeated[key] = int(Time.get_unix_time_from_system()) + WILD_MONSTER_SLEEP_SECONDS

# True while the placement is sleeping; a passed wake time clears it.
func is_wild_monster_asleep(key: String) -> bool:
	if not wild_monsters_defeated.has(key):
		return false
	var v = wild_monsters_defeated[key]
	if v is bool:
		return v
	if int(Time.get_unix_time_from_system()) >= int(v):
		wild_monsters_defeated.erase(key)
		return false
	return true
