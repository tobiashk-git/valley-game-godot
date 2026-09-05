extends SceneTree
# Dialogue portraits verification. Run via:
# godot --script res://tools/verify_portraits.gd (NOT --headless).
#
# A speaker with a portrait file gets the bust at the left of the box and
# the text column beside it; a speaker without one gets no frame and the
# text spans the box; the box self-fits either way; on a phone the box is
# nearly full width with a smaller bust; the intro pages show Oliver.

func _initialize() -> void:
	var dialogue: CanvasLayer = root.get_node("DialogueUI")
	var layout: Node = root.get_node("Layout")
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	# --- Oliver has a portrait. ---
	dialogue.show_dialogue("Oliver", "Boots on, then. The door's just south of here - let's go and see this valley.", [{"label": "Off we go", "callback": Callable()}])
	await process_frame
	await process_frame
	var frame_rect: Rect2 = dialogue.portrait_frame.get_global_rect()
	var text_rect: Rect2 = dialogue.text_label.get_global_rect()
	print("Oliver's bust shows in a 96px frame at the left, text column to its right: ", dialogue.portrait_frame.visible and dialogue.portrait.texture != null and frame_rect.size == Vector2(96, 96) and text_rect.position.x >= frame_rect.end.x + 8.0)
	print("The box fits the taller of bust and text (button inside the panel): ", dialogue.actions_row.get_global_rect().end.y <= dialogue.panel.get_global_rect().end.y and frame_rect.end.y <= dialogue.panel.get_global_rect().end.y)
	root.get_texture().get_image().save_png("res://verify_portrait_oliver.png")
	print("Saved verify_portrait_oliver.png")

	# --- NPC busts that exist so far (added one at a time). ---
	for speaker in ["Village Elder", "Village Trader", "Frostpeak Ranger", "Forest Druid", "Badlands Prospector", "Marsh Guide"]:
		if dialogue.portrait_for(speaker) == null:
			continue
		dialogue.show_dialogue(speaker, "Ah, a new face! I'm the %s - good to meet you, traveler." % speaker, [{"label": "Accept", "callback": Callable()}, {"label": "Not now", "callback": Callable()}])
		await process_frame
		await process_frame
		var fr: Rect2 = dialogue.portrait_frame.get_global_rect()
		print("%s: bust shows beside the text, box fits: " % speaker, dialogue.portrait_frame.visible and fr.size == Vector2(96, 96) and dialogue.actions_row.get_global_rect().end.y <= dialogue.panel.get_global_rect().end.y)
		var file: String = "res://verify_portrait_%s.png" % speaker.to_lower().replace(" ", "_")
		root.get_texture().get_image().save_png(file)
		print("Saved ", file)

	# --- A speaker without a file: no frame, full-width text. ---
	dialogue.show_dialogue("Forest Druid", "You've wandered far from the village.")
	await process_frame
	await process_frame
	print("Speaker without a portrait file: frame hidden, text spans the box: ", not dialogue.portrait_frame.visible and dialogue.portrait.texture == null and dialogue.text_label.get_global_rect().position.x < dialogue.panel.get_global_rect().position.x + 20.0)
	print("Unknown speaker name gets no portrait either: ", dialogue.portrait_for("Nobody") == null)
	dialogue.hide_dialogue()

	# --- Phone. ---
	root.size = Vector2i(400, 660)
	for i in range(6):
		await process_frame
	dialogue.show_dialogue("Oliver", "My first day in the valley. A house of my own, a village I barely know, and a whole valley beyond the gates that nobody has told me much about.", [{"label": "Next", "callback": Callable()}])
	await process_frame
	await process_frame
	var p: Rect2 = dialogue.panel.get_global_rect()
	frame_rect = dialogue.portrait_frame.get_global_rect()
	print("Phone: box spans the width (12px margins), 72px bust, text beside it, everything inside: ", layout.is_narrow() and p.position.x == 12.0 and p.end.x == 388.0 and frame_rect.size == Vector2(72, 72) and dialogue.text_label.get_global_rect().position.x >= frame_rect.end.x + 8.0 and dialogue.actions_row.get_global_rect().end.y <= p.end.y and p.end.y <= 660.0)
	root.get_texture().get_image().save_png("res://verify_portrait_phone.png")
	print("Saved verify_portrait_phone.png")
	dialogue.hide_dialogue()
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()
