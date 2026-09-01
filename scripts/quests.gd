extends Node
# Autoload — quest definitions + state, port of quests.js's first vertical
# slice (one fetch quest, offered/turned-in through an NPC's dialogue, not a
# separate quest UI). One entry for now, matching the JS reference's own
# "smallest slice that proves the loop end-to-end" scope decision.

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
}

var quest_state: Dictionary = {} # quest_id -> "accepted" | "completed" (absent = not yet offered)

func objective_met(quest_id: String) -> bool:
	var objective: Dictionary = QUEST_DEFS[quest_id].objective
	if objective.type == "gather":
		return Inventory.get_count(objective.item_id) >= objective.amount
	return false

# e.g. "3/5 Wood" - used by both the offer-in-progress line and the Journal.
func objective_progress_text(quest_id: String) -> String:
	var objective: Dictionary = QUEST_DEFS[quest_id].objective
	if objective.type == "gather":
		var have: int = min(Inventory.get_count(objective.item_id), objective.amount)
		return "%d/%d %s" % [have, objective.amount, Items.get_item_name(objective.item_id)]
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
