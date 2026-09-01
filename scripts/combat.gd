extends Node
# Autoload — Combat Phase 1: core battle loop. Single enemy, Attack/Cast
# Spell/Defend/Run, win/lose resolution. Port of the original (pre-groups,
# pre-status, pre-items) shape of combat.js. Random encounters trigger only
# while walking the dungeon interior (see dungeon.gd's tile-change hook).

signal changed
signal ended(victory: bool)

const ENCOUNTER_CHANCE := 0.12
const ENCOUNTER_COOLDOWN_STEPS := 4
const SPELL_MP_COST := 3
const SPELL_POWER := 10

var in_combat := false
var current_enemy: Dictionary = {}
var player_defending := false
var battle_log: Array[String] = []

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
	}
	in_combat = true
	player_defending = false
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

func player_attack() -> void:
	if not in_combat:
		return
	player_defending = false
	var power: int = Character.stats.strength * 2 + _weapon_attack_bonus()
	var dmg := _physical_damage(power, current_enemy.defense)
	current_enemy.hp = max(0, current_enemy.hp - dmg)
	_log("Oliver attacks %s for %d damage!" % [current_enemy.name, dmg])
	if current_enemy.hp <= 0:
		_victory()
		return
	_enemy_turn()

func player_cast_spell() -> void:
	if not in_combat or Character.stats.mp < SPELL_MP_COST:
		return
	player_defending = false
	Character.stats.mp -= SPELL_MP_COST
	var dmg := _physical_damage(SPELL_POWER, 0)
	current_enemy.hp = max(0, current_enemy.hp - dmg)
	_log("Oliver casts Fireball on %s for %d damage!" % [current_enemy.name, dmg])
	Character.changed.emit()
	if current_enemy.hp <= 0:
		_victory()
		return
	_enemy_turn()

func player_defend() -> void:
	if not in_combat:
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
	changed.emit()
	ended.emit(false)

func _enemy_turn() -> void:
	var dmg := _physical_damage(current_enemy.attack, 0)
	if player_defending:
		dmg = max(1, dmg / 2)
	Character.stats.hp = max(0, Character.stats.hp - dmg)
	_log("%s attacks Oliver for %d damage!" % [current_enemy.name, dmg])
	Character.changed.emit()
	if Character.stats.hp <= 0:
		_defeat()
		return
	changed.emit()

func _victory() -> void:
	var gold: int = current_enemy.gold_min + randi() % (current_enemy.gold_max - current_enemy.gold_min + 1)
	Inventory.add_item("gold", gold)
	_log("%s defeated! Found %d gold." % [current_enemy.name, gold])
	in_combat = false
	changed.emit()
	ended.emit(true)

func _defeat() -> void:
	_log("Oliver was defeated...")
	Character.stats.hp = Character.stats.max_hp
	Character.stats.mp = Character.stats.max_mp
	Character.changed.emit()
	in_combat = false
	current_enemy = {}
	changed.emit()
	ended.emit(false)
	get_tree().change_scene_to_file("res://scenes/House.tscn")
