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
	"meet_villagers": {
		"name": "Meet the Village",
		"objective": {"type": "talk_to_npcs", "npc_ids": ["village_elder", "village_trader"]},
	},
}

# quest_id -> "accepted" | "completed" (absent = not yet offered).
# meet_villagers starts pre-accepted so the Journal shows live progress from
# the very first frame - fitting for a tutorial the player has no choice
# but to complete anyway.
var quest_state: Dictionary = {"meet_villagers": "accepted"}

# npc_id -> true once that NPC's one-time intro has played (see npc.gd).
var npcs_met: Dictionary = {}

func objective_met(quest_id: String) -> bool:
	var objective: Dictionary = QUEST_DEFS[quest_id].objective
	if objective.type == "gather":
		return Inventory.get_count(objective.item_id) >= objective.amount
	if objective.type == "talk_to_npcs":
		for npc_id in objective.npc_ids:
			if not npcs_met.get(npc_id, false):
				return false
		return true
	return false

# e.g. "3/5 Wood" or "1/2 Villagers" - used by the offer-in-progress line
# (gather quests) and the Journal (every quest).
func objective_progress_text(quest_id: String) -> String:
	var objective: Dictionary = QUEST_DEFS[quest_id].objective
	if objective.type == "gather":
		var have: int = min(Inventory.get_count(objective.item_id), objective.amount)
		return "%d/%d %s" % [have, objective.amount, Items.get_item_name(objective.item_id)]
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
	changed.emit()

func _complete_quest(quest_id: String) -> void:
	var def: Dictionary = QUEST_DEFS[quest_id]
	var objective: Dictionary = def.objective
	Inventory.remove_item(objective.item_id, objective.amount)
	var reward: Dictionary = def.reward
	if reward.has("gold"):
		Inventory.add_item("gold", reward.gold)
	if reward.has("item_id"):
		Inventory.add_item(reward.item_id, reward.get("item_amount", 1))
	quest_state[quest_id] = "completed"
	changed.emit()

# Called by npc.gd the first time (and only the first time) the player
# interacts with a given NPC. Returns true if this specific interaction is
# the one that completes meet_villagers (and thus opens the gates) - the
# caller uses that to fold a "gates opened" line into the same intro
# message instead of trying to show a second dialogue on top of the first.
func mark_npc_met(npc_id: String) -> bool:
	npcs_met[npc_id] = true
	changed.emit()
	if quest_state.get("meet_villagers", "") == "completed":
		return false
	if not objective_met("meet_villagers"):
		return false
	quest_state["meet_villagers"] = "completed"
	GameState.village_gates_open = true
	changed.emit()
	return true
