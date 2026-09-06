extends StaticBody2D
# A fixed, much-stronger enemy standing in the dungeon - walk up, press E,
# same proximity convention as every other interactable. Unlike a random
# encounter, this is a deliberate one-time checkpoint: once beaten
# (GameState.boss_defeated[boss_id]), it stays beaten for the session and
# the tile becomes an inert, dimmed landmark rather than being removed.

const ALIVE_TINT := Color(0.55, 0.35, 0.75, 1.0) # the placeholder skeleton's purple (bosses without art yet)
const DEFEATED_TINT := Color(0.4, 0.4, 0.4, 1.0)
# Painted boss art (assets/enemies/art/<boss_id>.png, see Enemies.is_art):
# drawn smooth at a fixed height - bigger than any wild monster - with the
# feet FEET_DROP below the node and the interact area covering the figure
# (same grounding maths as wild_monster.gd).
const ART_HEIGHT := 92.0
const FEET_DROP := 10.0
const INTERACT_MARGIN := 24.0

@export var boss_id := "dungeon_boss"

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea

var _player_inside := false
var _sleep_marker: SleepMarker
var _art := false
var _flashing := false
var flashes := 0 # blinks played so far (the boss room reveal's "there it is")
const FLASH_TINT := Color(2.5, 2.5, 2.5, 1.0)

func _ready() -> void:
	var def: Dictionary = Enemies.BOSSES.get(boss_id, {})
	_art = not def.is_empty() and Enemies.is_art(def.sprite)
	if _art:
		var tex: Texture2D = load(def.sprite)
		sprite.texture = tex
		var tex_size: Vector2 = tex.get_size()
		var scale_f: float = float(def.get("art_height", ART_HEIGHT)) / tex_size.y
		sprite.scale = Vector2(scale_f, scale_f)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.offset = Vector2(0.0, FEET_DROP / scale_f - tex_size.y / 2.0)
		var shape := RectangleShape2D.new()
		shape.size = tex_size * scale_f + Vector2(INTERACT_MARGIN, INTERACT_MARGIN) * 2.0
		interact_area.get_node("CollisionShape2D").shape = shape
		interact_area.position = sprite.offset * scale_f
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

# The tint a living boss wears: none for painted art, the placeholder purple otherwise.
func alive_tint() -> Color:
	return Color.WHITE if _art else ALIVE_TINT

# A few bright blinks (the maze's boss room reveal). Instant under Combat.fast.
func flash(count: int, duration: float) -> void:
	_flashing = true
	for i in range(count):
		sprite.modulate = FLASH_TINT
		flashes += 1
		if not Combat.fast:
			await get_tree().create_timer(duration).timeout
		sprite.modulate = alive_tint()
		if not Combat.fast:
			await get_tree().create_timer(duration).timeout
		if not is_inside_tree():
			return
	_flashing = false

func _process(_delta: float) -> void:
	var defeated: bool = GameState.boss_defeated.get(boss_id, false)
	if not _flashing:
		sprite.modulate = DEFEATED_TINT if defeated else alive_tint()
	_sleep_marker.visible = defeated
	if _player_inside and not defeated and not Combat.in_combat and not GameState.interact_blocked() and Input.is_action_just_pressed("interact"):
		Combat.start_boss_fight(boss_id)
