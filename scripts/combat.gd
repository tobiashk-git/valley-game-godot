extends Node
# Autoload — Combat Phase 1+2+3: core battle loop, full command set, and
# status effects (poison/paralysis/sleep/confusion/silence). Single enemy,
# Attack/Magic/Item/Defend/Run, win/lose resolution. Port of the pre-groups
# shape of combat.js, up through its "Phase 3". Random encounters trigger
# only while walking the dungeon interior (see dungeon.gd's tile-change hook).
#
# Status effects are contained to combat: player_status always resets to {}
# when a fight starts or ends. Enemies can only inflict status on the player
# this pass (nothing the player has can inflict status on an enemy), so
# there is no enemy-side status state to track or tick.

signal changed
signal ended(victory: bool)

const ENCOUNTER_CHANCE := 0.12
const ENCOUNTER_COOLDOWN_STEPS := 4

var in_combat := false
var current_enemy: Dictionary = {}
var player_defending := false
var battle_log: Array[String] = []
var active_submenu := "" # "" | "magic" | "item"
var player_status: Dictionary = {} # status_id -> {"turns_left": N}

var _steps_since_encounter := ENCOUNTER_COOLDOWN_STEPS

func _log(message: String) -> void:
	battle_log.append(message)
	if battle_log.size() > 5:
		battle_log.pop_front()

func check_random_encounter() -> void:
	if in_combat:
		return
	_steps_since_encounter += 1
	if _steps_since_encounter < ENCOUNTER_COOLDOWN_STEPS:
		return
	if randf() < ENCOUNTER_CHANCE:
		_steps_since_encounter = 0
		start_combat(Enemies.pick_random_id())

func start_combat(enemy_id: String) -> void:
	var def: Dictionary = Enemies.ENEMIES[enemy_id]
	current_enemy = {
		"name": def.name,
		"sprite": def.sprite,
		"hp": def.max_hp,
		"max_hp": def.max_hp,
		"attack": def.attack,
		"defense": def.defense,
		"gold_min": def.gold_min,
		"gold_max": def.gold_max,
		"status_attack": def.get("status_attack", {}),
	}
	in_combat = true
	player_defending = false
	active_submenu = ""
	player_status = {}
	battle_log = ["%s appears!" % def.name]
	changed.emit()

func _weapon_attack_bonus() -> int:
	var weapon_id: String = Character.equipment.weapon
	if weapon_id == "":
		return 0
	return Items.ITEMS.get(weapon_id, {}).get("attack", 0)

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
	if not in_combat:
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

	var power: int = Character.stats.strength * 2 + _weapon_attack_bonus()
	var dmg := _physical_damage(power, current_enemy.defense)
	current_enemy.hp = max(0, current_enemy.hp - dmg)
	_log("Oliver attacks %s for %d damage!" % [current_enemy.name, dmg])
	if current_enemy.hp <= 0:
		_victory()
		return
	_enemy_turn()

func open_magic_menu() -> void:
	if not in_combat:
		return
	if player_status.has("silence"):
		_log("Oliver is silenced and cannot cast spells!")
		changed.emit()
		return
	active_submenu = "magic"
	changed.emit()

func open_item_menu() -> void:
	if not in_combat:
		return
	active_submenu = "item"
	changed.emit()

func close_submenu() -> void:
	active_submenu = ""
	changed.emit()

func cast_spell(spell_id: String) -> void:
	if not in_combat:
		return
	var spell: Dictionary = Spells.SPELLS.get(spell_id, {})
	if spell.is_empty() or Character.stats.mp < spell.mp_cost:
		return
	active_submenu = ""
	if not _begin_player_turn():
		return
	player_defending = false
	Character.stats.mp -= spell.mp_cost

	if spell.kind == "damage":
		var dmg := _physical_damage(spell.power, 0)
		current_enemy.hp = max(0, current_enemy.hp - dmg)
		_log("Oliver casts %s on %s for %d damage!" % [spell.name, current_enemy.name, dmg])
		Character.changed.emit()
		if current_enemy.hp <= 0:
			_victory()
			return
		_enemy_turn()
	elif spell.kind == "heal":
		var healed: int = min(spell.power, Character.stats.max_hp - Character.stats.hp)
		Character.stats.hp += healed
		_log("Oliver casts %s and recovers %d HP!" % [spell.name, healed])
		Character.changed.emit()
		_enemy_turn()

func use_item(item_id: String) -> void:
	if not in_combat or Inventory.get_count(item_id) <= 0:
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

	if effect.kind == "heal":
		var healed: int = min(effect.amount, Character.stats.max_hp - Character.stats.hp)
		Character.stats.hp += healed
		_log("Oliver uses %s and recovers %d HP!" % [def.name, healed])
	elif effect.kind == "restore_mp":
		var restored: int = min(effect.amount, Character.stats.max_mp - Character.stats.mp)
		Character.stats.mp += restored
		_log("Oliver uses %s and recovers %d MP!" % [def.name, restored])
	elif effect.kind == "cure":
		if player_status.has(effect.status):
			var status_name: String = Statuses.STATUSES[effect.status].name
			player_status.erase(effect.status)
			_log("Oliver uses %s and cures %s!" % [def.name, status_name])
		else:
			_log("Oliver uses %s, but wasn't affected." % def.name)
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
	current_enemy = {}
	active_submenu = ""
	player_status = {}
	changed.emit()
	ended.emit(false)

# ---------------------------------------------------------------------------
# Enemy turn / resolution
# ---------------------------------------------------------------------------

func _enemy_turn() -> void:
	var dmg := _physical_damage(current_enemy.attack, 0)
	if player_defending:
		dmg = max(1, dmg / 2)
	var was_asleep: bool = player_status.has("sleep")
	Character.stats.hp = max(0, Character.stats.hp - dmg)
	_log("%s attacks Oliver for %d damage!" % [current_enemy.name, dmg])
	Character.changed.emit()

	if Character.stats.hp <= 0:
		_defeat()
		return

	var status_attack: Dictionary = current_enemy.get("status_attack", {})
	if not status_attack.is_empty() and randf() < status_attack.chance:
		_apply_status_to_player(status_attack.status)

	if was_asleep:
		player_status.erase("sleep")
		_log("Oliver wakes up!")

	_tick_status_durations()
	changed.emit()

func _victory() -> void:
	var gold: int = current_enemy.gold_min + randi() % (current_enemy.gold_max - current_enemy.gold_min + 1)
	Inventory.add_item("gold", gold)
	_log("%s defeated! Found %d gold." % [current_enemy.name, gold])
	in_combat = false
	active_submenu = ""
	player_status = {}
	changed.emit()
	ended.emit(true)

func _defeat() -> void:
	_log("Oliver was defeated...")
	Character.stats.hp = Character.stats.max_hp
	Character.stats.mp = Character.stats.max_mp
	Character.changed.emit()
	in_combat = false
	current_enemy = {}
	active_submenu = ""
	player_status = {}
	changed.emit()
	ended.emit(false)
	get_tree().change_scene_to_file("res://scenes/House.tscn")
