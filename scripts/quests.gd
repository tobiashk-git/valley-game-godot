extends Node
# Autoload — quest definitions + state, port of quests.js. gather_wood is
# the original vertical-slice fetch quest (offered/turned-in through an
# NPC's dialogue). meet_villagers is the fence/gates tutorial: auto-active
# from boot, no giver/dialogue of its own - it completes silently the moment
# every villager has been talked to (see mark_npc_met(), called from
# npc.gd's one-time intro), which is also what unlocks the village gates.

signal changed

const QUEST_DEFS := {
	"gather_wood": {
		"giver_name": "Village Elder",
		"name": "A Village in Need",
		"objective": {"type": "gather", "item_id": "wood", "amount": 5},
		"reward": {"gold": 20, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "Traveler! Our village could use some wood for repairs. Could you bring me 5 Wood?",
			"in_progress": "I still need 5 Wood - do you have any to spare?",
			"ready": "Wonderful, you've brought the wood! Thank you.",
			"completed": "Thanks again for your help, traveler.",
		},
	},
	# The fence/gates tutorial. Offered by the Village Elder, who stands
	# OUTSIDE his house on the village square (user request: the player has
	# to go to him to receive it) - accepting it counts as meeting him, so
	# the objective is the one other villager. Completes silently the moment
	# the Trader's intro plays (see mark_npc_met()), or on the spot if the
	# player met the Trader first (see _accept_quest()). No reward entry:
	# the gates opening IS the reward.
	"meet_villagers": {
		"giver_name": "Village Elder",
		"name": "Meet the Village",
		"objective": {"type": "talk_to_npcs", "npc_ids": ["village_trader"], "goal": "Introduce yourself to the Village Trader in the south-west house."},
		"dialogue": {
			"offer": "Welcome to the valley, traveler! Before you go wandering, meet the rest of us - the Trader keeps the house in the south-west corner. Once you've said hello, I'll have the gates opened for you.",
			"in_progress": "The Trader's in the south-west house - go and say hello, and the gates are yours.",
			"ready": "You've met everyone worth meeting. The gates are open - the valley's yours to explore.",
			"completed": "The gates are open - the valley's yours to explore. Mind the river fords, though.",
		},
	},
	"cross_frostpeak": {
		"giver_name": "Frostpeak Ranger",
		"name": "Reinforcing the Ford",
		"objective": {"type": "gather_multi", "items": [
			{"item_id": "wood", "amount": 8},
			{"item_id": "stone", "amount": 8},
		]},
		"reward": {"gold": 35, "item_id": "healing_potion", "item_amount": 2},
		"dialogue": {
			"offer": "The ford north of here washed out ages ago - Frostpeak's been cut off ever since. Bring me 8 Wood and 8 Stone and I'll get it shored up.",
			"in_progress": "Still need more Wood and Stone for the ford - can you spare any?",
			"ready": "That's enough to shore up the crossing. Give me a moment... there, it'll hold now.",
			"completed": "The ford's holding steady, thanks to you.",
		},
	},
	"cross_verdantwood": {
		"giver_name": "Forest Druid",
		"name": "Clearing the Crossing",
		"objective": {"type": "gather", "item_id": "wood", "amount": 12},
		"reward": {"gold": 35, "item_id": "healing_potion", "item_amount": 2},
		"dialogue": {
			"offer": "The ford into Verdantwood is choked with fallen branches - bring me 12 Wood and I'll see it cleared.",
			"in_progress": "Still need more wood to clear the crossing - what have you got?",
			"ready": "That should do it. Let the forest breathe again...",
			"completed": "The crossing's clear, thanks to you.",
		},
	},
	"cross_badlands": {
		"giver_name": "Badlands Prospector",
		"name": "Shoring Up the Crossing",
		"objective": {"type": "gather", "item_id": "stone", "amount": 12},
		"reward": {"gold": 35, "item_id": "healing_potion", "item_amount": 2},
		"dialogue": {
			"offer": "The ford into Emberfall's crumbling at the edges - bring me 12 Stone and I'll get it packed solid again.",
			"in_progress": "Still need more stone for the crossing - what have you got?",
			"ready": "That'll do it. Should hold against the heat now.",
			"completed": "Crossing's solid, thanks to you.",
		},
	},
	"cross_gloomfen": {
		"giver_name": "Marsh Guide",
		"name": "Laying the Boardwalk",
		"objective": {"type": "gather", "item_id": "wood", "amount": 12},
		"reward": {"gold": 35, "item_id": "healing_potion", "item_amount": 2},
		"dialogue": {
			"offer": "The old boardwalk into Gloomfen rotted through long ago - bring me 12 Wood and I'll lay a new one.",
			"in_progress": "Still need more wood for the boardwalk - what have you got?",
			"ready": "That'll do it. Should hold you over the worst of the mire now.",
			"completed": "The boardwalk's holding, thanks to you.",
		},
	},
	# The Golden Plains gating quest - unlike the 4 ford quests above, this
	# doesn't open a river crossing (Golden Plains IS the valley, no river to
	# cross). Reuses the Village Trader (previously shop-only) rather than a
	# new standalone NPC - a lighter ask (6 items vs 8-12) and lighter reward
	# than the ford quests, matching its "light gate" framing.
	"open_ancient_barrow": {
		"giver_name": "Village Trader",
		"name": "What Lies Beneath",
		"objective": {"type": "gather", "item_id": "stone", "amount": 6},
		"reward": {"gold": 25, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "There's an old barrow at the edge of the valley - sealed for as long as anyone can remember. Bring me 6 Stone to clear the collapsed entrance and I'll show you where it lies.",
			"in_progress": "Still need more stone to clear the barrow's entrance - what have you got?",
			"ready": "That's enough. Let me show you where it opens up.",
			"completed": "The old barrow's open now, thanks to you.",
		},
	},
}

# quest_id -> "accepted" | "completed" (absent = not yet offered).
# Nothing is pre-accepted: even the tutorial (meet_villagers) is handed out
# by the Elder in person, so the first thing to do is go and find him.
var quest_state: Dictionary = {}

# npc_id -> true once that NPC's one-time intro has played (see npc.gd).
var npcs_met: Dictionary = {}

# Quest ids currently pinned to the always-visible QuestTracker overlay,
# toggled from the Journal (QuestPanel) or automatically on accept (see
# _accept_quest()/_mark_completed() below). Capped at MAX_TRACKED - tracking
# a 3rd quest (manually or on auto-accept) is simply refused (the Journal
# disables that row's Track button at the cap) rather than evicting an
# existing one, so the player always chooses what gets dropped. A completed
# quest can't be tracked at all - it's untracked the moment it completes,
# same as leaving the Journal's Active section.
const MAX_TRACKED := 2
var tracked_quests: Array[String] = []

func is_tracked(quest_id: String) -> bool:
	return tracked_quests.has(quest_id)

func toggle_track(quest_id: String) -> void:
	if tracked_quests.has(quest_id):
		tracked_quests.erase(quest_id)
	elif tracked_quests.size() < MAX_TRACKED:
		tracked_quests.append(quest_id)
	changed.emit()

func objective_met(quest_id: String) -> bool:
	var objective: Dictionary = QUEST_DEFS[quest_id].objective
	if objective.type == "gather":
		return Inventory.get_count(objective.item_id) >= objective.amount
	if objective.type == "gather_multi":
		for entry in objective.items:
			if Inventory.get_count(entry.item_id) < entry.amount:
				return false
		return true
	if objective.type == "talk_to_npcs":
		for npc_id in objective.npc_ids:
			if not npcs_met.get(npc_id, false):
				return false
		return true
	return false

# e.g. "3/5 [icon] Wood" or "1/2 Villagers" - used by the offer-in-progress
# line (gather quests) and the Journal (every quest). BBCode (the gather
# case embeds an inline item icon) - every consumer (DialogueUI's
# text_label, quest_panel.gd's Journal rows, quest_tracker.gd's status
# label) is a bbcode_enabled RichTextLabel.
func objective_progress_text(quest_id: String) -> String:
	var objective: Dictionary = QUEST_DEFS[quest_id].objective
	if objective.type == "gather":
		var have: int = min(Inventory.get_count(objective.item_id), objective.amount)
		return "%d/%d %s" % [have, objective.amount, Items.get_item_name_bbcode(objective.item_id)]
	if objective.type == "gather_multi":
		var parts: Array[String] = []
		for entry in objective.items:
			var have_entry: int = min(Inventory.get_count(entry.item_id), entry.amount)
			parts.append("%d/%d %s" % [have_entry, entry.amount, Items.get_item_name_bbcode(entry.item_id)])
		return ", ".join(parts)
	if objective.type == "talk_to_npcs":
		var have := 0
		for npc_id in objective.npc_ids:
			if npcs_met.get(npc_id, false):
				have += 1
		return "%d/%d Villagers" % [have, objective.npc_ids.size()]
	return ""

# Called by npc.gd when the player interacts with a quest-giving NPC. Picks
# the right dialogue line + Accept/Turn In choices for the quest's current
# state and shows it via DialogueUI - same one-frame-guard box every other
# NPC already uses, just sometimes with buttons attached.
func talk_to_giver(quest_id: String) -> void:
	var def: Dictionary = QUEST_DEFS[quest_id]
	var state: String = quest_state.get(quest_id, "")
	var dialogue_ui: Node = get_node("/root/DialogueUI")

	if state == "completed":
		dialogue_ui.show_dialogue(def.giver_name, def.dialogue.completed)
	elif state == "accepted":
		if objective_met(quest_id):
			dialogue_ui.show_dialogue(def.giver_name, def.dialogue.ready, [
				{"label": "Turn In", "callback": _complete_quest.bind(quest_id)},
				{"label": "Not yet", "callback": Callable()},
			])
		else:
			dialogue_ui.show_dialogue(def.giver_name, "%s (%s)" % [def.dialogue.in_progress, objective_progress_text(quest_id)])
	else:
		dialogue_ui.show_dialogue(def.giver_name, def.dialogue.offer, [
			{"label": "Accept", "callback": _accept_quest.bind(quest_id)},
			{"label": "Not now", "callback": Callable()},
		])

func _accept_quest(quest_id: String) -> void:
	quest_state[quest_id] = "accepted"
	# Auto-track so it's immediately visible on the overlay without a trip
	# to the Journal - silently skipped if the tracker is already full,
	# same as a manual Track click at the cap.
	if tracked_quests.size() < MAX_TRACKED:
		tracked_quests.append(quest_id)
	# The tutorial has no turn-in step: if the player already met the Trader
	# before finding the Elder, it's done the moment it's accepted - and the
	# Elder says so (the Accept button's own box has just closed).
	if quest_id == "meet_villagers" and objective_met(quest_id):
		_mark_completed(quest_id)
		_open_village_gates()
		get_node("/root/DialogueUI").show_dialogue(QUEST_DEFS[quest_id].giver_name, "You've already met the Trader? Splendid. The village gates are open - the valley's yours to explore.")
	changed.emit()

func _mark_completed(quest_id: String) -> void:
	quest_state[quest_id] = "completed"
	tracked_quests.erase(quest_id)

func _complete_quest(quest_id: String) -> void:
	Audio.play_sfx("quest")
	var def: Dictionary = QUEST_DEFS[quest_id]
	var objective: Dictionary = def.objective
	if objective.has("items"):
		for entry in objective.items:
			Inventory.remove_item(entry.item_id, entry.amount)
	elif objective.has("item_id"):
		Inventory.remove_item(objective.item_id, objective.amount)
	var reward: Dictionary = def.get("reward", {})
	if reward.has("gold"):
		Inventory.add_item("gold", reward.gold)
	if reward.has("item_id"):
		Inventory.add_item(reward.item_id, reward.get("item_amount", 1))
	_mark_completed(quest_id)
	if quest_id == "cross_frostpeak":
		GameState.biome_paths_open.frostpeak = true
	elif quest_id == "cross_verdantwood":
		GameState.biome_paths_open.verdantwood = true
	elif quest_id == "cross_badlands":
		GameState.biome_paths_open.badlands = true
	elif quest_id == "cross_gloomfen":
		GameState.biome_paths_open.gloomfen = true
	elif quest_id == "open_ancient_barrow":
		GameState.world_progress.golden_plains_revealed = true
	changed.emit()

# Called by npc.gd the first time (and only the first time) the player
# interacts with a given NPC. Returns true if this specific interaction is
# the one that completes meet_villagers (and thus opens the gates) - the
# caller uses that to fold a "gates opened" line into the same intro
# message instead of trying to show a second dialogue on top of the first.
func mark_npc_met(npc_id: String) -> bool:
	npcs_met[npc_id] = true
	changed.emit()
	# Only an ACCEPTED tutorial completes here - meeting the Trader before
	# the Elder just counts towards it (see _accept_quest()).
	if quest_state.get("meet_villagers", "") != "accepted":
		return false
	if not objective_met("meet_villagers"):
		return false
	_mark_completed("meet_villagers")
	_open_village_gates()
	changed.emit()
	return true

# Flips the flag AND repaints the gates if the player is standing on the
# overworld right now - the scene only reads the flag in its _ready(), so
# completing the tutorial outside (met the Trader first, then accepted from
# the Elder on the square) used to leave the gates shut until a reload.
func _open_village_gates() -> void:
	GameState.village_gates_open = true
	var scene: Node = get_tree().current_scene
	if scene != null and scene.name == "Overworld" and scene.has_node("TileMapLayer"):
		World.open_gates(scene.get_node("TileMapLayer"))

func reset() -> void:
	quest_state = {}
	npcs_met = {}
	tracked_quests.clear()
	changed.emit()
