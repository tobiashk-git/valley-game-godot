extends StaticBody2D
# A fixed, much-stronger enemy standing in the dungeon - walk up, press E,
# same proximity convention as every other interactable. Unlike a random
# encounter, this is a deliberate one-time checkpoint: once beaten
# (GameState.boss_defeated[boss_id]), it stays beaten for the session and
# the tile becomes an inert, dimmed landmark rather than being removed.

const ALIVE_TINT := Color(0.55, 0.35, 0.75, 1.0) # keep in sync with enemies.gd's BOSSES tint
const DEFEATED_TINT := Color(0.4, 0.4, 0.4, 1.0)

@export var boss_id := "dungeon_boss"

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea

var _player_inside := false
var _sleep_marker: SleepMarker

func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	# A beaten boss sleeps for good (a story gate); "z z Z" says so.
	var top: float = sprite.position.y + sprite.get_rect().position.y * sprite.scale.y if sprite.texture else -40.0
	_sleep_marker = SleepMarker.attach(self, top - 26.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	var defeated: bool = GameState.boss_defeated.get(boss_id, false)
	sprite.modulate = DEFEATED_TINT if defeated else ALIVE_TINT
	_sleep_marker.visible = defeated
	if _player_inside and not defeated and not Combat.in_combat and not GameState.interact_blocked() and Input.is_action_just_pressed("interact"):
		Combat.start_boss_fight(boss_id)
