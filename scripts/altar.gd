extends Node
# Autoload — the village altar's crystal/world-advance logic, port of the
# JS reference's altar interaction (world.js's Main Quest Arc plan),
# simplified to "prove the loop repeats" scope: both existing bosses drop a
# Magic Crystal alongside their usual gear; 2 crystals at the altar reveal a
# new, tougher final boss hidden in an outer biome; its crystal drop, once
# returned, opens a portal to a second, freshly-generated world. World 2
# itself is deliberately lean (see overworld2.gd) rather than a full second
# village/quest ecosystem - matching how even the original plan scoped
# itself to "World 2 becomes reachable" before stopping for a playtest.

const CRYSTALS_TO_REVEAL := 2

signal changed

func _dialogue_ui() -> Node:
	return get_node("/root/DialogueUI")

func interact() -> void:
	var progress: Dictionary = GameState.world_progress

	if progress.world2_unlocked:
		GameState.set_next_spawn(Vector2(World.OVERWORLD_WIDTH * 16, World.OVERWORLD_HEIGHT * 16))
		get_tree().change_scene_to_file("res://scenes/Overworld2.tscn")
		return

	if progress.final_boss_revealed:
		if not GameState.boss_defeated.final_boss:
			_dialogue_ui().show_dialogue("Altar", "The Ancient Warden still guards the far reaches of the valley.")
			return
		if Inventory.get_count("magic_crystal") >= 1:
			Inventory.remove_item("magic_crystal", 1)
			progress.world2_unlocked = true
			changed.emit()
			_dialogue_ui().show_dialogue("Altar", "The crystal dissolves into light... A portal to a new world opens! Return here and step through when you're ready.")
		else:
			_dialogue_ui().show_dialogue("Altar", "The altar awaits the Ancient Warden's crystal.")
		return

	if Inventory.get_count("magic_crystal") >= CRYSTALS_TO_REVEAL:
		Inventory.remove_item("magic_crystal", CRYSTALS_TO_REVEAL)
		progress.final_boss_revealed = true
		changed.emit()
		var current: Node = get_tree().current_scene
		if current.has_method("reveal_final_boss_entrance"):
			current.reveal_final_boss_entrance()
		_dialogue_ui().show_dialogue("Altar", "The two crystals resonate... a hidden path reveals itself at the edge of the valley!")
	else:
		var have: int = Inventory.get_count("magic_crystal")
		_dialogue_ui().show_dialogue("Altar", "Two Guardians protect ancient power. Bring their crystals here. (%d/%d Magic Crystals)" % [have, CRYSTALS_TO_REVEAL])
