class_name StoryJump
# Chapter jump for playtesting (user, 2026-09-08: "I really want to get a
# feel for the gating flow of the whole story"). Settings > Story jump sets
# the game to the START of a chapter: every earlier story quest turned in
# (and its world effects applied), the bosses so far asleep, the companions
# who have joined, and Oliver at the level and in the full armour set that
# chapter expects (the set-rule ladder) - then saves and lands him on the
# village square. Chapter 1 is a fresh game without the intro.
#
# What each chapter start assumes (mirrors the story line in quests.gd):
#   1 village     - nothing
#   2 frostpeak   - chapter 1 done: barrow + Bone Lord asleep, 1 crystal; L3, leather full
#   3 verdantwood - + northern ford, Luigi, Revenant asleep; L5, frost full
#   4 badlands    - + eastern ford, Eden, Bramblewood asleep; L8, ironwood full
#   5 gloomfen    - + southern ford, the pair, Cinderjaw asleep; L10, ember full
#   6 finale      - + western ford, Bogmaw asleep; L12, bog-iron full

const CHAPTER_ORDER := ["village", "frostpeak", "verdantwood", "badlands", "gloomfen", "finale"]

# Story quests completed on ENTERING each chapter (cumulative).
const DONE_BY := {
	"village": [],
	"frostpeak": ["meet_villagers", "gather_wood", "bank_gold", "open_ancient_barrow", "hunt_barrow", "hunt_dungeon"],
	"verdantwood": ["cross_frostpeak", "join_luigi", "hunt_frostpeak"],
	"badlands": ["cross_verdantwood", "join_eden", "hunt_verdantwood"],
	"gloomfen": ["cross_badlands", "join_pair", "hunt_badlands"],
	"finale": ["cross_gloomfen", "hunt_gloomfen"],
}
const BOSSES_BY := {
	"frostpeak": ["golden_plains_boss", "dungeon_boss"],
	"verdantwood": ["frostpeak_boss"],
	"badlands": ["verdantwood_boss"],
	"gloomfen": ["badlands_boss"],
	"finale": ["gloomfen_boss"],
}
const FORDS_BY := {"verdantwood": "frostpeak", "badlands": "verdantwood", "gloomfen": "badlands", "finale": "gloomfen"}
# Level and full set on entering the chapter (weapon first).
const KIT := {
	"village": {"level": 1, "gear": []},
	"frostpeak": {"level": 3, "gear": ["wooden_pickaxe", "leather_armor", "leather_cap", "leather_greaves", "leather_boots", "leather_gloves"]},
	"verdantwood": {"level": 5, "gear": ["frost_pick", "frostweave_coat", "frost_helm", "frost_greaves", "frost_boots", "frost_gloves"]},
	"badlands": {"level": 8, "gear": ["ironwood_blade", "ironwood_mail", "ironwood_helm", "ironwood_greaves", "ironwood_boots", "ironwood_gloves"]},
	"gloomfen": {"level": 10, "gear": ["ember_blade", "ember_plate", "ember_helm", "ember_greaves", "ember_boots", "ember_gloves"]},
	"finale": {"level": 12, "gear": ["bogiron_cleaver", "bogiron_harness", "bogiron_helm", "bogiron_greaves", "bogiron_boots", "bogiron_gloves"]},
}
const GOLD := 120
const POTIONS := 3

static func chapter_index(chapter_id: String) -> int:
	return CHAPTER_ORDER.find(chapter_id)

# Applies the chapter start to the autoloads (no scene change) - the part
# a verify can call. Returns false for an unknown chapter.
static func apply(tree: SceneTree, chapter_id: String) -> bool:
	var idx: int = chapter_index(chapter_id)
	if idx < 0:
		return false
	var root: Node = tree.root
	var game_state: Node = root.get_node("GameState")
	var quests: Node = root.get_node("Quests")
	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var storage: Node = root.get_node("Storage")
	var combat: Node = root.get_node("Combat")
	game_state.reset()
	quests.reset()
	inventory.reset()
	character.reset()
	storage.reset()
	combat.reset()
	game_state.intro_pending = false
	if idx == 0:
		return true
	# Quests and their world effects, chapter by chapter up to this one.
	for i in range(1, idx + 1):
		var ch: String = CHAPTER_ORDER[i]
		for quest_id in DONE_BY[ch]:
			quests.quest_state[quest_id] = "completed"
		for boss_id in BOSSES_BY.get(ch, []):
			game_state.boss_defeated[boss_id] = true
		if FORDS_BY.has(ch):
			game_state.biome_paths_open[FORDS_BY[ch]] = true
	game_state.village_gates_open = true
	game_state.world_progress.golden_plains_revealed = true
	# Every villager met, the joined companions' events done (in DONE_BY).
	for npc_id in ["village_elder", "village_trader", "village_blacksmith", "luigi", "eden"]:
		quests.npcs_met[npc_id] = true
	# The pack: the crystal from the Bone Lord, gold, potions, the chapter's kit worn.
	inventory.add_item("magic_crystal", 1)
	inventory.add_item("gold", GOLD)
	inventory.add_item("healing_potion", POTIONS)
	inventory.add_item("angel_feather", 1)
	var kit: Dictionary = KIT[chapter_id]
	while character.stats.level < kit.level:
		character.gain_xp(character.xp_to_next(character.stats.level))
	character.stats.hp = character.stats.max_hp
	character.stats.mp = character.stats.max_mp
	for item_id in kit.gear:
		inventory.add_item(item_id, 1)
		character.equip(root.get_node("Items").ITEMS[item_id].slot, item_id)
	quests.changed.emit()
	return true

# The Settings button: apply, save, and land on the village square.
static func jump(tree: SceneTree, chapter_id: String) -> void:
	if not apply(tree, chapter_id):
		return
	var root: Node = tree.root
	var world: Node = root.get_node("World")
	var spawn: Vector2i = world.ELDER_POS + Vector2i(0, 2)
	root.get_node("GameState").set_next_spawn(Vector2(spawn.x * 32 + 16, spawn.y * 32 + 16))
	root.get_node("SaveSystem").save_game()
	tree.change_scene_to_file("res://scenes/Overworld.tscn")
