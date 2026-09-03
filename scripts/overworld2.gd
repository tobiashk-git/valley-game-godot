extends Node2D
# World 2 — deliberately lean: a fresh biome map (same generation as World
# 1, via World.build_biome_layer()) with scattered resources and random
# encounters, but no village/houses/altar of its own. That onboarding
# tutorial (fence/gates, quest-giver, vendor) is explicitly World-1-only,
# and building a second full quest ecosystem is future scope beyond "prove
# the world-advance loop repeats" - matching how the original plan itself
# stopped at "World 2 becomes reachable" before any further build-out.

const TREE_SCENE := preload("res://scenes/props/Tree.tscn")
const ROCK_SCENE := preload("res://scenes/props/Rock.tscn")
const MIGHTY_OAK_SCENE := preload("res://scenes/props/MightyOak.tscn")
const ICE_BOULDER_SCENE := preload("res://scenes/props/IceBoulder.tscn")
const ICE_CRYSTAL_SHARD_SCENE := preload("res://scenes/props/IceCrystalShard.tscn")
const ICE_POOL_SCENE := preload("res://scenes/props/IcePool.tscn")
const FALLEN_LOG_SCENE := preload("res://scenes/props/FallenLog.tscn")
const TANGLED_BUSH_SCENE := preload("res://scenes/props/TangledBush.tscn")
const SWAMP_TREE_SCENE := preload("res://scenes/props/SwampTree.tscn")
const SWAMP_FERNS_SCENE := preload("res://scenes/props/SwampFerns.tscn")
const SWAMP_MUSHROOMS_SCENE := preload("res://scenes/props/SwampMushrooms.tscn")
const BADLANDS_PALMS_SCENE := preload("res://scenes/props/BadlandsPalms.tscn")
const BADLANDS_FIRE_GEYSER_SCENE := preload("res://scenes/props/BadlandsFireGeyser.tscn")
const BADLANDS_TUMBLEWEED_SCENE := preload("res://scenes/props/BadlandsTumbleweed.tscn")
const PORTAL_SCENE := preload("res://scenes/Portal.tscn")

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Player

var _last_tile := Vector2i(-9999, -9999)

func _tile_center(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * 32 + 16, pos.y * 32 + 16)

func _ready() -> void:
	World.build_biome_layer(tilemap)
	# World 1 gets this as part of its own build_overworld_map() (after its
	# river ring); World 2 skips that whole function (no village/river of its
	# own), so it needs the same call directly - otherwise the 4 outer
	# biomes would stay fully walkable into each other here even though
	# World 1 permanently blocks it, an inconsistency not worth leaving.
	World.paint_outer_biome_mountains(tilemap)
	World.add_world_boundary(self)

	for entry in World.scatter_trees_and_rocks(tilemap):
		var scene: PackedScene = TREE_SCENE if entry.scene == "Tree" else ROCK_SCENE
		var instance: Node2D = scene.instantiate()
		instance.position = _tile_center(entry.pos)
		ysort.add_child(instance)

	# Lakes paint before obstacles scatter - see overworld.gd's copy of this
	# comment for why the order matters.
	World.scatter_biome_lakes(tilemap)
	var obstacle_scenes := {
		"MightyOak": MIGHTY_OAK_SCENE,
		"IceBoulder": ICE_BOULDER_SCENE,
		"IceCrystalShard": ICE_CRYSTAL_SHARD_SCENE,
		"IcePool": ICE_POOL_SCENE,
		"FallenLog": FALLEN_LOG_SCENE,
		"TangledBush": TANGLED_BUSH_SCENE,
		"SwampTree": SWAMP_TREE_SCENE,
		"SwampFerns": SWAMP_FERNS_SCENE,
		"SwampMushrooms": SWAMP_MUSHROOMS_SCENE,
		"BadlandsPalms": BADLANDS_PALMS_SCENE,
		"BadlandsFireGeyser": BADLANDS_FIRE_GEYSER_SCENE,
		"BadlandsTumbleweed": BADLANDS_TUMBLEWEED_SCENE,
	}
	for entry in World.scatter_biome_obstacles(tilemap):
		var instance: Node2D = obstacle_scenes[entry.scene].instantiate()
		instance.position = _tile_center(entry.pos)
		ysort.add_child(instance)

	# Return trip lands back at World 1's village altar plaza (walkable
	# path tile just south of the altar itself, which is solid).
	var return_portal: Area2D = PORTAL_SCENE.instantiate()
	return_portal.position = _tile_center(Vector2i(World.WORLD_CENTER_X, World.WORLD_CENTER_Y))
	return_portal.get_node("CollisionShape2D").shape.size = Vector2(56, 56)
	return_portal.target_scene = "res://scenes/Overworld.tscn"
	return_portal.target_spawn = Vector2(World.ALTAR_POS.x * 32 + 16, (World.ALTAR_POS.y + 2) * 32 + 16)
	add_child(return_portal)

	if not GameState.consume_next_spawn(player):
		player.position = _tile_center(Vector2i(World.WORLD_CENTER_X, World.WORLD_CENTER_Y + 2))

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = World.OVERWORLD_WIDTH * 32
	cam.limit_bottom = World.OVERWORLD_HEIGHT * 32
	cam.reset_smoothing()

# Same tile-change hook as overworld.gd - see its comment for why. World 2
# has no river/fords of its own yet (Phase 1 of the biome revamp is World-1
# scoped for that part), just the same per-biome encounter pool. Gated off
# for the same reason overworld.gd's own copy is - random encounters
# replaced by static wild monsters in the open world (see
# World.scatter_wild_monsters()) - but World 2 doesn't get wild monsters in
# this first pass (kept World-1-scoped, same precedent as the Verdantwood
# maze's own initial rollout), so it just goes quiet here rather than
# gaining the new system too.
const OVERWORLD_ENCOUNTERS_ENABLED := false

func _process(_delta: float) -> void:
	var current_tile := Vector2i(int(player.position.x / 32), int(player.position.y / 32))
	if current_tile != _last_tile:
		_last_tile = current_tile
		var zone: int = World.biome_at(current_tile.x, current_tile.y).zone
		if zone != World.Zone.VALLEY and OVERWORLD_ENCOUNTERS_ENABLED:
			Combat.check_random_encounter(zone)
