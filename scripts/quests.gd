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
		"line": "story", "chapter": "village", "requires": ["meet_villagers"],
		"objective": {"type": "gather", "item_id": "wood", "amount": 5},
		"reward": {"xp": 40, "gold": 20, "item_id": "healing_potion", "item_amount": 1},
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
	# player met the Trader first (see _accept_quest()). Its reward is a
	# little XP - the gates opening is the real reward (npc.gd's "?" marker
	# keys off a gold reward, so a silent completion never shows one).
	"meet_villagers": {
		"giver_name": "Village Elder",
		"name": "Meet the Village",
		"line": "story", "chapter": "village", "requires": [],
		# Four villagers to meet (2026-09-07): the Trader and the Blacksmith in
		# their houses, Luigi and Eden on the square.
		"objective": {"type": "talk_to_npcs", "npc_ids": ["village_trader", "village_blacksmith", "luigi", "eden"], "goal": "Say hello to the Village Trader (south-west house), the Village Blacksmith (south-east house), Luigi the Fearless and Eden on the square."},
		"reward": {"xp": 20},
		"dialogue": {
			"offer": "Welcome to the valley, traveler! Before you go wandering, meet the rest of us: the Trader in the south-west house, the Blacksmith in the south-east one, and Luigi and Eden here on the square. Say hello to all four and I'll have the gates opened for you.",
			"in_progress": "The Trader's in the south-west house, the Blacksmith in the south-east, and Luigi and Eden are about the square - say hello to them all, and the gates are yours.",
			"ready": "You've met everyone worth meeting. The gates are open - the valley's yours to explore.",
			"completed": "The gates are open - the valley's yours to explore. Mind the river fords, though.",
		},
	},
	"cross_frostpeak": {
		"giver_name": "Frostpeak Ranger",
		"name": "Reinforcing the Ford",
		"line": "story", "chapter": "frostpeak", "requires": [],
		"objective": {"type": "gather_multi", "items": [
			{"item_id": "wood", "amount": 8},
			{"item_id": "stone", "amount": 8},
		]},
		"reward": {"xp": 120, "gold": 35, "item_id": "healing_potion", "item_amount": 1},
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
		"line": "story", "chapter": "verdantwood", "requires": [],
		"objective": {"type": "gather", "item_id": "wood", "amount": 12},
		"reward": {"xp": 150, "gold": 35, "item_id": "healing_potion", "item_amount": 1},
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
		"line": "story", "chapter": "badlands", "requires": [],
		"objective": {"type": "gather", "item_id": "stone", "amount": 12},
		"reward": {"xp": 180, "gold": 35, "item_id": "healing_potion", "item_amount": 1},
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
		"line": "story", "chapter": "gloomfen", "requires": [],
		"objective": {"type": "gather", "item_id": "wood", "amount": 12},
		"reward": {"xp": 210, "gold": 35, "item_id": "healing_potion", "item_amount": 1},
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
		"line": "side", "requires": [],
		"objective": {"type": "gather", "item_id": "stone", "amount": 6},
		"reward": {"xp": 90, "gold": 25, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "There's an old barrow at the edge of the valley - sealed for as long as anyone can remember. Bring me 6 Stone to clear the collapsed entrance and I'll show you where it lies.",
			"in_progress": "Still need more stone to clear the barrow's entrance - what have you got?",
			"ready": "That's enough. Let me show you where it opens up.",
			"completed": "The old barrow's open now, thanks to you.",
		},
	},
	# --- Story chapters (quest lines revamp, 2026-09-07). The Village Elder
	# is the story voice: after each ford opens he sends Oliver after that
	# biome's boss, and once all four sleep, after the two Guardians and the
	# Ancient Warden. Fords stay open in any order (the hunts only require
	# their own ford), so chapters 2-5 can be played in any order.
	"hunt_frostpeak": {
		"giver_name": "Village Elder",
		"name": "The Glacial Revenant",
		"line": "story", "chapter": "frostpeak", "requires": ["cross_frostpeak"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["frostpeak_boss"], "label": "Glacial Revenant asleep", "goal": "Find the ice caves beyond the northern ford and put the Glacial Revenant to sleep."},
		"reward": {"xp": 180, "gold": 50, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "The ford's open, but Frostpeak isn't safe yet - something haunts the ice caves up there. The Ranger calls it the Glacial Revenant. Put it to sleep and the ridge is ours again.",
			"in_progress": "The Revenant still walks the ice caves. Take a Frost set if you can forge one - the cold up there bites.",
			"ready": "The Revenant sleeps? Then Frostpeak breathes easy tonight. Well done, traveler.",
			"completed": "Frostpeak's quiet now, thanks to you.",
		},
	},
	"hunt_verdantwood": {
		"giver_name": "Village Elder",
		"name": "Elder Bramblewood",
		"line": "story", "chapter": "verdantwood", "requires": ["cross_verdantwood"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["verdantwood_boss"], "label": "Elder Bramblewood asleep", "goal": "Go deep into Verdantwood's tangled interior and put Elder Bramblewood to sleep."},
		"reward": {"xp": 220, "gold": 60, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "With the eastern crossing clear, the forest's rot can be reached at last. Something old and thorned sits at its heart - the Druid calls it Elder Bramblewood. Put it to sleep and the wood will heal.",
			"in_progress": "Bramblewood still chokes the forest's heart. Ironwood armour turns thorns, if the Blacksmith can make you some.",
			"ready": "The old bramble sleeps? Then Verdantwood can grow green again. You have my thanks.",
			"completed": "The forest's healing, thanks to you.",
		},
	},
	"hunt_badlands": {
		"giver_name": "Village Elder",
		"name": "Cinderjaw",
		"line": "story", "chapter": "badlands", "requires": ["cross_badlands"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["badlands_boss"], "label": "Cinderjaw asleep", "goal": "Brave the Emberfall interior and put Cinderjaw to sleep."},
		"reward": {"xp": 260, "gold": 70, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "The southern crossing holds, so Emberfall's open - and so is whatever's been setting the badlands alight. The Prospector calls it Cinderjaw. Put it to sleep before the fires spread.",
			"in_progress": "Cinderjaw still burns in the badlands. Ember plate shrugs off the heat - worth the forge time.",
			"ready": "Cinderjaw sleeps? The fires will die down now. Bravely done.",
			"completed": "The badlands are cooling, thanks to you.",
		},
	},
	"hunt_gloomfen": {
		"giver_name": "Village Elder",
		"name": "The Bogmaw",
		"line": "story", "chapter": "gloomfen", "requires": ["cross_gloomfen"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["gloomfen_boss"], "label": "The Bogmaw asleep", "goal": "Cross the new boardwalk into Gloomfen's depths and put the Bogmaw to sleep."},
		"reward": {"xp": 300, "gold": 80, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "The boardwalk's laid, and the marsh has a mouth at the end of it - the Guide calls it the Bogmaw. It's the worst of the four. Put it to sleep and the whole valley sleeps easier.",
			"in_progress": "The Bogmaw still lurks in the mire. Bog-iron is the only armour that keeps its teeth out.",
			"ready": "The Bogmaw sleeps? Then the last of the four is done. The valley owes you, traveler.",
			"completed": "Gloomfen's still now, thanks to you.",
		},
	},
	"two_guardians": {
		"giver_name": "Village Elder",
		"name": "The Two Guardians",
		"line": "story", "chapter": "finale", "requires": ["hunt_frostpeak", "hunt_verdantwood", "hunt_badlands", "hunt_gloomfen"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["dungeon_boss", "castle_boss"], "label": "Guardians asleep", "goal": "Put the Bone Lord in the old dungeon and the Royal Wraith in the castle to sleep, and bring their two crystals to the altar."},
		"reward": {"xp": 300, "gold": 100},
		"dialogue": {
			"offer": "All four biomes sleep, but the valley's oldest trouble is still below us. Two Guardians keep the way to it - the Bone Lord in the dungeon and the Royal Wraith in the castle. Each holds a crystal. Bring both to the altar on the square.",
			"in_progress": "The Guardians hold the crystals - the Bone Lord below the dungeon, the Royal Wraith in the castle. The altar needs both.",
			"ready": "Both crystals? Then the altar will show you where the Ancient Warden hides. Steel yourself, traveler.",
			"completed": "The Guardians sleep and the way is open.",
		},
	},
	"ancient_warden": {
		"giver_name": "Village Elder",
		"name": "The Ancient Warden",
		"line": "story", "chapter": "finale", "requires": ["two_guardians"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["final_boss"], "label": "Ancient Warden asleep", "goal": "Enter the hidden lair the altar revealed and put the Ancient Warden to sleep."},
		"reward": {"xp": 500, "gold": 200},
		"dialogue": {
			"offer": "The altar has shown you the lair. The Ancient Warden has slept fitfully under this valley for longer than anyone remembers - it's time it slept properly. Go carefully. Come back to us.",
			"in_progress": "The Warden waits in its lair. Everything you've forged, wear it.",
			"ready": "It sleeps? Truly? Then the valley is free, and it's you we have to thank. Rest, traveler. You've earned it.",
			"completed": "The valley is at peace, thanks to you. Enjoy it.",
		},
	},
	# --- Side quests: single actions and short chains, from the villagers.
	# A two-step chain for the Blacksmith (the second needs the first) and a
	# single hunt for the Druid.
	"forge_whetstone": {
		"giver_name": "Village Blacksmith",
		"name": "A Keen Edge",
		"line": "side", "requires": [],
		"objective": {"type": "gather", "item_id": "stone", "amount": 6},
		"reward": {"xp": 30, "gold": 15},
		"dialogue": {
			"offer": "My whetstone's worn to a sliver. Bring me 6 Stone and I'll cut a new one - and keep your blades sharp for nothing.",
			"in_progress": "Still need stone for that whetstone - got any?",
			"ready": "Good, solid stone. That'll grind for years. Here - for your trouble.",
			"completed": "Blades keeping sharp? Good.",
		},
	},
	"forge_frost": {
		"giver_name": "Village Blacksmith",
		"name": "Cold Iron",
		"line": "side", "requires": ["forge_whetstone"],
		"objective": {"type": "gather", "item_id": "frost_shard", "amount": 2},
		"reward": {"xp": 80, "gold": 40, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "Now that the edge is keen, I want to try something. The Frostpeak creatures leave shards of ice that never melt - bring me 2 Frost Shard and I'll see if they take a temper.",
			"in_progress": "Still after those Frost Shards - the ridge monsters drop them.",
			"ready": "Look at that - it holds. Cold iron. Take this, and thank you.",
			"completed": "Cold iron. Never thought I'd see it.",
		},
	},
	"thornback_warden": {
		"giver_name": "Forest Druid",
		"name": "The Thornback",
		"line": "side", "requires": ["cross_verdantwood"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["verdantwood_maze_guardian_1"], "label": "Thornback Warden asleep", "goal": "Find the walled glade in Verdantwood's maze and put the Thornback Warden to sleep."},
		"reward": {"xp": 120, "gold": 30},
		"dialogue": {
			"offer": "There's a glade in the forest maze walled off by something with a shell of thorns - the Thornback Warden. It keeps the wood's paths from healing. Put it to sleep for me?",
			"in_progress": "The Thornback still holds its glade in the maze.",
			"ready": "The glade's open again? The paths will mend now. Thank you.",
			"completed": "The maze breathes easier without the Thornback.",
		},
	},
}

# The story line's chapters, in order. Chapter 1 is the village, then one
# per biome (playable in any order - the fords are independent), then the
# finale. The Journal groups story quests under these.
const CHAPTERS := [
	{"id": "village", "title": "Chapter 1: The Valley", "blurb": "A new face in a small settlement."},
	{"id": "frostpeak", "title": "Chapter 2: Frostpeak Ridge", "blurb": "The ice caves beyond the northern ford."},
	{"id": "verdantwood", "title": "Chapter 3: Verdantwood Forest", "blurb": "The rot at the heart of the eastern wood."},
	{"id": "badlands", "title": "Chapter 4: Emberfall Badlands", "blurb": "Fires in the south."},
	{"id": "gloomfen", "title": "Chapter 5: Gloomfen Marsh", "blurb": "The mouth at the end of the boardwalk."},
	{"id": "finale", "title": "Chapter 6: The Ancient Warden", "blurb": "Two Guardians, two crystals, and what sleeps beneath the valley."},
]

# --- lines, chapters and chains ---
# Every quest has a "line" (story / side); story quests a "chapter"; any
# quest may "require" others - it is only offered once they are completed.
# Chains are derived from those links: prev = the first same-line
# requirement, next = the same-line quests that require this one.

func line_of(quest_id: String) -> String:
	return QUEST_DEFS[quest_id].get("line", "side")

func chapter_of(quest_id: String) -> String:
	return QUEST_DEFS[quest_id].get("chapter", "")

func requires_of(quest_id: String) -> Array:
	return QUEST_DEFS[quest_id].get("requires", [])

# Offerable: not yet handed out and every requirement completed.
func is_available(quest_id: String) -> bool:
	if quest_state.has(quest_id):
		return false
	for req in requires_of(quest_id):
		if quest_state.get(req, "") != "completed":
			return false
	return true

# Two quests are chain-linked when one requires the other on the same line
# and, for story quests, in the same chapter (the finale requires all four
# hunts but is its own chapter, not the tail of Frostpeak's chain).
func _linked(a: String, b: String) -> bool:
	if line_of(a) != line_of(b):
		return false
	return line_of(a) != "story" or chapter_of(a) == chapter_of(b)

func prev_of(quest_id: String) -> String:
	for req in requires_of(quest_id):
		if _linked(req, quest_id):
			return req
	return ""

func next_of(quest_id: String) -> Array:
	var out: Array = []
	for other in QUEST_DEFS.keys():
		if other != quest_id and _linked(other, quest_id) and requires_of(other).has(quest_id):
			out.append(other)
	return out

# The quest's chain from its first step to its last (following the first
# "next" at each step) - a single-action quest is a chain of one.
func chain_of(quest_id: String) -> Array:
	var first: String = quest_id
	var guard := 0
	while prev_of(first) != "" and guard < 32:
		first = prev_of(first)
		guard += 1
	var chain: Array = [first]
	var cur: String = first
	guard = 0
	while guard < 32:
		var nxt: Array = next_of(cur)
		if nxt.is_empty():
			break
		cur = nxt[0]
		chain.append(cur)
		guard += 1
	return chain

# [step index (1-based), chain length].
func step_of(quest_id: String) -> Array:
	var chain: Array = chain_of(quest_id)
	return [chain.find(quest_id) + 1, chain.size()]

func chapter_quests(chapter_id: String) -> Array:
	var out: Array = []
	for id in QUEST_DEFS.keys():
		if chapter_of(id) == chapter_id:
			out.append(id)
	return out

# "complete" when every quest of the chapter is done, "in_progress" once any
# of them has been handed out, else "not_started".
func chapter_state(chapter_id: String) -> String:
	var ids: Array = chapter_quests(chapter_id)
	var all_done := not ids.is_empty()
	var any_state := false
	for id in ids:
		var st: String = quest_state.get(id, "")
		if st != "completed":
			all_done = false
		if st != "":
			any_state = true
	if all_done:
		return "complete"
	return "in_progress" if any_state else "not_started"

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
	if objective.type == "defeat_bosses":
		for boss_id in objective.boss_ids:
			if not GameState.boss_defeated.get(boss_id, false):
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
	if objective.type == "defeat_bosses":
		var asleep := 0
		for boss_id in objective.boss_ids:
			if GameState.boss_defeated.get(boss_id, false):
				asleep += 1
		return "%d/%d %s" % [asleep, objective.boss_ids.size(), objective.get("label", "bosses asleep")]
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
		get_node("/root/DialogueUI").show_dialogue(QUEST_DEFS[quest_id].giver_name, "You've already met everyone? Splendid. The village gates are open - the valley's yours to explore.")
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
	# Quest XP pays well above a fight's worth (user: "quest returns tend to
	# be much larger than combat xp") - shown as a HUD popup; a level-up
	# announces itself through Character.levelled_up as usual.
	if reward.get("xp", 0) > 0:
		HUD._spawn_text_popup("+%d XP" % reward.xp, Color(1.0, 0.85, 0.3))
		Character.gain_xp(reward.xp)
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
