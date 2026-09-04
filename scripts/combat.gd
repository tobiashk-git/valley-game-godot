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

func _log(message: String) -> void:
	battle_log.append(message)
	if battle_log.size() > 5:
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
	_log("Oliver is afflicted with %s!" % def.name)

func _tick_player_poison() -> void:
	if not player_status.has("poison"):
		return
	var dmg: int = Statuses.STATUSES.poison.dot_damage
	Character.stats.hp = max(0, Character.stats.hp - dmg)
	_log("Oliver takes %d poison damage!" % dmg)
	Character.changed.emit()

func _tick_status_durations() -> void:
	var expired: Array = []
	for status_id in player_status.keys():
		player_status[status_id].turns_left -= 1
		if player_status[status_id].turns_left <= 0:
			expired.append(status_id)
	for status_id in expired:
		_log("Oliver's %s wears off." % Statuses.STATUSES[status_id].name)
		player_status.erase(status_id)

# Gate run at the start of every player-committing action. Ticks poison,
# then checks Sleep/Paralysis. Returns true if the action should proceed;
# if false, it has already resolved the turn as skipped (or handled defeat).
func _begin_player_turn() -> bool:
	_tick_player_poison()
	if Character.stats.hp <= 0:
		_defeat()
		return false
	if player_status.has("sleep"):
		_log("Oliver is fast asleep and can't act!")
		changed.emit()
		_enemy_turn()
		return false
	if player_status.has("paralysis") and randf() >= Statuses.STATUSES.paralysis.act_chance:
		_log("Oliver is paralyzed and can't move!")
		changed.emit()
		_enemy_turn()
		return false
	return true

# ---------------------------------------------------------------------------
# Player actions
# ---------------------------------------------------------------------------

func player_attack() -> void:
	if not in_combat or alive_enemies().is_empty():
		return
	active_submenu = ""
	if not _begin_player_turn():
		return
	player_defending = false

	if player_status.has("confusion") and randf() < Statuses.STATUSES.confusion.self_hit_chance:
		var self_power: int = Character.stats.strength * 2 + _weapon_attack_bonus()
		var self_dmg := _physical_damage(self_power, 0)
		Character.stats.hp = max(0, Character.stats.hp - self_dmg)
		_log("Oliver is confused and hits himself for %d damage!" % self_dmg)
		Character.changed.emit()
		if Character.stats.hp <= 0:
			_defeat()
			return
		_enemy_turn()
		return

	var alive := alive_enemies()
	if alive.size() == 1:
		_resolve_attack_on_target(alive[0])
	else:
		selecting_target = "attack"
		changed.emit()

func _resolve_attack_on_target(index: int) -> void:
	var enemy: Dictionary = current_enemies[index]
	var power: int = Character.stats.strength * 2 + _weapon_attack_bonus()
	var dmg := _physical_damage(power, enemy.defense)
	enemy.hp = max(0, enemy.hp - dmg)
	_log("Oliver attacks %s for %d damage!" % [enemy.name, dmg])
	changed.emit()
	if enemy.hp <= 0:
		_defeat_enemy(index)
	else:
		_enemy_turn()

# Click handler for an enemy slot — only does anything while a target is
# being chosen (2+ enemies were alive when Attack/a damage spell was picked).
func select_target(index: int) -> void:
	if selecting_target == "" or index >= current_enemies.size() or current_enemies[index] == null:
		return
	var action := selecting_target
	selecting_target = ""
	if action == "attack":
		_resolve_attack_on_target(index)
	elif action.begins_with("spell:"):
		_resolve_spell_on_target(action.substr(6), index)

func open_magic_menu() -> void:
	if not in_combat or alive_enemies().is_empty():
		return
	if player_status.has("silence"):
		_log("Oliver is silenced and cannot cast spells!")
		changed.emit()
		return
	active_submenu = "magic"
	changed.emit()

func open_item_menu() -> void:
	if not in_combat or alive_enemies().is_empty():
		return
	active_submenu = "item"
	changed.emit()

func close_submenu() -> void:
	active_submenu = ""
	changed.emit()

func cast_spell(spell_id: String) -> void:
	if not in_combat or alive_enemies().is_empty():
		return
	var spell: Dictionary = Spells.SPELLS.get(spell_id, {})
	if spell.is_empty() or Character.stats.mp < spell.mp_cost:
		return
	active_submenu = ""
	if not _begin_player_turn():
		return
	player_defending = false
	Character.stats.mp -= spell.mp_cost
	Character.changed.emit()

	if spell.kind == "damage":
		var alive := alive_enemies()
		if alive.size() == 1:
			_resolve_spell_on_target(spell_id, alive[0])
		else:
			selecting_target = "spell:%s" % spell_id
			changed.emit()
	elif spell.kind == "heal":
		var healed: int = min(spell.power, Character.stats.max_hp - Character.stats.hp)
		Character.stats.hp += healed
		_log("Oliver casts %s and recovers %d HP!" % [spell.name, healed])
		Character.changed.emit()
		_enemy_turn()

func _resolve_spell_on_target(spell_id: String, index: int) -> void:
	var spell: Dictionary = Spells.SPELLS[spell_id]
	var enemy: Dictionary = current_enemies[index]
	var dmg := _physical_damage(spell.power, 0)
	enemy.hp = max(0, enemy.hp - dmg)
	_log("Oliver casts %s on %s for %d damage!" % [spell.name, enemy.name, dmg])
	changed.emit()
	if enemy.hp <= 0:
		_defeat_enemy(index)
	else:
		_enemy_turn()

func use_item(item_id: String) -> void:
	if not in_combat or alive_enemies().is_empty() or Inventory.get_count(item_id) <= 0:
		return
	var def: Dictionary = Items.ITEMS.get(item_id, {})
	var effect: Dictionary = def.get("effect", {})
	if effect.is_empty():
		return
	active_submenu = ""
	if not _begin_player_turn():
		return
	player_defending = false
	Inventory.remove_item(item_id, 1)
	# Effect maths lives in Items.apply_effect() (shared with the
	# out-of-combat QuickBar); in combat the item is always spent since the
	# turn is used either way.
	_log(Items.apply_effect(item_id).message)
	Character.changed.emit()
	_enemy_turn()

func player_defend() -> void:
	if not in_combat:
		return
	active_submenu = ""
	if not _begin_player_turn():
		return
	player_defending = true
	_log("Oliver braces for the next attack.")
	_enemy_turn()

func player_run() -> void:
	if not in_combat:
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

# One enemy dropping to 0 HP: grants its gold (and drop item, if any)
# immediately, logs it, and clears its slot. If that empties the whole
# group, ends combat in victory (marking a boss's checkpoint permanently
# defeated); otherwise the fight continues with the survivors' turn.
func _defeat_enemy(index: int) -> void:
	var enemy: Dictionary = current_enemies[index]
	var gold: int = enemy.gold_min + randi() % (enemy.gold_max - enemy.gold_min + 1)
	Inventory.add_item("gold", gold)
	var msg := "%s defeated! Found %d gold." % [enemy.name, gold]
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
	_log(msg)
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
			GameState.wild_monsters_defeated[current_wild_monster_key] = true
			current_wild_monster_key = ""
		changed.emit()
		ended.emit(true)
	else:
		changed.emit()
		_enemy_turn()

func _enemy_turn() -> void:
	var was_asleep: bool = player_status.has("sleep")
	var woke_this_round := false
	for index in alive_enemies():
		var enemy: Dictionary = current_enemies[index]
		var dmg := _physical_damage(enemy.attack, _player_defense_bonus())
		if player_defending:
			dmg = max(1, dmg / 2)
		Character.stats.hp = max(0, Character.stats.hp - dmg)
		_log("%s attacks Oliver for %d damage!" % [enemy.name, dmg])
		Character.changed.emit()

		if Character.stats.hp <= 0:
			_defeat()
			return

		var status_attack: Dictionary = enemy.get("status_attack", {})
		if not status_attack.is_empty():
			var chance: float = status_attack.chance * (1.0 - _accessory_bonus("status_resistance"))
			if randf() < chance:
				_apply_status_to_player(status_attack.status)

		if was_asleep and not woke_this_round:
			player_status.erase("sleep")
			_log("Oliver wakes up!")
			woke_this_round = true

	_tick_status_durations()
	changed.emit()

func _defeat() -> void:
	_log("Oliver was defeated...")
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
	get_tree().change_scene_to_file("res://scenes/House.tscn")
