extends Node
# Autoload — a thin alias for the character sheet's Map tab. The World Map
# used to be its own window (and before that a list panel); it now lives
# inside the sheet (scripts/map_view.gd) so the tab strip stays available
# - the user found the standalone window "loses the tabs of the other
# panels, so you can't switch back to inventory". Kept as an autoload so
# every caller that knew WorldMapPanel (toolbar, quest tracker, quick bar,
# verify scripts) keeps working unchanged: open/close/is_open/toggle_open
# route to the sheet, and the M key is handled by the sheet itself.

func is_open() -> bool:
	return CharacterSheet.is_open() and CharacterSheet.current_tab == "map"

func open() -> void:
	CharacterSheet.open("map")

func close() -> void:
	if is_open():
		CharacterSheet.close()

func toggle_open() -> void:
	CharacterSheet.toggle("map")

func _on_travel(poi_id: String) -> void:
	CharacterSheet.close()
	WorldMap.travel_to(poi_id)
