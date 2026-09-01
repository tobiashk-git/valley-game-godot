extends SceneTree

func _initialize() -> void:
	var trader_scene: PackedScene = load("res://scenes/TraderHouse.tscn")
	var trader_house: Node2D = trader_scene.instantiate()
	root.add_child(trader_house)
	current_scene = trader_house
	await process_frame
	await process_frame

	var inventory: Node = root.get_node("Inventory")
	var shop: Node = root.get_node("Shop")
	var shop_panel: Node = root.get_node("ShopPanel")
	var player: CharacterBody2D = trader_house.get_node("YSort/Player")

	var ysort: Node2D = trader_house.get_node("YSort")
	var trader: Node = null
	for child in ysort.get_children():
		if child.name.begins_with("NPC"):
			trader = child
	print("Trader NPC found: ", trader != null)

	player.position = trader.position + Vector2(0, 20)
	for i in range(3):
		await process_frame

	# --- Dismiss the one-time intro (village fence/gates tutorial) first -
	# the shop opens on the *second* interaction now, not the first. ---
	var dialogue_ui: Node = root.get_node("DialogueUI")
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Intro shown first: ", dialogue_ui.text_label.text.begins_with("Welcome, welcome"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# --- Walk up + E opens the shop directly (no dialogue step). ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Shop opened via walk-up + E: ", shop_panel.is_open())
	print("Defaults to Buy tab: ", shop_panel.buy_tab_btn.disabled)
	root.get_texture().get_image().save_png("res://verify_shop_buy_broke.png")

	# --- Buy fails when broke (0 gold). ---
	var list: VBoxContainer = shop_panel.get_node("Panel/Margin/VBox/List")
	var potion_row: HBoxContainer = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text.contains("Healing Potion"):
			potion_row = row
	print("Healing Potion buy row found: ", potion_row != null)
	var buy_btn: Button = potion_row.get_child(1)
	print("Buy button disabled while broke: ", buy_btn.disabled)

	# --- Give gold, buy a potion. ---
	inventory.add_item("gold", 100)
	await process_frame
	potion_row = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text.contains("Healing Potion"):
			potion_row = row
	buy_btn = potion_row.get_child(1)
	print("Buy button enabled with gold: ", not buy_btn.disabled)
	var gold_before: int = inventory.get_count("gold")
	buy_btn.pressed.emit()
	await process_frame
	print("Potion bought: ", inventory.get_count("healing_potion") == 1)
	print("Gold deducted (12): ", inventory.get_count("gold") == gold_before - 12)
	root.get_texture().get_image().save_png("res://verify_shop_after_buy.png")

	# --- Switch to Sell tab: bought potion + gathered wood should list; gold/equipped gear should not. ---
	inventory.add_item("wood", 3)
	var character: Node = root.get_node("Character")
	inventory.add_item("wooden_pickaxe", 1)
	character.equip("weapon", "wooden_pickaxe")
	shop_panel.sell_tab_btn.pressed.emit()
	await process_frame
	print("Sell tab active: ", shop_panel.sell_tab_btn.disabled)
	var sell_texts: Array = []
	for row in list.get_children():
		if row is HBoxContainer:
			sell_texts.append((row.get_child(0) as Label).text)
	print("Sell list: ", sell_texts)
	var has_wood := false
	var has_potion := false
	var has_gold := false
	var has_equipped_pickaxe := false
	for t in sell_texts:
		if t.contains("Wood") and not t.contains("Wooden Pickaxe"):
			has_wood = true
		if t.contains("Healing Potion"):
			has_potion = true
		if t.contains("Gold"):
			has_gold = true
		if t.contains("Wooden Pickaxe"):
			has_equipped_pickaxe = true
	print("Wood listed on Sell: ", has_wood)
	print("Healing Potion listed on Sell: ", has_potion)
	print("Gold never listed on Sell: ", not has_gold)
	print("Equipped pickaxe NOT listed (it's not in the backpack): ", not has_equipped_pickaxe)
	root.get_texture().get_image().save_png("res://verify_shop_sell_tab.png")

	# --- Sell the wood. ---
	var wood_row: HBoxContainer = null
	for row in list.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text.contains("Wood") and not (row.get_child(0) as Label).text.contains("Wooden Pickaxe"):
			wood_row = row
	var sell_btn: Button = wood_row.get_child(1)
	var gold_before_sell: int = inventory.get_count("gold")
	sell_btn.pressed.emit()
	await process_frame
	print("Wood count reduced by 1 after selling: ", inventory.get_count("wood") == 2)
	print("Gold gained from selling (1 gold, half of value 1 rounded up to min 1): ", inventory.get_count("gold") == gold_before_sell + 1)

	# --- Close via E, confirm it stays closed (process-priority fix). ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Shop closed via E: ", not shop_panel.is_open())

	quit()
