extends SceneTree
# Worn armour on the walking sprite. Run via:
# godot --script res://tools/verify_armour_layers.gd (NOT --headless).
# The player carries an ArmorLayer overlay over its base sprite; it is
# hidden with nothing worn, shows the item's LPC torso layer when armour is
# equipped, mirrors the base's animation/frame/offset while walking, and
# every armour item's layer sheet exists on the same 576x256 walk grid.

func _initialize() -> void:
	var items: Node = root.get_node("Items")
	var character: Node = root.get_node("Character")
	var inventory: Node = root.get_node("Inventory")
	var house: Node2D = load("res://scenes/House.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in range(4):
		await process_frame
	var player: CharacterBody2D = house.get_node("YSort/Player")
	var layer: AnimatedSprite2D = player.get_node_or_null("ArmorLayer")
	character.unequip("armor")
	await process_frame
	print("Player has an ArmorLayer overlay above its base sprite (third of four layers: legs, feet, body, head), hidden with nothing worn: ", layer != null and layer.get_index() == player.sprite.get_index() + 3 and not layer.visible)
	var all_ok := true
	for item_id in items.ITEMS.keys():
		var def: Dictionary = items.ITEMS[item_id]
		if def.get("slot", "") != "armor":
			continue
		var path: String = def.get("layer", "")
		var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
		if tex == null or tex.get_size() != Vector2(576, 256):
			all_ok = false
			print("  missing/odd layer for ", item_id, ": ", path)
	print("Every armour item has a 576x256 layer sheet (leather + the four tiers + Royal Plate): ", all_ok)
	inventory.add_item("leather_armor", 1)
	character.equip("armor", "leather_armor")
	await process_frame
	await process_frame
	print("Equipping Leather Armor shows the leather torso layer over Oliver: ", layer.visible and layer.get_meta("layer_path", "").ends_with("leather_armor.png") and layer.sprite_frames.get_animation_names().size() == player.sprite.sprite_frames.get_animation_names().size())
	# Walk: the layer follows the base frame by frame.
	Input.action_press("move_right")
	for i in range(12):
		await physics_frame
	await process_frame
	var synced: bool = layer.animation == player.sprite.animation and layer.frame == player.sprite.frame and layer.animation == "right"
	Input.action_release("move_right")
	print("Walking right, the layer plays the same animation and frame as the base: ", synced)
	root.get_texture().get_image().save_png("res://verify_armour_layer.png")
	print("Saved verify_armour_layer.png")
	inventory.add_item("ember_plate", 1)
	character.equip("armor", "ember_plate")
	await process_frame
	print("Swapping to Ember Plate swaps the sheet: ", layer.visible and layer.get_meta("layer_path", "").ends_with("ember_plate.png"))
	character.unequip("armor")
	await process_frame
	print("Unequipping hides it again: ", not layer.visible)
	quit()
