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
	# The fence/gates tutorial and the GATEWAY quest (2026-09-07): every
	# other quest requires it, so no other "!" shows until it is turned in.
	# Offered by the Village Elder, who stands OUTSIDE his house on the
	# village square; meet the four villagers, then come BACK to the Elder -
	# his "?" is how the player learns the turn-in marker - and the gates
	# open on the turn-in (see _complete_quest()).
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
			"ready": "You've met everyone worth meeting? Splendid. Then let me have those gates opened for you.",
			"completed": "The gates are open - the valley's yours to explore. Mind the river fords, though.",
		},
	},
	"cross_frostpeak": {
		"giver_name": "Frostpeak Ranger",
		"name": "Reinforcing the Ford",
		"line": "story", "chapter": "frostpeak", "requires": ["hunt_dungeon"],
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
		"line": "story", "chapter": "verdantwood", "requires": ["hunt_frostpeak"],
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
		"line": "story", "chapter": "badlands", "requires": ["hunt_verdantwood"],
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
		"line": "story", "chapter": "gloomfen", "requires": ["hunt_badlands"],
		"objective": {"type": "gather", "item_id": "wood", "amount": 12},
		"reward": {"xp": 210, "gold": 35, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "The old boardwalk into Gloomfen rotted through long ago - bring me 12 Wood and I'll lay a new one.",
			"in_progress": "Still need more wood for the boardwalk - what have you got?",
			"ready": "That'll do it. Should hold you over the worst of the mire now.",
			"completed": "The boardwalk's holding, thanks to you.",
		},
	},
	# --- Chapter 1's teaching arc (2026-09-08, the user's storyline pass):
	# the Ancient Barrow is the FIRST dungeon - a few encounters, the fog, the
	# chests and a boss the full leather set is needed for (the upgrade
	# lesson) - then the old dungeon and its Bone Lord, whose crystal is the
	# Elder's reason to open the fords. The Elder gives all of it; the Trader
	# is a shop again. The dungeon gate stays barred until The Bone Lord is
	# handed out (portal.gd lock_quest), the castle's until The Royal Wraith.
	# The bank lesson (user, 2026-09-08): before the barrow the Elder has
	# Oliver put the wood errand's gold in the house chest - what is banked
	# is safe from a nap and spendable everywhere. Objective type "bank".
	"bank_gold": {
		"giver_name": "Village Elder",
		"name": "A Safe Place",
		"line": "story", "chapter": "village", "requires": ["gather_wood"],
		"objective": {"type": "bank", "item_id": "gold", "amount": 20, "goal": "Put at least 20 gold in the chest in your house, then come back to the Elder."},
		"reward": {"xp": 30},
		"dialogue": {
			"offer": "Before you go anywhere dangerous, a word about your gold. There's a chest in your house, by the bed - put your coin and your spare goods in it. Whatever's in that chest is safe: a nap can't lose it, and the Trader, the Blacksmith and I can all draw on it wherever you are. Go and bank the 20 gold I gave you, then come back.",
			"in_progress": "The chest is in your house, by the bed. Put at least 20 gold in it - 'Deposit all' does it in one tap - and come back to me.",
			"ready": "Banked? Good. That's a habit that will save you more than once. Now - about the barrow.",
			"completed": "Keep banking what you bring home.",
		},
	},
	"open_ancient_barrow": {
		"giver_name": "Village Elder",
		"name": "What Lies Beneath",
		"line": "story", "chapter": "village", "requires": ["bank_gold"],
		"objective": {"type": "gather", "item_id": "stone", "amount": 6, "goal": "Bring the Elder 6 Stone to shore up the barrow's collapsed entrance. Buy the leather set from the Trader while you gather."},
		"reward": {"xp": 90, "gold": 40, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "There's an old barrow at the edge of the valley - sealed for as long as anyone remembers. Bring me 6 Stone to shore up its collapsed entrance and I'll show you where it lies. And traveler: the Trader sells leather gear. Buy the whole set before you go down. Every piece.",
			"in_progress": "Still need 6 Stone for the barrow's entrance. And get that leather from the Trader - armour, cap, greaves, boots, gloves. All of it.",
			"ready": "That's enough stone. Let me show you where it opens up.",
			"completed": "The old barrow's open. Mind yourself down there.",
		},
	},
	"hunt_barrow": {
		"giver_name": "Village Elder",
		"name": "The Barrow Warden",
		"line": "story", "chapter": "village", "requires": ["open_ancient_barrow"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["golden_plains_boss"], "label": "Barrow Warden asleep", "goal": "Go down into the Ancient Barrow, learn its ways, and put the Barrow Warden to sleep. Wear the whole leather set."},
		"reward": {"xp": 100, "gold": 40, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "The barrow's open. Something stirs at the bottom of it - the Barrow Warden, the old stories call it. Go down, find your feet, and put it to sleep. Full leather, mind: armour, cap, greaves, boots and gloves. The Trader has them all.",
			"in_progress": "The Barrow Warden still stirs. If it keeps throwing you out, you're missing a piece of leather - the Trader stocks the lot.",
			"ready": "The Warden sleeps? Then you've the makings of an adventurer. Rest up - I've something bigger for you.",
			"completed": "The barrow's quiet now.",
		},
	},
	"hunt_dungeon": {
		"giver_name": "Village Elder",
		"name": "The Bone Lord",
		"line": "story", "chapter": "village", "requires": ["hunt_barrow"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["dungeon_boss"], "label": "Bone Lord asleep", "goal": "The old dungeon's gate is open. Put the Bone Lord to sleep and bring back the Magic Crystal it guards."},
		"reward": {"xp": 150, "gold": 50, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "There's an old dungeon under the north road, and I've had its gate unbarred for you. A Bone Lord walks its halls, and it guards a Magic Crystal - the first of two the altar needs. Put it to sleep and bring the crystal home.",
			"in_progress": "The Bone Lord still walks the dungeon. There's more bone in it than the Warden had - keep potions on you.",
			"ready": "The crystal! Keep it safe. With that in hand I'll ask the Ranger to open the northern ford.",
			"completed": "The Bone Lord sleeps. The fords are next.",
		},
	},
	# --- Story chapters (quest lines revamp, 2026-09-07). The Village Elder
	# is the story voice: after each ford opens he sends Oliver after that
	# biome's boss, and once all four sleep, after the two Guardians and the
	# Ancient Warden. Since the storyline pass (2026-09-08) the chapters run
	# in order: each ford quest requires the previous chapter's hunt.
	# --- Joining events (2026-09-07, user: "we would need a joining event").
	# The companions follow the story: once a ford opens, the one who comes
	# along for that biome waits ON the crossing (blocking it) with a "!";
	# accepting completes the quest on the spot (objective type "join") and
	# they walk with Oliver (Combat.roster_for_zone reads these states).
	# Luigi for Frostpeak; Eden alone for Verdantwood (the Bramblewood hates
	# dogs - Luigi goes home); both together from the Badlands on (the pair
	# wait at the southern ford, and their event also settles the other two).
	# Each is the middle step of its chapter's chain: ford -> join -> hunt
	# (the hunt requires the join; Gloomfen's needs only its ford - its
	# companions are the pair from the Badlands). See overworld.gd
	# _place_companions() for where they stand.
	"join_luigi": {
		"giver_name": "Luigi the Fearless", "giver_is_name": true,
		"name": "A Fearless Friend",
		"line": "story", "chapter": "frostpeak", "requires": ["cross_frostpeak"],
		"objective": {"type": "join", "companion": "luigi", "goal": "Luigi waits on the northern ford. Ask him along into Frostpeak."},
		"reward": {"xp": 30},
		"dialogue": {
			"offer": "Woof - there you are, pup. The ford's open, and Frostpeak is no place to go alone. The wolves up there bite - but I bite harder. Say the word and I'll come along.",
			"in_progress": "Say the word, pup.",
			"ready": "Luigi the Fearless walks at your side! Call him in a fight and he'll bite first and take the blows after.",
			"completed": "Frostpeak, pup. Stay behind me and mind the ice.",
		},
	},
	# The biome hunts of chapters 2 and 3 are handed out IN THE FIELD (user,
	# 2026-09-08: the player is already past the ford and would miss an offer
	# back in the village): the Ranger / the Druid give them, standing just
	# past the crossing once it opens (overworld._place_guides), and the
	# Elder takes the turn-in - giver_id / turn_in_id tell npc.gd who offers
	# and who shows the "?"; "send_on" is the giver's line once the boss sleeps.
	"hunt_frostpeak": {
		"giver_name": "Frostpeak Ranger", "giver_id": "frostpeak_ranger",
		"turn_in_name": "Village Elder", "turn_in_id": "village_elder",
		"name": "The Glacial Revenant",
		"line": "story", "chapter": "frostpeak", "requires": ["join_luigi"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["frostpeak_boss"], "label": "Glacial Revenant asleep", "goal": "Find the ice caves up the ridge and put the Glacial Revenant to sleep, then tell the Village Elder."},
		"reward": {"xp": 180, "gold": 50, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "The ford holds and you've a hound at your side - good. Something haunts the ice caves up the ridge; the old hands call it the Glacial Revenant. Put it to sleep, then tell the Elder in the village - he'll want to hear it from you.",
			"in_progress": "The Revenant still walks the ice caves. Take a Frost set if you can forge one - the cold up there bites.",
			"send_on": "It sleeps? Then go and tell the Elder - he keeps the count of these things.",
			"ready": "The Revenant sleeps? Then Frostpeak breathes easy tonight. Well done, traveler.",
			"completed": "Frostpeak's quiet now, thanks to you.",
		},
	},
	"join_eden": {
		"giver_name": "Eden", "giver_is_name": true,
		"name": "A Small Loud Guide",
		"line": "story", "chapter": "verdantwood", "requires": ["cross_verdantwood"],
		"objective": {"type": "join", "companion": "eden", "goal": "Eden waits on the eastern ford. Ask her along into Verdantwood."},
		"reward": {"xp": 30},
		"dialogue": {
			"offer": "Verdantwood, hm? The Bramblewood hates dogs - it would tangle poor Luigi in a heartbeat. He goes home. I come with you. I know every root in that wood, and I can be very, very loud.",
			"in_progress": "Well? Do you want a guide or not?",
			"ready": "Eden flits to your shoulder! Call her in a fight and she'll scream first and take the blows after.",
			"completed": "Luigi's sulking on the square. He'll live. Into the trees!",
		},
	},
	"hunt_verdantwood": {
		"giver_name": "Forest Druid", "giver_id": "forest_druid",
		"turn_in_name": "Village Elder", "turn_in_id": "village_elder",
		"name": "Elder Bramblewood",
		"line": "story", "chapter": "verdantwood", "requires": ["join_eden"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["verdantwood_boss"], "label": "Elder Bramblewood asleep", "goal": "Go deep into Verdantwood's tangled interior and put Elder Bramblewood to sleep, then tell the Village Elder."},
		"reward": {"xp": 220, "gold": 60, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "The crossing's clear and Eden's with you. Something old and thorned sits at the heart of the wood - Elder Bramblewood. Put it to sleep, then tell the Elder in the village; he'll want to know the forest breathes again.",
			"in_progress": "Bramblewood still chokes the forest's heart. Ironwood armour turns thorns, if the Blacksmith can make you some.",
			"send_on": "The bramble sleeps? Go and tell the Elder - it's his village that's been holding its breath.",
			"ready": "The old bramble sleeps? Then Verdantwood can grow green again. You have my thanks.",
			"completed": "The forest's healing, thanks to you.",
		},
	},
	"join_pair": {
		"giver_name": "Luigi the Fearless", "giver_is_name": true,
		"name": "The Fearless Pair",
		"line": "story", "chapter": "badlands", "requires": ["cross_badlands"],
		"objective": {"type": "join", "companion": "both", "goal": "Luigi and Eden wait on the southern ford. Ask them both along."},
		"reward": {"xp": 40},
		"dialogue": {
			"offer": "Woof! We've talked it over, Eden and I. Emberfall and the fen are too much for one of us - so you get both. No arguments. Except from cats.",
			"in_progress": "Both of us, pup. Say yes.",
			"ready": "Luigi and Eden both walk with you now! Call either in a fight - and the other waits their turn.",
			"completed": "Both of us, pup. Nothing gets past.",
		},
	},
	"hunt_badlands": {
		"giver_name": "Badlands Prospector", "giver_id": "badlands_prospector",
		"turn_in_name": "Village Elder", "turn_in_id": "village_elder",
		"name": "Cinderjaw",
		"line": "story", "chapter": "badlands", "requires": ["join_pair"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["badlands_boss"], "label": "Cinderjaw asleep", "goal": "Brave the Emberfall caldera and put Cinderjaw to sleep, then tell the Village Elder."},
		"reward": {"xp": 260, "gold": 70, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "Crossing holds, and you've the pair of them with you - good. Something's been setting the badlands alight from the caldera; I call it Cinderjaw. Put it to sleep before the fires spread, then tell the Elder - he'll want the news.",
			"in_progress": "Cinderjaw still burns in the caldera. Ember plate shrugs off the heat - worth the forge time.",
			"send_on": "It sleeps? Then the fires will die down. Go and tell the Elder.",
			"ready": "Cinderjaw sleeps? The fires will die down now. Bravely done.",
			"completed": "The badlands are cooling, thanks to you.",
		},
	},
	"hunt_gloomfen": {
		"giver_name": "Marsh Guide", "giver_id": "marsh_guide",
		"turn_in_name": "Village Elder", "turn_in_id": "village_elder",
		"name": "The Bogmaw",
		"line": "story", "chapter": "gloomfen", "requires": ["cross_gloomfen"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["gloomfen_boss"], "label": "The Bogmaw asleep", "goal": "Follow the boardwalk into Gloomfen's depths and put the Bogmaw to sleep, then tell the Village Elder."},
		"reward": {"xp": 300, "gold": 80, "item_id": "healing_potion", "item_amount": 1},
		"dialogue": {
			"offer": "The boardwalk holds. The marsh has a mouth at the end of it - I call it the Bogmaw, and it's the worst thing in this valley. Put it to sleep, then tell the Elder; he's been waiting on that news longer than any of us.",
			"in_progress": "The Bogmaw still lurks in the mire. Bog-iron is the only armour that keeps its teeth out.",
			"send_on": "It sleeps? Then the marsh is quiet at last. Go and tell the Elder.",
			"ready": "The Bogmaw sleeps? Then the last of the four is done. The valley owes you, traveler.",
			"completed": "Gloomfen's still now, thanks to you.",
		},
	},
	"hunt_castle": {
		"giver_name": "Village Elder",
		"name": "The Royal Wraith",
		"line": "story", "chapter": "finale", "requires": ["hunt_gloomfen"],
		"objective": {"type": "defeat_bosses", "boss_ids": ["castle_boss"], "label": "Royal Wraith asleep", "goal": "The castle gate is unchained. Put the Royal Wraith to sleep and take the second Magic Crystal."},
		"reward": {"xp": 300, "gold": 100},
		"dialogue": {
			"offer": "All four biomes sleep, but the valley's oldest trouble is still below us. One crystal is in your pack; the other is in the castle, with the Royal Wraith. I've had the castle gate unchained. Take both your companions.",
			"in_progress": "The Royal Wraith holds the castle - and the second crystal.",
			"ready": "Both crystals! To the altar on the square, traveler - it will show us where the Warden hides.",
			"completed": "The Wraith sleeps.",
		},
	},
	"two_guardians": {
		"giver_name": "Village Elder",
		"name": "The Altar",
		"line": "story", "chapter": "finale", "requires": ["hunt_castle"],
		"objective": {"type": "flag", "flag": "final_boss_revealed", "label": "lair revealed", "goal": "Set both Magic Crystals on the altar on the village square."},
		"reward": {"xp": 200, "gold": 100},
		"dialogue": {
			"offer": "The altar on the square has waited an age for those two crystals. Set them on it and watch.",
			"in_progress": "The altar waits for the two crystals. Press E at it with both in your pack.",
			"ready": "The altar has shown you the lair. Steel yourself, traveler.",
			"completed": "The lair is known.",
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
		# Waits for the Frostpeak chapter to open (the Bone Lord turned in):
		# its follow-up wants frost shards (user, 2026-09-08).
		"line": "side", "requires": ["hunt_dungeon"],
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
	{"id": "village", "title": "Chapter 1: The Valley", "blurb": "A new face, a barrow to learn in, and a crystal under the north road."},
	{"id": "frostpeak", "title": "Chapter 2: Frostpeak Ridge", "blurb": "The ice caves beyond the northern ford."},
	{"id": "verdantwood", "title": "Chapter 3: Verdantwood Forest", "blurb": "The rot at the heart of the eastern wood."},
	{"id": "badlands", "title": "Chapter 4: Emberfall Badlands", "blurb": "Fires in the south."},
	{"id": "gloomfen", "title": "Chapter 5: Gloomfen Marsh", "blurb": "The mouth at the end of the boardwalk."},
	{"id": "finale", "title": "Chapter 6: The Ancient Warden", "blurb": "The castle's crystal, the altar, and what sleeps beneath the valley."},
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
		return Inventory.available(objective.item_id) >= objective.amount # carried + banked
	if objective.type == "gather_multi":
		for entry in objective.items:
			if Inventory.available(entry.item_id) < entry.amount:
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
	if objective.type == "join":
		return true # settled the moment it is accepted
	if objective.type == "flag":
		return bool(GameState.world_progress.get(objective.flag, false))
	if objective.type == "bank":
		return Storage.get_count(Inventory.BANK_CHEST, objective.item_id) >= objective.amount
	return false

# e.g. "3/5 [icon] Wood" or "1/2 Villagers" - used by the offer-in-progress
# line (gather quests) and the Journal (every quest). BBCode (the gather
# case embeds an inline item icon) - every consumer (DialogueUI's
# text_label, quest_panel.gd's Journal rows, quest_tracker.gd's status
# label) is a bbcode_enabled RichTextLabel.
func objective_progress_text(quest_id: String) -> String:
	var objective: Dictionary = QUEST_DEFS[quest_id].objective
	if objective.type == "gather":
		var have: int = min(Inventory.available(objective.item_id), objective.amount)
		return "%d/%d %s" % [have, objective.amount, Items.get_item_name_bbcode(objective.item_id)]
	if objective.type == "gather_multi":
		var parts: Array[String] = []
		for entry in objective.items:
			var have_entry: int = min(Inventory.available(entry.item_id), entry.amount)
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
	if objective.type == "join":
		return "Ready to join"
	if objective.type == "flag":
		return "%d/1 %s" % [1 if bool(GameState.world_progress.get(objective.flag, false)) else 0, objective.get("label", "done")]
	if objective.type == "bank":
		return "%d/%d %s banked" % [min(Storage.get_count(Inventory.BANK_CHEST, objective.item_id), objective.amount), objective.amount, Items.get_item_name(objective.item_id)]
	return ""

# Called by npc.gd when the player interacts with a quest-giving NPC. Picks
# the right dialogue line + Accept/Turn In choices for the quest's current
# state and shows it via DialogueUI - same one-frame-guard box every other
# NPC already uses, just sometimes with buttons attached.
# `npc_id` = who is talking: a quest with a separate turn-in NPC offers at
# its giver, sends the player on ("send_on") once the objective is met, and
# only the turn-in NPC shows the Turn In choice.
func talk_to_giver(quest_id: String, npc_id: String = "") -> void:
	var def: Dictionary = QUEST_DEFS[quest_id]
	var state: String = quest_state.get(quest_id, "")
	var dialogue_ui: Node = get_node("/root/DialogueUI")
	var speaker: String = def.turn_in_name if (def.has("turn_in_name") and npc_id != "" and npc_id == def.get("turn_in_id", "")) else def.giver_name

	if state == "completed":
		dialogue_ui.show_dialogue(speaker, def.dialogue.completed)
	elif state == "accepted":
		if objective_met(quest_id) and takes_turn_in(quest_id, npc_id):
			dialogue_ui.show_dialogue(speaker, def.dialogue.ready, [
				{"label": "Turn In", "callback": _complete_quest.bind(quest_id)},
				{"label": "Not yet", "callback": Callable()},
			])
		elif objective_met(quest_id):
			dialogue_ui.show_dialogue(speaker, def.dialogue.get("send_on", def.dialogue.in_progress))
		else:
			dialogue_ui.show_dialogue(speaker, "%s (%s)" % [def.dialogue.in_progress, objective_progress_text(quest_id)])
	else:
		dialogue_ui.show_dialogue(def.giver_name, def.dialogue.offer, [
			{"label": "Accept", "callback": _accept_quest.bind(quest_id)},
			{"label": "Not now", "callback": Callable()},
		])

func _accept_quest(quest_id: String) -> void:
	quest_state[quest_id] = "accepted"
	var def: Dictionary = QUEST_DEFS[quest_id]
	# A joining event settles on the spot: the companion walks with Oliver
	# and says so (the "ready" line stands in for a turn-in).
	if def.objective.type == "join":
		_complete_quest(quest_id)
		get_node("/root/DialogueUI").call_deferred("show_dialogue", def.giver_name, def.dialogue.ready)
		return
	# Auto-track so it's immediately visible on the overlay without a trip
	# to the Journal - silently skipped if the tracker is already full,
	# same as a manual Track click at the cap.
	if tracked_quests.size() < MAX_TRACKED:
		tracked_quests.append(quest_id)
	changed.emit()

# "the Village Elder", but "Luigi the Fearless" / "Eden": a giver that is a
# proper name (giver_is_name) takes no article in the Journal.
func giver_label(quest_id: String) -> String:
	var def: Dictionary = QUEST_DEFS[quest_id]
	var giver: String = def.get("giver_name", "villagers")
	return giver if def.get("giver_is_name", false) else "the " + giver

# Where a quest is turned in - the giver unless it names someone else.
func turn_in_label(quest_id: String) -> String:
	var def: Dictionary = QUEST_DEFS[quest_id]
	if def.has("turn_in_name"):
		return def.turn_in_name if def.get("turn_in_is_name", false) else "the " + def.turn_in_name
	return giver_label(quest_id)

# The NPC that offers a quest ("" = whoever carries it in their chain) and
# the one that takes its turn-in (the giver unless turn_in_id says otherwise).
func giver_id_of(quest_id: String) -> String:
	return QUEST_DEFS[quest_id].get("giver_id", "")

func turn_in_id_of(quest_id: String) -> String:
	return QUEST_DEFS[quest_id].get("turn_in_id", giver_id_of(quest_id))

func offers(quest_id: String, npc_id: String) -> bool:
	var g: String = giver_id_of(quest_id)
	return g == "" or npc_id == "" or g == npc_id

func takes_turn_in(quest_id: String, npc_id: String) -> bool:
	var t: String = turn_in_id_of(quest_id)
	return t == "" or npc_id == "" or t == npc_id

# The joining event a companion (or the pair) needs before it comes along.
func companion_joined(event_id: String) -> bool:
	return quest_state.get(event_id, "") == "completed" or quest_state.get("join_pair", "") == "completed"

func _mark_completed(quest_id: String) -> void:
	quest_state[quest_id] = "completed"
	tracked_quests.erase(quest_id)

func _complete_quest(quest_id: String) -> void:
	Audio.play_sfx("quest")
	var def: Dictionary = QUEST_DEFS[quest_id]
	var objective: Dictionary = def.objective
	if objective.has("items"):
		for entry in objective.items:
			Inventory.consume(entry.item_id, entry.amount)
	elif objective.has("item_id"):
		Inventory.consume(objective.item_id, objective.amount) # carried first, then the chest
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
	elif quest_id == "meet_villagers":
		_open_village_gates() # the tutorial's real reward, paid on the turn-in
	elif quest_id == "join_pair":
		# Both walk with Oliver from here on - the single events are moot.
		for event in ["join_luigi", "join_eden"]:
			if quest_state.get(event, "") != "completed":
				_mark_completed(event)
	changed.emit()

# Called by npc.gd the first time (and only the first time) the player
# interacts with a given NPC. Returns true if this specific interaction is
# the one that completes meet_villagers (and thus opens the gates) - the
# caller uses that to fold a "gates opened" line into the same intro
# message instead of trying to show a second dialogue on top of the first.
func mark_npc_met(npc_id: String) -> bool:
	npcs_met[npc_id] = true
	changed.emit()
	# The tutorial is turned in at the Elder (his "?"), never completed here;
	# kept returning false so npc.gd's intro fold-in stays inert.
	return false

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
