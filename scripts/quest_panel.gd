extends Node
# Autoload — a thin alias for the character sheet's Journal tab. The
# Journal used to be its own list panel; it now lives inside the sheet
# (scripts/journal_view.gd) so the tab strip stays available - the same
# reason the World Map moved in. Kept as an autoload so every caller that
# knew QuestPanel (toolbar, quest tracker, quick bar, verify scripts) keeps
# working: open/close/is_open/toggle_open route to the sheet, and the Q key
# is handled by the sheet itself.

func is_open() -> bool:
	return CharacterSheet.is_open() and CharacterSheet.current_tab == "journal"

func open() -> void:
	CharacterSheet.open("journal")

func close() -> void:
	if is_open():
		CharacterSheet.close()

func toggle_open() -> void:
	CharacterSheet.toggle("journal")
