extends Node
# Autoload — fast-travel destinations, port of worldmap.js's POI list +
# travelTo(). Fast travel always goes through GameState.next_spawn_position
# + a scene change to Overworld.tscn, whether the player is already there or
# in an interior - one code path instead of two, at the cost of the
# Overworld's trees/rocks re-scattering into new spots on a same-scene
# "travel" (harmless, just a quirk of reusing change_scene_to_file()
# unconditionally rather than a separate in-place-reposition path).

signal changed

const POI_NAMES := {
	"house": "Your House",
	"village": "Village",
	"dungeon": "Dungeon",
	"castle": "Castle",
	"frostpeak_interior": "Frostpeak Ice Caves",
	"verdantwood_interior": "Verdantwood Grove",
	"badlands_interior": "Emberfall Caldera",
	"gloomfen_interior": "Sunken Gloomfen Temple",
	"golden_plains_interior": "The Ancient Barrow",
}

const LOCATION_NAMES := {
	"Overworld": "the Valley",
	"Dungeon": "the Dungeon",
	"Castle": "the Castle",
	"House": "your House",
	"ElderHouse": "the Elder's House",
	"TraderHouse": "the Trader's House",
	"EmptyHouse": "an empty house",
	"FrostpeakInterior": "the Ice Caves",
	"VerdantwoodInterior": "the Verdantwood Grove",
	"BadlandsInterior": "the Caldera",
	"GloomfenInterior": "the Sunken Temple",
	"GoldenPlainsInterior": "the Ancient Barrow",
}

# Computed lazily (not a const dict) since it reads World.VILLAGE_GATES,
# which is a `var` there, not a compile-time constant.
func poi_target(poi_id: String) -> Vector2:
	match poi_id:
		"house":
			return Vector2(World.HOUSE_ENTRANCE.x * 32 + 16, (World.HOUSE_ENTRANCE.y + 1) * 32 + 16)
		"village":
			var t: Vector2i = World.VILLAGE_GATES.south + Vector2i(0, -2)
			return Vector2(t.x * 32 + 16, t.y * 32 + 16)
		"dungeon":
			return Vector2(World.DUNGEON_ENTRANCE.x * 32 + 16, (World.DUNGEON_ENTRANCE.y + 1) * 32 + 16)
		"castle":
			return Vector2(World.CASTLE_ENTRANCE.x * 32 + 16, (World.CASTLE_ENTRANCE.y + 1) * 32 + 16)
		"frostpeak_interior":
			return Vector2(World.FROSTPEAK_INTERIOR_ENTRANCE.x * 32 + 16, (World.FROSTPEAK_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		"verdantwood_interior":
			return Vector2(World.VERDANTWOOD_INTERIOR_ENTRANCE.x * 32 + 16, (World.VERDANTWOOD_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		"badlands_interior":
			return Vector2(World.BADLANDS_INTERIOR_ENTRANCE.x * 32 + 16, (World.BADLANDS_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		"gloomfen_interior":
			return Vector2(World.GLOOMFEN_INTERIOR_ENTRANCE.x * 32 + 16, (World.GLOOMFEN_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		"golden_plains_interior":
			return Vector2(World.GOLDEN_PLAINS_INTERIOR_ENTRANCE.x * 32 + 16, (World.GOLDEN_PLAINS_INTERIOR_ENTRANCE.y + 1) * 32 + 16)
		_:
			return Vector2.ZERO

func is_discovered(poi_id: String) -> bool:
	return GameState.discovered_pois.get(poi_id, false)

func current_location_name() -> String:
	var current: Node = get_tree().current_scene
	var scene_name: String = current.name if current else ""
	return LOCATION_NAMES.get(scene_name, scene_name)

func travel_to(poi_id: String) -> void:
	if not is_discovered(poi_id):
		return
	GameState.set_next_spawn(poi_target(poi_id))
	get_tree().change_scene_to_file("res://scenes/Overworld.tscn")
