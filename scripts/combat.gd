extends Node
# Autoload — Combat Phase 1-6: core battle loop, full command set, status
# effects, enemy groups, equipment-driven defense/status-resistance, and
# boss battles. Up to 3 enemies per fight (weighted 60/30/10 solo/duo/trio),
# click-a-portrait targeting once 2+ are alive (a lone survivor always
# auto-targets). Port of combat.js up through its "Phase 6". Random
# encounters trigger only while walking the dungeon interior (see
# dungeon.gd's tile-change hook); a boss fight is instead started
# deliberately by boss.gd when the player walks up and presses E.
#
# Status effects are contained to combat: player_status always resets to {}
# when a fight starts or ends. Enemies can only inflict status on the player
# this pass, so there is no enemy-side status state to track or tick.

signal changed
signal ended(victory: bool)
# The last enemy has dropped: the fight is won (the victory sting plays
# here). `ended(true)` follows once the player leaves the summary screen.
signal won
# Emitted after a lost fight, once the player has been sent home:
# {"cause": enemy name | "poison" | "confusion", "gold_lost": int}. The
# DefeatPanel autoload plays the death sequence from it.
signal defeated(info: Dictionary)
const FEATHER_DROP_CHANCE := 0.03
# Where a nap ends: the floor tile beside Oliver's bed in House.tscn (the
# bed stands at (2, 5)) - mirrors house.gd's NAP_SPAWN_TILE (not preloaded
# from there: pulling house.gd into a --script compile drags chest.gd in,
# where autoload names don't resolve).
const NAP_SPAWN_TILE := Vector2i(5, 5) # the middle of the room (the rug)
var last_defeat: Dictionary = {}

const ENCOUNTER_CHANCE := 0.12
const ENCOUNTER_COOLDOWN_STEPS := 4
const MAX_ENEMY_SLOTS := 3

var in_combat := false
var current_enemies: Array = [] # up to MAX_ENEMY_SLOTS entries: Dictionary | null
var player_defending := false
var battle_log: Array[String] = []
var active_submenu := "" # "" | "magic" | "item"
var player_status: Dictionary = {} # status_id -> {"turns_left": N}
var selecting_target := "" # "" | "attack" | "spell:<spell_id>"
var current_boss_id := "" # set for the duration of a boss fight, "" otherwise
var current_wild_monster_key := "" # set for the duration of a wild-monster fight (see start_wild_encounter()), "" otherwise
# A won fight holds on its summary ("Victory! ...") with in_combat still
# true until finish_combat() - the battle screen's Continue button or E -
# so the loot can be read (user feedback: it vanished at once). Under a
# verify script (`fast`) the fight ends immediately as it always did.
var awaiting_exit := false
var _nap_pending := false # awaiting_exit after a LOSS: Continue starts the nap
var fight_gold := 0
var fight_xp := 0
var fight_items: Array[String] = []

var _steps_since_encounter := ENCOUNTER_COOLDOWN_STEPS

# ---------------------------------------------------------------------------
# Companions (2026-09-07, the user's idea): Luigi and Eden are once-per-fight
# boosters. A bust button on the battle screen hands them the next round -
# their move replaces Oliver's action, then the enemies act as usual. Bite
# (Luigi) is the boss answer: one target, 1.5x Oliver's attack power through
# the normal armour maths. Scream (Eden) is the mob answer: every enemy takes
# 0.4x Oliver's attack power with no armour to soak it, and each regular
# survivor may be left reeling (it skips its next strike); a boss only
# flinches. The companion then STAYS on stage as a tank (user, after the
# phone test: "when a companion is active it draws the attacks from the
# enemies instead of Oliver"): it has a small pool of hit points -
# COMPANION_HP_FACTOR of Oliver's maximum, no armour - and every enemy blow
# lands on it until the pool is gone and it limps out (nobody dies). Calling
# the other companion sends the first back. One charge each per fight, both
# usable in the same fight, refilled every fight (nothing to save); unlocked
# once Meet the Village is turned in.
# WHO COMES ALONG follows the story (user, 2026-09-07): Oliver starts on his
# own (village, dungeon, plains, castle), Luigi joins for Frostpeak, Eden
# alone for Verdantwood, both from the Badlands on and for the finale - and
# only once that biome's JOINING EVENT is done (quests.gd join_luigi /
# join_eden / join_pair: they wait on the ford). A fight's roster comes from
# its zone (random and wild encounters carry one) or, for a boss, from the
# boss itself - see roster_for_zone / BOSS_EVENT. The strengths come from
# tools/sim_balance.gd --companions: a player opens every fight with both,
# and at 2x / 1x the next biome's boss fell to the previous set 65% of the
# time (the set rule wants <= 25%); the live numbers keep every band.
# PHASE 2 (2026-09-07): a bust opens a two-move menu. Luigi: Bite, or GUARD
# (he braces: blows on him are halved this round, and his pool is doubled
# on his first call or topped up after). Eden: Scream, or SHIMMER (nothing
# lands on anyone this round). CHARGES grow with level (charges_for_level:
# 1, 2 at level 5, 3 at level 10) and are the number of MOVES a companion
# gets per fight; its POOL is granted once per fight on its first call and
# carries over when it steps back for the other - and once knocked out it
# is out for the fight, charges or not (the pool is what limits the tank).
# ---------------------------------------------------------------------------
signal companion_called(id: String)
signal companion_struck(id: String)
signal companion_hit(id: String, damage: int) # an enemy blow landed on the tank
signal companion_left(id: String) # knocked back, or stepped aside for the other
const COMPANIONS := {
	"luigi": {"name": "Luigi the Fearless", "move": "Bite", "portrait": "res://assets/portraits/luigi.png", "sprite": "res://assets/npc_luigi.png"},
	"eden": {"name": "Eden", "move": "Scream", "portrait": "res://assets/portraits/eden.png", "sprite": "res://assets/npc_eden.png"},
}
const BITE_MULT := 1.5
const SCREAM_MULT := 0.4
const SCREAM_STUN_CHANCE := 0.5
const COMPANION_HP_FACTOR := 0.35 # the tank's pool as a share of Oliver's max HP
# Which joining event a boss fight falls under; EVENT_ROSTER says who that
# event brings.
const BOSS_EVENT := {
	"frostpeak_boss": "join_luigi",
	"verdantwood_boss": "join_eden", "verdantwood_maze_guardian_1": "join_eden",
	"castle_boss": "join_pair", "badlands_boss": "join_pair",
	"gloomfen_boss": "join_pair", "final_boss": "join_pair",
}
const EVENT_ROSTER := {"join_luigi": ["luigi"], "join_eden": ["eden"], "join_pair": ["luigi", "eden"]}
const COMPANION_MOVES := {
	"luigi": [
		{"id": "bite", "name": "Bite", "hint": "one hard bite"},
		{"id": "guard", "name": "Guard", "hint": "braces, blows halved"},
	],
	"eden": [
		{"id": "scream", "name": "Scream", "hint": "hits everyone, may stun"},
		{"id": "shimmer", "name": "Shimmer", "hint": "nothing lands this round"},
	],
}
const CHARGE_LEVELS := [5, 10] # one more charge per fight at each
const GUARD_POOL_MULT := 2.0 # Guard on the first call: twice the pool; later: topped up to it
var companion_pools: Dictionary = {} # id -> remaining pool this fight (granted on the first call)
var companion_max_pools: Dictionary = {} # id -> that pool's size
var companion_out: Dictionary = {} # id -> true once knocked out (out for the fight)
var guard_round := false # Luigi braced this round: blows on him halved
var shimmer_round := false # Eden shimmered this round: nothing lands on anyone

static func charges_for_level(level: int) -> int:
	var n := 1
	for at in CHARGE_LEVELS:
		if level >= at:
			n += 1
	return n
var companion_charges: Dictionary = {} # id -> charges left this fight; {} while locked
var fight_zone := -1 # the World.Zone the current fight is in (-1: village, dungeon, plains, castle)
var companion_active := "" # the companion on stage drawing the blows, "" for none
var companion_hp := 0
var companion_max_hp := 0

func companions_unlocked() -> bool:
	return Quests.quest_state.get("meet_villagers", "") == "completed"

func companion_ready(id: String) -> bool:
	return in_combat and companion_charges.get(id, 0) > 0 and not companion_out.get(id, false)

func open_companion_menu(id: String) -> void:
	if not in_combat or playing or awaiting_exit or alive_enemies().is_empty() or not companion_ready(id):
		return
	active_submenu = "companion:" + id
	changed.emit()

# The companions who come along in a zone (see the roster note above):
# the zone's event, if it has been done.
func roster_for_zone(zone: int) -> Array:
	if zone == World.Zone.FROSTPEAK:
		return roster_for_event("join_luigi")
	if zone == World.Zone.VERDANTWOOD:
		return roster_for_event("join_eden")
	if zone == World.Zone.BADLANDS or zone == World.Zone.GLOOMFEN:
		return roster_for_event("join_pair")
	return []

func roster_for_event(event_id: String) -> Array:
	if event_id == "" or not Quests.companion_joined(event_id):
		return []
	return EVENT_ROSTER[event_id]

func _refill_companions(roster: Array) -> void:
	companion_charges = {}
	companion_pools = {}
	companion_max_pools = {}
	companion_out = {}
	companion_active = ""
	companion_hp = 0
	companion_max_hp = 0
	guard_round = false
	shimmer_round = false
	if companions_unlocked():
		for id in roster:
			companion_charges[id] = charges_for_level(Character.stats.level)

# ---------------------------------------------------------------------------
# Beats - the fight's rhythm (user's reference: Shining in the Darkness).
# Every event is one BEAT: a message the battle screen shows big on its
# own, with the command buttons hidden until the whole sequence has played,
# so an enemy's turn is something you sit through ("prepares to strike..."
# then the hit) rather than a line scrolling past. Each beat lasts
# BEAT_SECONDS; a tap on the message or E skips ahead (skip_beat()). Under
# a verify script (`fast`) beats never wait, so `await _beat()` returns at
# once and the old synchronous flow - and every existing verify - holds.
# ---------------------------------------------------------------------------

signal beat(message: String)
# Which enemy is acting (2026-09-07, user: with three on stage you could not
# tell who was hitting you): the panel leans the winding-up figure forward
# and shakes + flashes it on the blow; the others stay still.
signal enemy_turn_started(index: int)
signal enemy_struck(index: int)
const BEAT_SECONDS := 1.1
const BEAT_SECONDS_SHORT := 0.7
var playing := false # a sequence of beats is on screen: commands hidden, actions ignored
var fast := false
var _skip := false

func _ready() -> void:
	fast = get_tree().get_script() != null

func skip_beat() -> void:
	_skip = true

func _beat(message: String, seconds: float = BEAT_SECONDS) -> void:
	_log(message)
	changed.emit()
	beat.emit(message)
	if fast:
		return
	_skip = false
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not _skip:
		await get_tree().process_frame

func _end_turn() -> void:
	playing = false
	changed.emit()

func _log(message: String) -> void:
	battle_log.append(message)
	if battle_log.size() > 8:
		battle_log.pop_front()

func alive_enemies() -> Array:
	var result: Array = []
	for i in range(current_enemies.size()):
		if current_enemies[i] != null:
			result.append(i)
	return result

func _join_names(names: Array) -> String:
	if names.size() == 1:
		return "A %s" % names[0]
	if names.size() == 2:
		return "A %s and a %s" % [names[0], names[1]]
	var head := ""
	for i in range(names.size() - 1):
		if i > 0:
			head += ", a "
		head += names[i]
	return "A %s, and a %s" % [head, names[-1]]

func _pick_encounter_group(zone: int = -1) -> Array:
	var roll := randf()
	var size := 1
	if roll < 0.10:
		size = 3
	elif roll < 0.40:
		size = 2
	var group: Array = []
	for i in range(size):
		group.append(Enemies.pick_random_id() if zone == -1 else Enemies.pick_random_id_for_zone(zone))
	return group

# zone: an outer-biome World.Zone value from the overworld's per-tile
# check (see overworld.gd/overworld2.gd), or the default -1 for every
# existing interior call site (maze_interior.gd) - keeps their behavior
# byte-for-byte unchanged, still drawing from the original 5-enemy pool.
func check_random_encounter(zone: int = -1) -> void:
	if in_combat:
		return
	_steps_since_encounter += 1
	if _steps_since_encounter < ENCOUNTER_COOLDOWN_STEPS:
		return
	if randf() < ENCOUNTER_CHANCE:
		_steps_since_encounter = 0
		start_combat(_pick_encounter_group(zone), zone)

func _build_enemy_entry(def: Dictionary) -> Dictionary:
	return {
		"name": def.name,
		"sprite": def.sprite,
		"tint": def.get("tint", Color(1, 1, 1, 1)),
		"hp": def.max_hp,
		"max_hp": def.max_hp,
		"attack": def.attack,
		"defense": def.defense,
		"gold_min": def.gold_min,
		"gold_max": def.gold_max,
		"status_attack": def.get("status_attack", {}),
		"drop_item_ids": def.get("drop_item_ids", []),
	}

# Accepts either a single enemy id (String) or a group (Array of Strings).
# `zone` (a World.Zone value) decides which companions come along.
func start_combat(enemy_ids, zone: int = -1) -> void:
	var ids: Array = enemy_ids if enemy_ids is Array else [enemy_ids]
	fight_zone = zone
	current_enemies = []
	var names: Array = []
	for id in ids:
		var def: Dictionary = Enemies.ENEMIES[id]
		names.append(def.name)
		current_enemies.append(_build_enemy_entry(def))
	in_combat = true
	player_defending = false
	active_submenu = ""
	selecting_target = ""
	player_status = {}
	current_boss_id = ""
	current_wild_monster_key = ""
	awaiting_exit = false
	_nap_pending = false
	fight_gold = 0
	fight_xp = 0
	fight_items = []
	_refill_companions(roster_for_zone(zone))
	battle_log = ["%s %s!" % [_join_names(names), "appears" if names.size() == 1 else "appear"]]
	changed.emit()

# A static overworld wild monster (wild_monster.gd) was interacted with - the
# player already knows which SPECIES they're walking up to (that's the whole
# point of "farm specific monster types"), but not how many. Reuses
# _pick_encounter_group()'s exact size weighting (60/30/10 solo/duo/trio) so
# there's still a real "oh, there's three of them" surprise, just with slot 0
# forced to the anchor species so it's always guaranteed to be part of the
# fight. Delegates to the existing start_combat() for everything else, then
# stamps current_wild_monster_key afterward (start_combat() itself resets it
# to "" as part of its normal per-fight state reset, same as current_boss_id -
# setting it after the call, not before, avoids that reset clobbering it).
func start_wild_encounter(anchor_enemy_id: String, zone: int, placement_key: String) -> void:
	if in_combat:
		return
	var group: Array = _pick_encounter_group(zone)
	group[0] = anchor_enemy_id
	start_combat(group, zone)
	current_wild_monster_key = placement_key

# Fixed boss fight: the player already deliberately walked up and pressed E
# (boss.gd), so unlike a random encounter there's no need to build any
# suspense - the battle screen just opens, same as any other encounter here.
func start_boss_fight(boss_id: String) -> void:
	if in_combat or not Enemies.BOSSES.has(boss_id):
		return
	var def: Dictionary = Enemies.BOSSES[boss_id]
	current_enemies = [_build_enemy_entry(def)]
	in_combat = true
	player_defending = false
	active_submenu = ""
	selecting_target = ""
	player_status = {}
	current_boss_id = boss_id
	current_wild_monster_key = ""
	fight_zone = -1
	_refill_companions(roster_for_event(BOSS_EVENT.get(boss_id, "")))
	battle_log = ["%s blocks your path!" % def.name]
	changed.emit()

# Gear contributions come from Character.SLOTS (the one slot table) - attack
# and defence are summed over every slot that feeds them, bonuses take the
# best value - so a new slot type needs no change here.
func _weapon_attack_bonus() -> int:
	return Character.gear_total("attack")

func _player_defense_bonus() -> int:
	return Character.gear_total("defense")

func _accessory_bonus(field: String) -> float:
	return Character.gear_bonus(field)

# Percentage mitigation (balance pass, 2026-09-06): every point of defence
# shaves a share off the hit rather than a flat amount, so armour tiers are
# visible steps and none makes you immune - leather (3) blocks ~27%,
# Bog-iron Harness (11) ~58%. Tuned with tools/sim_balance.gd.
const ARMOUR_K := 8.0

func _physical_damage(power: int, defense: int) -> int:
	var base: float = power * ARMOUR_K / (ARMOUR_K + defense)
	var variance: float = base * (randf() * 0.3 - 0.15)
	return max(1, int(round(base + variance)))

# ---------------------------------------------------------------------------
# Status effects
# ---------------------------------------------------------------------------

func _apply_status_to_player(status_id: String) -> void:
	if player_status.has(status_id):
		return # no stacking/refresh this pass
	var def: Dictionary = Statuses.STATUSES[status_id]
	player_status[status_id] = {"turns_left": def.duration}
	await _beat("Oliver is afflicted with %s!" % def.name)

func _tick_player_poison() -> void:
	if not player_status.has("poison"):
		return
	var dmg: int = Statuses.STATUSES.poison.dot_damage
	Character.stats.hp = max(0, Character.stats.hp - dmg)
	Character.changed.emit()
	await _beat("Oliver takes %d poison damage!" % dmg, BEAT_SECONDS_SHORT)

func _tick_status_durations() -> void:
	var expired: Array = []
	for status_id in player_status.keys():
		player_status[status_id].turns_left -= 1
		if player_status[status_id].turns_left <= 0:
			expired.append(status_id)
	for status_id in expired:
		player_status.erase(status_id)
		await _beat("Oliver's %s wears off." % Statuses.STATUSES[status_id].name, BEAT_SECONDS_SHORT)

# Gate run at the start of every player-committing action. Ticks poison,
# then checks Sleep/Paralysis. Returns true if the action should proceed;
# if false, it has already resolved the turn as skipped (or handled defeat).
func _begin_player_turn() -> bool:
	await _tick_player_poison()
	if Character.stats.hp <= 0:
		await _defeat("poison")
		return false
	if player_status.has("sleep"):
		await _beat("Oliver is fast asleep and can't act!")
		await _enemy_turn()
		return false
	if player_status.has("paralysis") and randf() >= Statuses.STATUSES.paralysis.act_chance:
		await _beat("Oliver is paralyzed and can't move!")
		await _enemy_turn()
		return false
	return true

# ---------------------------------------------------------------------------
# Player actions - each one is a sequence of beats; `playing` is true from
# the press until the last beat has shown (the screen hides the commands).
# ---------------------------------------------------------------------------

func player_attack() -> void:
	if not in_combat or playing or awaiting_exit or alive_enemies().is_empty():
		return
	active_submenu = ""
	playing = true
	changed.emit()
	if not await _begin_player_turn():
		_end_turn()
		return
	player_defending = false

	if player_status.has("confusion") and randf() < Statuses.STATUSES.confusion.self_hit_chance:
		var self_power: int = Character.stats.strength * 2 + _weapon_attack_bonus()
		var self_dmg := _physical_damage(self_power, 0)
		Character.stats.hp = max(0, Character.stats.hp - self_dmg)
		Character.changed.emit()
		await _beat("Oliver is confused and hits himself for %d damage!" % self_dmg)
		if Character.stats.hp <= 0:
			await _defeat("confusion")
			_end_turn()
			return
		await _enemy_turn()
		_end_turn()
		return

	var alive := alive_enemies()
	if alive.size() == 1:
		await _resolve_attack_on_target(alive[0])
	else:
		selecting_target = "attack" # the sequence resumes in select_target()
	_end_turn()

func _resolve_attack_on_target(index: int) -> void:
	var enemy: Dictionary = current_enemies[index]
	var power: int = Character.stats.strength * 2 + _weapon_attack_bonus()
	var dmg := _physical_damage(power, enemy.defense)
	enemy.hp = max(0, enemy.hp - dmg)
	await _beat("Oliver attacks %s for %d damage!" % [enemy.name, dmg])
	if enemy.hp <= 0:
		await _defeat_enemy(index)
	else:
		await _enemy_turn()

# Click handler for an enemy slot - only does anything while a target is
# being chosen (2+ enemies were alive when Attack/a damage spell was picked).
func select_target(index: int) -> void:
	if playing or selecting_target == "" or index >= current_enemies.size() or current_enemies[index] == null:
		return
	var action := selecting_target
	selecting_target = ""
	playing = true
	changed.emit()
	if action == "attack":
		await _resolve_attack_on_target(index)
	elif action == "bite":
		await _resolve_bite(index)
	elif action.begins_with("spell:"):
		await _resolve_spell_on_target(action.substr(6), index)
	_end_turn()

# --- companion rounds ---

# `move` is one of COMPANION_MOVES[id] ids; "" = the companion's first move.
func companion_act(id: String, move: String = "") -> void:
	if not in_combat or playing or awaiting_exit or alive_enemies().is_empty() or not companion_ready(id):
		return
	if move == "":
		move = COMPANION_MOVES[id][0].id
	active_submenu = ""
	playing = true
	changed.emit()
	if not await _begin_player_turn():
		_end_turn()
		return
	player_defending = false
	companion_charges[id] -= 1
	if companion_active != "" and companion_active != id:
		var other: String = companion_active
		companion_active = ""
		await _beat("%s steps back." % COMPANIONS[other].name, BEAT_SECONDS_SHORT)
		companion_left.emit(other)
	var was_on_stage: bool = companion_active == id
	companion_active = id
	# The pool: granted once per fight on the first call (doubled for a
	# Guard), kept across a step-back, topped up by a later Guard.
	var base_pool: int = max(1, int(round(Character.stats.max_hp * COMPANION_HP_FACTOR)))
	if not companion_pools.has(id):
		var size: int = int(round(base_pool * GUARD_POOL_MULT)) if move == "guard" else base_pool
		companion_pools[id] = size
		companion_max_pools[id] = size
	elif move == "guard":
		companion_max_pools[id] = int(round(base_pool * GUARD_POOL_MULT))
		companion_pools[id] = mini(companion_max_pools[id], companion_pools[id] + base_pool)
	companion_hp = companion_pools[id]
	companion_max_hp = companion_max_pools[id]
	if not was_on_stage:
		companion_called.emit(id)
	match move:
		"bite":
			await _beat("Luigi the Fearless bounds in!" if not was_on_stage else "Luigi bares his teeth!", BEAT_SECONDS_SHORT)
			var alive := alive_enemies()
			if alive.size() == 1:
				await _resolve_bite(alive[0])
			else:
				selecting_target = "bite" # the sequence resumes in select_target()
		"guard":
			guard_round = true
			await _beat("Luigi plants his paws and braces - nothing gets past!", BEAT_SECONDS_SHORT)
			await _enemy_turn()
		"scream":
			await _beat("Eden flits in and draws a deep breath..." if not was_on_stage else "Eden draws a deep breath...", BEAT_SECONDS_SHORT)
			await _scream()
		"shimmer":
			shimmer_round = true
			await _beat("Eden scatters a shimmer of light - nothing can find its mark!", BEAT_SECONDS_SHORT)
			await _enemy_turn()
	_end_turn()

# The active companion took `damage`: its pool and the mirror the panel reads.
func _hurt_companion(id: String, damage: int) -> void:
	companion_pools[id] = max(0, companion_pools.get(id, 0) - damage)
	companion_hp = companion_pools[id]

func _resolve_bite(index: int) -> void:
	var enemy: Dictionary = current_enemies[index]
	var power: int = int(round((Character.stats.strength * 2 + _weapon_attack_bonus()) * BITE_MULT))
	var dmg := _physical_damage(power, enemy.defense)
	enemy.hp = max(0, enemy.hp - dmg)
	companion_struck.emit("luigi")
	await _beat("Luigi bites %s for %d damage!" % [enemy.name, dmg])
	if enemy.hp <= 0:
		await _defeat_enemy(index)
	else:
		await _enemy_turn()

func _scream() -> void:
	var power: int = int(round((Character.stats.strength * 2 + _weapon_attack_bonus()) * SCREAM_MULT))
	companion_struck.emit("eden")
	var first := true
	var targets := alive_enemies()
	for index in targets:
		var enemy: Dictionary = current_enemies[index]
		var dmg := _physical_damage(power, 0)
		enemy.hp = max(0, enemy.hp - dmg)
		await _beat("%s%s takes %d damage!" % ["Eden SCREAMS! " if first else "", enemy.name, dmg], BEAT_SECONDS if first else BEAT_SECONDS_SHORT)
		first = false
	# The fallen doze off in slot order (the enemy turn waits for all of them).
	for index in targets:
		if current_enemies[index] != null and current_enemies[index].hp <= 0:
			await _defeat_enemy(index, false)
	if alive_enemies().is_empty():
		return
	for index in alive_enemies():
		var enemy: Dictionary = current_enemies[index]
		if current_boss_id != "":
			await _beat("%s only flinches." % enemy.name, BEAT_SECONDS_SHORT)
		elif randf() < SCREAM_STUN_CHANCE:
			enemy.stunned = true
			await _beat("%s is left reeling!" % enemy.name, BEAT_SECONDS_SHORT)
	await _enemy_turn()

func open_magic_menu() -> void:
	if not in_combat or playing or awaiting_exit or alive_enemies().is_empty():
		return
	if player_status.has("silence"):
		_log("Oliver is silenced and cannot cast spells!")
		changed.emit()
		return
	active_submenu = "magic"
	changed.emit()

func open_item_menu() -> void:
	if not in_combat or playing or awaiting_exit or alive_enemies().is_empty():
		return
	active_submenu = "item"
	changed.emit()

func close_submenu() -> void:
	active_submenu = ""
	changed.emit()

func cast_spell(spell_id: String) -> void:
	if not in_combat or playing or awaiting_exit or alive_enemies().is_empty():
		return
	var spell: Dictionary = Spells.SPELLS.get(spell_id, {})
	if spell.is_empty() or Character.stats.mp < spell.mp_cost:
		return
	active_submenu = ""
	playing = true
	changed.emit()
	if not await _begin_player_turn():
		_end_turn()
		return
	player_defending = false
	Character.stats.mp -= spell.mp_cost
	Character.changed.emit()

	if spell.kind == "damage":
		var alive := alive_enemies()
		if alive.size() == 1:
			await _resolve_spell_on_target(spell_id, alive[0])
		else:
			selecting_target = "spell:%s" % spell_id
	elif spell.kind == "heal":
		var healed: int = min(spell.power, Character.stats.max_hp - Character.stats.hp)
		Character.stats.hp += healed
		Character.changed.emit()
		await _beat("Oliver casts %s and recovers %d HP!" % [spell.name, healed])
		await _enemy_turn()
	_end_turn()

func _resolve_spell_on_target(spell_id: String, index: int) -> void:
	var spell: Dictionary = Spells.SPELLS[spell_id]
	var enemy: Dictionary = current_enemies[index]
	var dmg := _physical_damage(spell.power, 0)
	enemy.hp = max(0, enemy.hp - dmg)
	await _beat("Oliver casts %s on %s for %d damage!" % [spell.name, enemy.name, dmg])
	if enemy.hp <= 0:
		await _defeat_enemy(index)
	else:
		await _enemy_turn()

func use_item(item_id: String) -> void:
	if not in_combat or playing or awaiting_exit or alive_enemies().is_empty() or Inventory.get_count(item_id) <= 0:
		return
	var def: Dictionary = Items.ITEMS.get(item_id, {})
	var effect: Dictionary = def.get("effect", {})
	if effect.is_empty():
		return
	active_submenu = ""
	playing = true
	changed.emit()
	if not await _begin_player_turn():
		_end_turn()
		return
	player_defending = false
	Inventory.remove_item(item_id, 1)
	if effect.kind == "escape":
		# The Angel Feather: a guaranteed escape that also carries Oliver
		# home. The fight ends like a flight (no sting, boss re-challengeable).
		await _beat("Oliver holds up the %s - a rush of wings!" % def.name)
		_flee()
		GameState.escape_home()
		return
	# Effect maths lives in Items.apply_effect() (shared with the
	# out-of-combat QuickBar); in combat the item is always spent since the
	# turn is used either way.
	var message: String = Items.apply_effect(item_id).message
	Character.changed.emit()
	await _beat(message)
	await _enemy_turn()
	_end_turn()

func player_defend() -> void:
	if not in_combat or playing or awaiting_exit:
		return
	active_submenu = ""
	playing = true
	changed.emit()
	if not await _begin_player_turn():
		_end_turn()
		return
	player_defending = true
	await _beat("Oliver braces for the next attack.", BEAT_SECONDS_SHORT)
	await _enemy_turn()
	_end_turn()

func player_run() -> void:
	if not in_combat or playing or awaiting_exit:
		return
	_log("Oliver flees the battle!")
	_flee()

# Ends the fight without a victory: running, or a feather home.
func _flee() -> void:
	in_combat = false
	playing = false
	current_enemies = []
	active_submenu = ""
	selecting_target = ""
	player_status = {}
	current_boss_id = "" # fleeing a boss leaves it undefeated, re-challengeable
	current_wild_monster_key = "" # same - fleeing a wild monster leaves it re-challengeable
	companion_charges = {}
	companion_active = ""
	changed.emit()
	ended.emit(false)

# ---------------------------------------------------------------------------
# Enemy turn / resolution
# ---------------------------------------------------------------------------

# One enemy dropping to 0 HP: grants its gold (and drop item, if any) and
# XP, tells it in beats (the doze-off, then any level-up), and clears its
# slot. If that empties the whole group, ends combat in victory (marking a
# boss's checkpoint permanently defeated); otherwise the survivors take
# their turn.
# `then_enemy_turn` = false while several fall at once (Eden's scream): the
# caller runs the enemy turn after the last of them.
func _defeat_enemy(index: int, then_enemy_turn: bool = true) -> void:
	var enemy: Dictionary = current_enemies[index]
	var gold: int = enemy.gold_min + randi() % (enemy.gold_max - enemy.gold_min + 1)
	Inventory.add_item("gold", gold)
	fight_gold += gold
	var msg := "%s dozes off! You pocket %d gold." % [enemy.name, gold]
	# Drop entries are either a plain item id (always drops) or
	# {"item": id, "chance": 0..1} for rarer ingredients (Ember Core).
	var drop_item_ids: Array = enemy.get("drop_item_ids", [])
	for entry in drop_item_ids:
		var drop_item_id: String = entry.item if entry is Dictionary else entry
		var chance: float = float(entry.get("chance", 1.0)) if entry is Dictionary else 1.0
		if randf() >= chance:
			continue
		Inventory.add_item(drop_item_id, 1)
		fight_items.append(Items.get_item_name(drop_item_id))
		msg += " Obtained %s!" % Items.get_item_name(drop_item_id)
	# The way home: a boss ALWAYS drops an Angel Feather (in case you left
	# home without one); any wild monster may.
	var feather: bool = current_boss_id != "" or randf() < FEATHER_DROP_CHANCE
	if feather and Inventory.can_add("angel_feather"):
		Inventory.add_item("angel_feather", 1)
		fight_items.append(Items.get_item_name("angel_feather"))
		msg += " Obtained Angel Feather!"
	# Experience: paid per enemy as it drops (a boss is worth double).
	var xp: int = Enemies.xp_for(enemy, current_boss_id != "")
	fight_xp += xp
	msg += " +%d XP." % xp
	Audio.play_sfx("coin")
	await _beat(msg)
	var level_before: int = Character.stats.level
	if Character.gain_xp(xp) > 0:
		await _beat("Level up! Oliver is now level %d (%s)." % [Character.stats.level, Character.level_up_text(Character.stats.level)])
		if Character.stats.level - level_before > 1:
			await _beat("...and climbed %d levels at once!" % (Character.stats.level - level_before), BEAT_SECONDS_SHORT)
	current_enemies[index] = null
	if alive_enemies().is_empty():
		active_submenu = ""
		selecting_target = ""
		player_status = {}
		if current_boss_id != "":
			GameState.boss_defeated[current_boss_id] = true
			current_boss_id = ""
		if current_wild_monster_key != "":
			GameState.put_wild_monster_to_sleep(current_wild_monster_key)
			current_wild_monster_key = ""
		if companion_active != "":
			var home: String = companion_active
			companion_active = ""
			companion_left.emit(home)
		won.emit()
		if fast:
			in_combat = false
			changed.emit()
			ended.emit(true)
		else:
			_log(victory_summary())
			awaiting_exit = true
			changed.emit()
	else:
		changed.emit()
		if then_enemy_turn:
			await _enemy_turn()

# "Victory! You earned 12 gold and 19 XP. Loot: Monster Fur." - the whole
# fight's takings, shown big while the screen waits for Continue.
func victory_summary() -> String:
	var text := "Victory! You earned %d gold and %d XP." % [fight_gold, fight_xp]
	if not fight_items.is_empty():
		text += " Loot: %s." % ", ".join(fight_items)
	return text

# Leaves the victory summary: the fight is over and the world resumes.
func finish_combat() -> void:
	if not awaiting_exit:
		return
	awaiting_exit = false
	if _nap_pending:
		_nap_pending = false
		_nap()
		return
	in_combat = false
	changed.emit()
	ended.emit(true)

func _enemy_turn() -> void:
	var was_asleep: bool = player_status.has("sleep")
	var woke_this_round := false
	for index in alive_enemies():
		var enemy: Dictionary = current_enemies[index]
		# Left reeling by Eden's scream: this strike is skipped.
		if enemy.get("stunned", false):
			enemy.erase("stunned")
			await _beat("%s is still reeling and can't attack!" % enemy.name, BEAT_SECONDS_SHORT)
			continue
		# The wind-up: a beat of nothing you can do about it.
		enemy_turn_started.emit(index)
		await _beat("%s prepares to strike..." % enemy.name, BEAT_SECONDS_SHORT)
		# Eden's shimmer: this round nothing lands on anyone.
		if shimmer_round:
			enemy_struck.emit(index)
			Audio.play_sfx("dodge")
			await _beat("%s attacks - the shimmer turns it aside!" % enemy.name)
			continue
		# A companion on stage draws the blow onto its own pool (no armour;
		# halved while Luigi braces).
		if companion_active != "":
			var cid: String = companion_active
			var cdmg := _physical_damage(enemy.attack, 0)
			if guard_round:
				cdmg = max(1, cdmg / 2)
			_hurt_companion(cid, cdmg)
			enemy_struck.emit(index)
			companion_hit.emit(cid, cdmg)
			await _beat("%s attacks %s for %d damage!" % [enemy.name, COMPANIONS[cid].name, cdmg])
			if companion_hp <= 0:
				companion_active = ""
				companion_out[cid] = true
				await _beat("%s is knocked back and limps out of the fight!" % COMPANIONS[cid].name)
				companion_left.emit(cid)
			continue
		# Agility above its starting value lets Oliver slip a blow entirely.
		if randf() < Character.dodge_chance():
			enemy_struck.emit(index)
			Audio.play_sfx("dodge")
			await _beat("%s attacks - Oliver dodges!" % enemy.name)
			if was_asleep and not woke_this_round:
				player_status.erase("sleep")
				await _beat("Oliver wakes up!", BEAT_SECONDS_SHORT)
				woke_this_round = true
			continue
		var dmg := _physical_damage(enemy.attack, _player_defense_bonus())
		if player_defending:
			dmg = max(1, dmg / 2)
		Character.stats.hp = max(0, Character.stats.hp - dmg)
		Character.changed.emit()
		enemy_struck.emit(index)
		await _beat("%s attacks Oliver for %d damage!" % [enemy.name, dmg])

		if Character.stats.hp <= 0:
			await _defeat(enemy.name)
			return

		var status_attack: Dictionary = enemy.get("status_attack", {})
		if not status_attack.is_empty():
			var chance: float = status_attack.chance * (1.0 - _accessory_bonus("status_resistance"))
			if randf() < chance:
				await _apply_status_to_player(status_attack.status)

		if was_asleep and not woke_this_round:
			player_status.erase("sleep")
			await _beat("Oliver wakes up!", BEAT_SECONDS_SHORT)
			woke_this_round = true

	guard_round = false
	shimmer_round = false
	await _tick_status_durations()
	changed.emit()

# Losing: HP/MP restored, a tenth of the gold lost, back home in bed. The
# DefeatPanel autoload covers the scene change and tells the story.
func _defeat(cause: String = "") -> void:
	await _beat("Oliver is worn out and needs a nap...")
	# A nap costs the pack: all carried gold and every valued stackable
	# (materials, potions, feathers). Gear - worn or spare - and quest items
	# stay; gold banked in the house chest is untouched.
	var lost: Dictionary = Inventory.drop_on_defeat()
	var gold_lost: int = int(lost.get("gold", 0))
	lost.erase("gold")
	last_defeat = {"cause": cause, "gold_lost": gold_lost, "items_lost": lost}
	# The screen holds on the last blow and the nap line until Continue
	# (user feedback: it vanished before the hit could be read) - same hold
	# as a victory. Under a verify script the nap starts at once.
	if fast:
		_nap()
	else:
		awaiting_exit = true
		_nap_pending = true
		changed.emit()

# The nap itself: HP/MP back, fight cleared, home to the house, DefeatPanel.
func _nap() -> void:
	Character.stats.hp = Character.stats.max_hp
	Character.stats.mp = Character.stats.max_mp
	Character.changed.emit()
	in_combat = false
	current_enemies = []
	active_submenu = ""
	selecting_target = ""
	player_status = {}
	current_boss_id = "" # losing to a boss leaves it undefeated, re-challengeable
	current_wild_monster_key = "" # same - losing to a wild monster leaves it re-challengeable
	changed.emit()
	ended.emit(false)
	# Nap time: wake up beside the bed at home.
	GameState.set_next_spawn(Vector2(NAP_SPAWN_TILE.x * 32 + 16, NAP_SPAWN_TILE.y * 32 + 16))
	get_tree().change_scene_to_file("res://scenes/House.tscn")
	defeated.emit(last_defeat)

# Drops any fight state (SaveSystem.new_game() / load).
func reset() -> void:
	in_combat = false
	current_enemies = []
	player_defending = false
	battle_log = []
	active_submenu = ""
	player_status = {}
	selecting_target = ""
	current_boss_id = ""
	current_wild_monster_key = ""
	playing = false
	awaiting_exit = false
	_nap_pending = false
	companion_charges = {}
	companion_active = ""
	changed.emit()
