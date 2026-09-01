extends CanvasLayer
# Autoload — full-screen battle UI. Visibility just mirrors Combat.in_combat;
# every button is a thin wrapper calling straight into Combat's own guards.

@onready var panel: Panel = $Panel
@onready var enemy_sprite: TextureRect = $Panel/Margin/VBox/EnemyRow/EnemySprite
@onready var enemy_name_label: Label = $Panel/Margin/VBox/EnemyRow/EnemyInfo/EnemyName
@onready var enemy_hp_bar: ProgressBar = $Panel/Margin/VBox/EnemyRow/EnemyInfo/EnemyHPBar
@onready var enemy_hp_label: Label = $Panel/Margin/VBox/EnemyRow/EnemyInfo/EnemyHPBar/EnemyHPLabel
@onready var player_hp_bar: ProgressBar = $Panel/Margin/VBox/PlayerRow/PlayerHPBar
@onready var player_hp_label: Label = $Panel/Margin/VBox/PlayerRow/PlayerHPBar/PlayerHPLabel
@onready var player_mp_bar: ProgressBar = $Panel/Margin/VBox/PlayerRow/PlayerMPBar
@onready var player_mp_label: Label = $Panel/Margin/VBox/PlayerRow/PlayerMPBar/PlayerMPLabel
@onready var log_label: Label = $Panel/Margin/VBox/LogPanel/LogLabel
@onready var attack_btn: Button = $Panel/Margin/VBox/Commands/AttackBtn
@onready var spell_btn: Button = $Panel/Margin/VBox/Commands/SpellBtn
@onready var defend_btn: Button = $Panel/Margin/VBox/Commands/DefendBtn
@onready var run_btn: Button = $Panel/Margin/VBox/Commands/RunBtn

func _ready() -> void:
	panel.visible = false
	Combat.changed.connect(_refresh)
	Character.changed.connect(_refresh)
	attack_btn.pressed.connect(Combat.player_attack)
	spell_btn.pressed.connect(Combat.player_cast_spell)
	defend_btn.pressed.connect(Combat.player_defend)
	run_btn.pressed.connect(Combat.player_run)

func _refresh() -> void:
	panel.visible = Combat.in_combat
	if not Combat.in_combat:
		return

	var enemy: Dictionary = Combat.current_enemy
	enemy_sprite.texture = load(enemy.sprite)
	enemy_name_label.text = enemy.name
	enemy_hp_bar.max_value = enemy.max_hp
	enemy_hp_bar.value = enemy.hp
	enemy_hp_label.text = "%d / %d" % [enemy.hp, enemy.max_hp]

	var stats: Dictionary = Character.stats
	player_hp_bar.max_value = stats.max_hp
	player_hp_bar.value = stats.hp
	player_hp_label.text = "HP: %d / %d" % [stats.hp, stats.max_hp]
	player_mp_bar.max_value = stats.max_mp
	player_mp_bar.value = stats.mp
	player_mp_label.text = "MP: %d / %d" % [stats.mp, stats.max_mp]

	spell_btn.disabled = stats.mp < Combat.SPELL_MP_COST

	var text := ""
	for i in range(Combat.battle_log.size()):
		if i > 0:
			text += "\n"
		text += Combat.battle_log[i]
	log_label.text = text
