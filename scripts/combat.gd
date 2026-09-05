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
# Emitted after a lost fight, once the player has been sent home:
# {"cause": enemy name | "poison" | "confusion", "gold_lost": int}. The
# DefeatPanel autoload plays the death sequence from it.
signal defeated(info: Dictionary)
const DEFEAT_GOLD_FRACTION := 0.1
# Where a nap ends: the floor tile beside Oliver's bed in House.tscn (the
# bed stands at (2, 4)) - mirrors house.gd's NAP_SPAWN_TILE (not preloaded
# from there: pulling house.gd into a --script compile drags chest.gd in,
# where autoload names don't resolve).
const NAP_SPAWN_TILE := Vector2i(3, 4)
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

var _steps_since_encounter := ENCOUNTER_COOLDOWN_STEPS

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
		start_combat(_pick_encounter_group(zone))

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
func start_combat(enemy_ids) -> void:
	var ids: Array = enemy_ids if enemy_ids is Array else [enemy_ids]
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
	start_combat(group)
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

func _physical_damage(power: int, defense: int) -> int:
	var base: float = power - defense
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
	if not in_combat or playing or alive_enemies().is_empty():
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
	elif action.begins_with("spell:"):
		await _resolve_spell_on_target(action.substr(6), index)
	_end_turn()

func open_magic_menu() -> void:
	if not in_combat or playing or alive_enemies().is_empty():
		return
	if player_status.has("silence"):
		_log("Oliver is silenced and cannot cast spells!")
		changed.emit()
		return
	active_submenu = "magic"
	changed.emit()

func open_item_menu() -> void:
	if not in_combat or playing or alive_enemies().is_empty():
		return
	active_submenu = "item"
	changed.emit()

func close_submenu() -> void:
	active_submenu = ""
	changed.emit()

func cast_spell(spell_id: String) -> void:
	if not in_combat or playing or alive_enemies().is_empty():
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
	if not in_combat or playing or alive_enemies().is_empty() or Inventory.get_count(item_id) <= 0:
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
	# Effect maths lives in Items.apply_effect() (shared with the
	# out-of-combat QuickBar); in combat the item is always spent since the
	# turn is used either way.
	var message: String = Items.apply_effect(item_id).message
	Character.changed.emit()
	await _beat(message)
	await _enemy_turn()
	_end_turn()

func player_defend() -> void:
	if not in_combat or playing:
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
	if not in_combat or playing:
		return
	_log("Oliver flees the battle!")
	in_combat = false
	current_enemies = []
	active_submenu = ""
	selecting_target = ""
	player_status = {}
	current_boss_id = "" # fleeing a boss leaves it undefeated, re-challengeable
	current_wild_monster_key = "" # same - fleeing a wild monster leaves it re-challengeable
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
func _defeat_enemy(index: int) -> void:
	var enemy: Dictionary = current_enemies[index]
	var gold: int = enemy.gold_min + randi() % (enemy.gold_max - enemy.gold_min + 1)
	Inventory.add_item("gold", gold)
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
		msg += " Obtained %s!" % Items.get_item_name(drop_item_id)
	# Experience: paid per enemy as it drops (a boss is worth double).
	var xp: int = Enemies.xp_for(enemy, current_boss_id != "")
	msg += " +%d XP." % xp
	await _beat(msg)
	var level_before: int = Character.stats.level
	if Character.gain_xp(xp) > 0:
		await _beat("Level up! Oliver is now level %d (%s)." % [Character.stats.level, Character.level_up_text(Character.stats.level)])
		if Character.stats.level - level_before > 1:
			await _beat("...and climbed %d levels at once!" % (Character.stats.level - level_before), BEAT_SECONDS_SHORT)
	current_enemies[index] = null
	if alive_enemies().is_empty():
		in_combat = false
		active_submenu = ""
		selecting_target = ""
		player_status = {}
		if current_boss_id != "":
			GameState.boss_defeated[current_boss_id] = true
			current_boss_id = ""
		if current_wild_monster_key != "":
			GameState.put_wild_monster_to_sleep(current_wild_monster_key)
			current_wild_monster_key = ""
		changed.emit()
		ended.emit(true)
	else:
		changed.emit()
		await _enemy_turn()

func _enemy_turn() -> void:
	var was_asleep: bool = player_status.has("sleep")
	var woke_this_round := false
	for index in alive_enemies():
		var enemy: Dictionary = current_enemies[index]
		# The wind-up: a beat of nothing you can do about it.
		await _beat("%s prepares to strike..." % enemy.name, BEAT_SECONDS_SHORT)
		# Agility above its starting value lets Oliver slip a blow entirely.
		if randf() < Character.dodge_chance():
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

	await _tick_status_durations()
	changed.emit()

# Losing: HP/MP restored, a tenth of the gold lost, back home in bed. The
# DefeatPanel autoload covers the scene change and tells the story.
func _defeat(cause: String = "") -> void:
	await _beat("Oliver is worn out and needs a nap...")
	var gold_lost: int = int(floor(Inventory.get_count("gold") * DEFEAT_GOLD_FRACTION))
	if gold_lost > 0:
		Inventory.remove_item("gold", gold_lost)
	last_defeat = {"cause": cause, "gold_lost": gold_lost}
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
	changed.emit()
