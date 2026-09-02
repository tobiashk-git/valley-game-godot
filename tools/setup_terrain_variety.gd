extends SceneTree
# Phase 7c: adds a second atlas tile (Vector2i(1,0)) to the 4 outdoor-ground
# TileSetAtlasSources (SRC_FROSTPEAK=1, SRC_BADLANDS=2, SRC_VERDANTWOOD=3,
# SRC_GLOOMFEN=4) in both Overworld.tscn and Overworld2.tscn's embedded
# TileSets, now that tools/integrate_terrain_variety.gd has widened each
# ground PNG to a 64x32 fill+flecked strip. Same "instantiate the live
# scene, edit tilemap.tile_set, pack+save back over the .tscn" technique used
# for adding SRC_RAVINE (see tools/setup_wedge_seam_ravine.gd) - Overworld
# scenes' TileSets are embedded SubResources, not the external
# resources/overworld_tileset.tres.
# Run via: godot --headless --script res://tools/setup_terrain_variety.gd

const SCENES := ["res://scenes/Overworld.tscn", "res://scenes/Overworld2.tscn"]
const GROUND_SOURCE_IDS := [1, 2, 3, 4] # SRC_FROSTPEAK, SRC_BADLANDS, SRC_VERDANTWOOD, SRC_GLOOMFEN

func _initialize() -> void:
	print("=== Terrain variety TileSet setup starting ===")

	for scene_path in SCENES:
		var world: Node2D = load(scene_path).instantiate()
		var tilemap: TileMapLayer = world.get_node("TileMapLayer")
		var tile_set: TileSet = tilemap.tile_set

		for source_id in GROUND_SOURCE_IDS:
			var source: TileSetAtlasSource = tile_set.get_source(source_id)
			if source.has_tile(Vector2i(1, 0)):
				print(scene_path, " source ", source_id, ": tile (1,0) already present, skipping")
				continue
			source.create_tile(Vector2i(1, 0))
			print(scene_path, " source ", source_id, ": added tile (1,0)")

		var packed := PackedScene.new()
		packed.pack(world)
		var err := ResourceSaver.save(packed, scene_path)
		print(scene_path, " saved: ", err)

	print("=== Terrain variety TileSet setup complete ===")
	quit()
