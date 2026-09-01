extends Node
# Autoload — Combat Phase 1+2: core battle loop plus the full command set.
# Single enemy, Attack/Magic/Item/Defend/Run, win/lose resolution. Magic and
# Item open a submenu (spell list / usable-item list) instead of acting
# directly. Port of the pre-groups, pre-status shape of combat.js, up
# through its "Phase 2" (items + real spell menu). Random encounters trigger
# only while walking the dungeon interior (see dungeon.gd's tile-change hook).

signal changed
signal ended(victory: bool)

const ENCOUNTER_CHANCE := 0.12
const ENCOUNTER_COOLDOWN_STEPS := 4

var in_combat := false
var current_enemy: Dictionary = {}
var player_defending := false
var battle_log: Array[String] = []
var active_submenu := "" # "" | "magic" | "item"

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
	active_submenu = ""
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
	active_submenu = ""
	player_defending = false
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
	Character.changed.emit()
	_enemy_turn()

func player_defend() -> void:
	if not in_combat:
		return
	active_submenu = ""
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
	active_submenu = ""
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
	changed.emit()
	ended.emit(false)
	get_tree().change_scene_to_file("res://scenes/House.tscn")
