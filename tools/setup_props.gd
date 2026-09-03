extends SceneTree
# Builds Tree.tscn, Rock.tscn, HouseEntrance.tscn, DungeonEntrance.tscn,
# CastleEntrance.tscn — all StaticBody2D scenes with a full-tile collision
# shape and (except the two placeholder-shape entrances) a bottom-anchored
# Sprite2D, matching the JS game's oversized/bottom-anchor sprite convention.
# Run via: godot --headless --script res://tools/setup_props.gd

const TILE := 32.0
const HALF := TILE / 2.0

func _build_sprite_prop(scene_name: String, tex_path: String, src_w: float, src_h: float, scale: float, region: Rect2 = Rect2(), z_index: int = 1) -> void:
	var body := StaticBody2D.new()
	body.name = scene_name
	body.z_index = z_index # Two-tier layering: everything that stands proud of the
	# ground (default 1, matching Player.tscn's own z_index=1) mutually Y-sorts as
	# normal - unchanged from before this existed. Ground-flush objects (FallenLog,
	# IcePool) pass 0 instead - still above the TileMapLayer terrain (which is also
	# 0, drawn first by sibling order), but strictly BEHIND the z=1 tier, so a flat
	# object can never appear to float in front of a taller neighbor (tree, boulder,
	# bush) or the player, regardless of which tile row either one is on. A single
	# scalar z_index can't express "loses to elevated, ties with player" at once -
	# this bumps the elevated+player tier up together instead of pushing flush down,
	# which would otherwise sink it below the terrain and make it invisible.

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(tex_path)
	if region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = region
	sprite.scale = Vector2(scale, scale)
	var drawn_h: float = src_h * scale
	sprite.offset = Vector2(0, HALF - drawn_h / 2.0) # bottom-anchored: sprite's bottom sits at the tile's bottom edge
	body.add_child(sprite)
	sprite.owner = body

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE - 4, TILE - 4) # collision stays a single tile even though the sprite overflows visually
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body

	var packed := PackedScene.new()
	packed.pack(body)
	var err := ResourceSaver.save(packed, "res://scenes/props/%s.tscn" % scene_name)
	print(scene_name, ".tscn saved: ", err)

func _build_drawn_prop(scene_name: String, script_path: String, z_index: int = 1) -> void:
	var body := StaticBody2D.new()
	body.name = scene_name
	body.z_index = z_index
	body.set_script(load(script_path))

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE - 4, TILE - 4)
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body

	var packed := PackedScene.new()
	packed.pack(body)
	var err := ResourceSaver.save(packed, "res://scenes/props/%s.tscn" % scene_name)
	print(scene_name, ".tscn saved: ", err)

func _initialize() -> void:
	print("=== Props setup starting ===")

	DirAccess.make_dir_recursive_absolute("res://scenes/props")

	_build_sprite_prop("Tree", "res://assets/tree.png", 94.0, 80.0, 0.6)
	_build_sprite_prop("Rock", "res://assets/rock.png", 32.0, 32.0, 1.0, Rect2(0, 0, 32, 32))
	_build_sprite_prop("HouseEntrance", "res://assets/house.png", 69.0, 123.0, 0.75)
	_build_drawn_prop("DungeonEntrance", "res://scripts/dungeon_entrance.gd")
	_build_drawn_prop("CastleEntrance", "res://scripts/castle_entrance.gd")
	# Phase 7b - real cropped-sprite entrance props (LPC Cavern & Ruin Tiles /
	# LPC Base Assets, see assets_source/lpc/CREDITS.md), replacing the
	# hand-drawn _draw() placeholders these 5 used through Phase 6.
	_build_sprite_prop("WatchtowerRuinEntrance", "res://assets/watchtower_ruin.png", 192.0, 96.0, 0.35)
	_build_sprite_prop("DruidCircleEntrance", "res://assets/druid_circle.png", 96.0, 64.0, 0.55)
	_build_sprite_prop("VolcanoEntrance", "res://assets/volcano.png", 192.0, 78.0, 0.4)
	_build_sprite_prop("SubmergedTempleEntrance", "res://assets/submerged_temple.png", 192.0, 96.0, 0.35)
	_build_sprite_prop("AncientBarrowEntrance", "res://assets/ancient_barrow.png", 26.0, 61.0, 1.1)
	# Outer-biome obstacles (AI-generated, color-keyed + auto-cropped from a
	# 1024x1024 isolated-object generation) - MightyOak scatters into
	# Zone.VERDANTWOOD via World.scatter_biome_obstacles(), same single-tile
	# collision convention as every prop above despite the larger visual size.
	_build_sprite_prop("MightyOak", "res://assets/mighty_oak.png", 629.0, 598.0, 0.134)
	_build_sprite_prop("IceBoulder", "res://assets/ice_boulder.png", 477.0, 519.0, 0.116)
	_build_sprite_prop("IceCrystalShard", "res://assets/ice_crystal_shard.png", 543.0, 586.0, 0.0853)
	# IcePool/FallenLog lie flush with the ground (unlike every other obstacle
	# above, which stands proud of it) - z_index 0 (below the z=1 default every
	# other prop and the Player use) keeps them from ever floating in front of
	# a taller neighbor they happen to visually overlap.
	_build_sprite_prop("IcePool", "res://assets/ice_pool.png", 761.0, 757.0, 0.0859, Rect2(), 0)
	_build_sprite_prop("FallenLog", "res://assets/fallen_log.png", 526.0, 185.0, 0.1597, Rect2(), 0)
	_build_sprite_prop("TangledBush", "res://assets/tangled_bush.png", 681.0, 647.0, 0.1028)
	# Gloomfen's first prop-scatter obstacle - a gnarled swamp tree, MightyOak's
	# elevated counterpart for Zone.GLOOMFEN.
	_build_sprite_prop("SwampTree", "res://assets/swamp_tree.png", 501.0, 600.0, 0.1677)
	# Second Gloomfen obstacle for variety - a dense fern/reed cluster, same
	# "second, smaller obstacle" role FallenLog/TangledBush play in Verdantwood.
	_build_sprite_prop("SwampFerns", "res://assets/swamp_ferns.png", 733.0, 841.0, 0.0955)

	print("=== Props setup complete ===")
	quit()
