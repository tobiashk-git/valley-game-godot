extends "res://scripts/maze_interior.gd"
# Verdantwood Forest's roguelike tree-hollow interior - the shared
# maze_interior.gd skeleton plus two hazard set-pieces layered on top of the
# same DungeonGen layout: a root-snare room (briefly immobilizes the player)
# and a canopy-fog room (reduced fog-reveal radius). Both are movement/
# vision-only - unlike Frostpeak's brittle bridge, neither can ever block a
# tile or strand the player, so no "repair" logic is needed here.

const SRC_ROOT := 2
const SRC_CANOPY := 3
const SNARE_DURATION := 1.5 # seconds
const CANOPY_RADIUS := 1 # vs. the base FOG_REVEAL_RADIUS (2) elsewhere

var hazard_map: Dictionary = {} # Vector2i -> "root" | "canopy"
var _snare_timer := 0.0
var _snare_anchor := Vector2.ZERO
var _last_tile := Vector2i(-9999, -9999)

func _ready() -> void:
	super._ready()
	# Runs after Player's own _physics_process (default priority 0) in the
	# same tick, so the snare override below isn't immediately stomped by
	# player.gd setting velocity from input every frame.
	process_physics_priority = 10
	_place_hazards()

func _place_hazards() -> void:
	var room_chain: Array = _gen.room_chain
	var root_room = room_chain[1] # a different intermediate room than Frostpeak's [2], purely for variety
	# Checkerboard, not every tile - covering the whole room would mean every
	# single step re-triggers the snare (there's nowhere un-rooted to step
	# to), turning a hazard into a tedious "wait 1.5s per tile" slog instead
	# of something to navigate carefully. This always leaves an adjacent
	# clear tile to step onto.
	for y in range(root_room.y, root_room.y + root_room.h):
		for x in range(root_room.x, root_room.x + root_room.w):
			if (x + y) % 2 != 0:
				continue
			var pos := Vector2i(x, y)
			hazard_map[pos] = "root"
			terrain.set_cell(pos, SRC_ROOT, Vector2i(0, 0))

	var canopy_room = room_chain[3]
	for y in range(canopy_room.y, canopy_room.y + canopy_room.h):
		for x in range(canopy_room.x, canopy_room.x + canopy_room.w):
			var pos := Vector2i(x, y)
			hazard_map[pos] = "canopy"
			terrain.set_cell(pos, SRC_CANOPY, Vector2i(0, 0))

func _reveal_around(center: Vector2i, radius: int = FOG_REVEAL_RADIUS) -> void:
	var r: int = CANOPY_RADIUS if hazard_map.get(center, "") == "canopy" else radius
	super._reveal_around(center, r)

# player.gd (default priority 0) runs its own move_and_slide() BEFORE this,
# using whatever velocity it read from input - by the time this runs, that
# movement has already been applied this tick, so just zeroing velocity
# afterward can't undo it (a lesson Frostpeak's ice never hit, since ice
# only ever ADDS movement on top of player.gd's, never needs to SUPPRESS
# movement player.gd already made). Snapping position back to the anchor
# each snared tick is what actually pins the player in place.
func _physics_process(delta: float) -> void:
	if _snare_timer > 0.0:
		player.position = _snare_anchor
		player.velocity = Vector2.ZERO
		_snare_timer -= delta

func _process(delta: float) -> void:
	super._process(delta)

	var tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if tile != _last_tile:
		_last_tile = tile
		if hazard_map.get(tile, "") == "root":
			_snare_timer = SNARE_DURATION
			_snare_anchor = player.position
