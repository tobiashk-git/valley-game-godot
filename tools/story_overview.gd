extends SceneTree
# Story overview generator. Run via:
#   godot --headless --script res://tools/story_overview.gd
# Writes res://story_overview.md from the live data: the story chapters and
# their chains (giver, where, gate, goal, reward, what completing it unlocks),
# the side quests, every place and boss with how it is reached, and who
# comes along where. Refresh it after any quest / roster / boss change - it
# is the reviewable "storyboard" (user, 2026-09-08: a structured list that
# can be refreshed, to walk the storyline in a controlled, gated order).

# Where a giver stands, in the player's terms.
const WHERE := {
	"Village Elder": "village square, outside his house",
	"Village Trader": "village, south-west house (shop)",
	"Village Blacksmith": "village, south-east house (workbench)",
	"Frostpeak Ranger": "camp by the northern ford; just past the crossing for good once it opens (hunt turned in at the Elder; the zone's side quests from there)",
	"Forest Druid": "glade by the eastern ford; just past the crossing for good once it opens (hunt turned in at the Elder; the zone's side quests from there)",
	"Badlands Prospector": "camp by the southern ford; just past the crossing for good once it opens (hunt turned in at the Elder; the zone's side quests from there)",
	"Marsh Guide": "camp by the western ford; just past the crossing for good once it opens (hunt turned in at the Elder; the zone's side quests from there)",
	"Luigi the Fearless": "village square; on a ford for his events",
	"Eden": "village square; on the eastern ford for her event",
}
# What completing a quest changes in the world (quests.gd _complete_quest and friends).
const UNLOCKS := {
	"meet_villagers": "the village gates open - the valley (Golden Plains); the dungeon and castle gates stay barred",
	"gather_wood": "nothing in the world - the Elder's first errand (potion reward); leads to the bank lesson",
	"bank_gold": "nothing in the world - the bank lesson (the house chest is safe and spendable everywhere); leads to the barrow",
	"hunt_barrow": "chapter 1's dungeon lesson done; the Elder unbars the old dungeon next",
	"hunt_dungeon": "Magic Crystal 1 in the pack; the northern ford quest becomes available",
	"hunt_castle": "Magic Crystal 2 in the pack; the altar step becomes available",
	"cross_frostpeak": "the northern ford opens (a bridge appears): Frostpeak Ridge and its ice caves; Luigi moves onto the ford",
	"join_luigi": "Luigi walks with Oliver - Bite / Guard in Frostpeak fights",
	"hunt_frostpeak": "chapter 2 done; the finale needs it",
	"cross_verdantwood": "the eastern ford opens: Verdantwood Forest, its maze and grove; Eden moves onto the ford (Luigi beside her)",
	"join_eden": "Eden walks with Oliver - Scream / Shimmer in Verdantwood; Luigi goes home",
	"hunt_verdantwood": "chapter 3 done; the finale needs it",
	"cross_badlands": "the southern ford opens: Emberfall Badlands and the caldera; both companions move onto the ford",
	"join_pair": "both walk with Oliver from here on (Badlands, Gloomfen, the castle, the finale); settles the single events too",
	"hunt_badlands": "chapter 4 done; the finale needs it",
	"cross_gloomfen": "the western ford opens: Gloomfen Marsh and the sunken temple",
	"hunt_gloomfen": "chapter 5 done; the finale needs it",
	"two_guardians": "both crystals set on the altar: the Ancient Warden's lair is revealed at the valley's edge",
	"ancient_warden": "the Warden's crystal at the altar ENDS THE GAME: a swirl from the altar, then the completion screen (Oliver with Luigi and Eden, the bosses put to sleep, Play again / Quit). World 2 is a future version.",
	"open_ancient_barrow": "the Ancient Barrow entrance appears in the Golden Plains - chapter 1's teaching dungeon",
	"forge_whetstone": "nothing in the world (gold + XP); leads to Cold Iron",
	"forge_frost": "nothing in the world (potion + gold)",
	"thornback_warden": "the Thornback's glade in the Verdantwood maze is cleared",
}
const WHO := {
	"village": "Oliver alone", "frostpeak": "Luigi (after A Fearless Friend)", "verdantwood": "Eden (after A Small Loud Guide)",
	"badlands": "Luigi and Eden (after The Fearless Pair)", "gloomfen": "Luigi and Eden (the pair's event is on the southern ford)", "finale": "Luigi and Eden",
}
# Places: how each is reached, what waits there.
const PLACES := [
	["Village", "start", "Elder, Trader (shop), Blacksmith (workbench), Luigi, Eden, Oliver's house (bank chest, bed), the altar"],
	["Golden Plains (the valley)", "Meet the Village turned in (gates)", "wild monsters, trees and rocks, the Ranger / Druid / Prospector / Guide camps by the fords"],
	["Old dungeon (Bone Lord)", "barred until The Bone Lord is handed out (chapter 1); E on the gate says the Elder might help", "maze with two treasure chests; the Bone Lord drops a Magic Crystal (Guardian 1) + the bone greatsword"],
	["Castle (Royal Wraith)", "barred until The Royal Wraith is handed out (chapter 6)", "maze; the Royal Wraith drops a Magic Crystal (Guardian 2) + royal plate"],
	["Ancient Barrow (Golden Plains interior)", "What Lies Beneath (Elder, 6 stone) - chapter 1", "a few dungeon-pool encounters, two chests; the Barrow Warden - needs the full leather set"],
	["Frostpeak Ridge + ice caves", "Reinforcing the Ford (Ranger: 8 wood, 8 stone)", "frost shards, wolves and bears; the Glacial Revenant - Frost set"],
	["Verdantwood Forest + grove + maze", "Clearing the Crossing (Druid: 12 wood)", "the Thornback Warden in the maze (side); Elder Bramblewood - Ironwood set"],
	["Emberfall Badlands + caldera", "Shoring Up the Crossing (Prospector: 12 stone)", "ember cores, geysers; Cinderjaw - Ember set"],
	["Gloomfen Marsh + sunken temple", "Laying the Boardwalk (Guide: 12 wood)", "bog iron; the Bogmaw - Bog-iron set"],
	["The Ancient Warden's lair", "two Magic Crystals at the altar (The Two Guardians)", "the Ancient Warden; its crystal opens the world-2 portal"],
]

func _out(lines: Array, s: String) -> void:
	lines.append(s)

func _goal(quests: Node, id: String) -> String:
	var o: Dictionary = quests.QUEST_DEFS[id].objective
	if o.has("goal"):
		return o.goal
	match o.type:
		"gather": return "Gather %d %s" % [o.amount, root.get_node("Items").get_item_name(o.item_id)]
		"gather_multi":
			var parts: Array = []
			for e in o.items:
				parts.append("%d %s" % [e.amount, root.get_node("Items").get_item_name(e.item_id)])
			return "Gather " + " and ".join(parts)
		"talk_to_npcs": return "Meet %d villagers" % o.npc_ids.size()
		"defeat_bosses": return "Put %s to sleep" % ", ".join(o.boss_ids)
		"join": return "Ask the companion along"
	return o.type

func _reward(quests: Node, id: String) -> String:
	var r: Dictionary = quests.QUEST_DEFS[id].get("reward", {})
	var parts: Array = []
	if r.get("xp", 0) > 0:
		parts.append("%d XP" % r.xp)
	if r.get("gold", 0) > 0:
		parts.append("%d gold" % r.gold)
	if r.has("item_id"):
		parts.append("%d %s" % [r.get("item_amount", 1), root.get_node("Items").get_item_name(r.item_id)])
	return ", ".join(parts) if not parts.is_empty() else "-"

func _initialize() -> void:
	var quests: Node = root.get_node("Quests")
	var enemies: Node = root.get_node("Enemies")
	var combat: Node = root.get_node("Combat")
	var lines: Array = []
	_out(lines, "# Story overview")
	_out(lines, "")
	_out(lines, "Generated by tools/story_overview.gd from the live quest, roster and boss data on %s. Refresh: `godot --headless --script res://tools/story_overview.gd`." % Time.get_date_string_from_system())
	_out(lines, "")
	_out(lines, "Reading it: a quest is OFFERED only when everything in its Gate is turned in (Quests.is_available). A chapter's quests form a chain (ford -> joining event -> hunt), and each ford quest requires the previous chapter's hunt, so the story runs in order. Settings > Story jump starts a test at any chapter.")
	_out(lines, "")

	_out(lines, "## Story line, chapter by chapter")
	for chapter in quests.CHAPTERS:
		_out(lines, "")
		_out(lines, "### %s" % chapter.title)
		_out(lines, "")
		_out(lines, "_%s_  -  companions: %s" % [chapter.blurb, WHO.get(chapter.id, "?")])
		_out(lines, "")
		_out(lines, "| # | Quest | Giver (where) | Gate (needs turned in) | Goal | Reward | Completing it unlocks |")
		_out(lines, "|---|---|---|---|---|---|---|")
		var ids: Array = quests.chapter_quests(chapter.id)
		# Chain order: by step index within the chapter's chains.
		ids.sort_custom(func(a: String, b: String) -> bool:
			var ca: Array = quests.chain_of(a)
			var cb: Array = quests.chain_of(b)
			if ca[0] != cb[0]:
				return ca[0] < cb[0]
			return quests.step_of(a)[0] < quests.step_of(b)[0])
		var n := 0
		for id in ids:
			n += 1
			var def: Dictionary = quests.QUEST_DEFS[id]
			var giver: String = def.get("giver_name", "-")
			var gate: String = ", ".join(quests.requires_of(id).map(func(r: String) -> String: return quests.QUEST_DEFS[r].name))
			_out(lines, "| %d | %s (`%s`) | %s (%s) | %s | %s | %s | %s |" % [n, def.name, id, giver, WHERE.get(giver, "?"), gate if gate != "" else "-", _goal(quests, id), _reward(quests, id), UNLOCKS.get(id, "-")])

	_out(lines, "")
	_out(lines, "## Side quests")
	_out(lines, "")
	_out(lines, "| Quest | Giver (where) | Gate | Goal | Reward | Unlocks |")
	_out(lines, "|---|---|---|---|---|---|")
	for id in quests.QUEST_DEFS.keys():
		if quests.line_of(id) != "side":
			continue
		var def: Dictionary = quests.QUEST_DEFS[id]
		var giver: String = def.get("giver_name", "-")
		var gate: String = ", ".join(quests.requires_of(id).map(func(r: String) -> String: return quests.QUEST_DEFS[r].name))
		_out(lines, "| %s (`%s`) | %s (%s) | %s | %s | %s | %s |" % [def.name, id, giver, WHERE.get(giver, "?"), gate if gate != "" else "-", _goal(quests, id), _reward(quests, id), UNLOCKS.get(id, "-")])

	_out(lines, "")
	_out(lines, "## Places and how they open")
	_out(lines, "")
	_out(lines, "| Place | Opens with | What waits there |")
	_out(lines, "|---|---|---|")
	for p in PLACES:
		_out(lines, "| %s | %s | %s |" % [p[0], p[1], p[2]])

	_out(lines, "")
	_out(lines, "## Bosses")
	_out(lines, "")
	_out(lines, "| Boss | Where | HP / attack / defence | Drops | Companions | Quest that wants it |")
	_out(lines, "|---|---|---|---|---|---|")
	var wanted: Dictionary = {}
	for id in quests.QUEST_DEFS.keys():
		var o: Dictionary = quests.QUEST_DEFS[id].objective
		if o.type == "defeat_bosses":
			for b in o.boss_ids:
				wanted[b] = quests.QUEST_DEFS[id].name
	var where_boss: Dictionary = {"dungeon_boss": "old dungeon", "castle_boss": "castle", "golden_plains_boss": "Ancient Barrow", "frostpeak_boss": "ice caves", "verdantwood_boss": "Verdantwood grove", "verdantwood_maze_guardian_1": "Verdantwood maze glade", "badlands_boss": "caldera", "gloomfen_boss": "sunken temple", "final_boss": "the Warden's lair"}
	for boss_id in enemies.BOSSES.keys():
		var b: Dictionary = enemies.BOSSES[boss_id]
		var drops: Array = b.get("drop_item_ids", []).map(func(d): return d.item if d is Dictionary else d)
		var roster: Array = combat.EVENT_ROSTER.get(combat.BOSS_EVENT.get(boss_id, ""), [])
		_out(lines, "| %s (`%s`) | %s | %d / %d / %d | %s | %s | %s |" % [b.name, boss_id, where_boss.get(boss_id, "?"), b.max_hp, b.attack, b.defense, ", ".join(drops) if not drops.is_empty() else "-", ", ".join(roster) if not roster.is_empty() else "nobody", wanted.get(boss_id, "- (not in any quest)")])

	_out(lines, "")
	_out(lines, "## Loose ends the data shows")
	_out(lines, "")
	for boss_id in enemies.BOSSES.keys():
		if not wanted.has(boss_id):
			_out(lines, "- %s (`%s`) is not the target of any quest." % [enemies.BOSSES[boss_id].name, boss_id])
	_out(lines, "- The old dungeon is chapter 1's last step and the castle the finale's first; both gates are barred until their hunt is handed out.")
	_out(lines, "- The chapters are chained (each ford needs the previous hunt); the Story jump in Settings is the way to test a later chapter.")
	_out(lines, "- world 2 (the portal after the Warden) is a future version; this version ends at the altar.")

	var f := FileAccess.open("res://story_overview.md", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("wrote res://story_overview.md (%d lines)" % lines.size())
	quit()
