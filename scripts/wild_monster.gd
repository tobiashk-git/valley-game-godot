extends StaticBody2D
# A static, visible, farmable overworld monster - walk up, press E, same
# proximity convention as every other interactable (modeled directly on
# boss.gd, which this scene reuses the exact node shape of). Unlike Boss.tscn,
# one WildMonster.tscn instance needs to represent any of 12 different
# species across 5 shared sprite files, so nothing is baked into the scene at
# design time - the sprite texture and tint are both applied here at runtime
# from `enemy_id`. Once beaten it stays beaten for the session (no respawn
# yet - see World.scatter_wild_monsters()'s header comment) and dims in
# place, same "inert landmark" treatment as a defeated boss.

@export var enemy_id := ""
@export var zone := -1 # a World.Zone value, passed through to Combat.start_wild_encounter()
@export var placement_key := "" # "<tile_x>_<tile_y>" - set by whoever instances this, see World.scatter_wild_monsters()

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea

var _player_inside := false

func _ready() -> void:
	var def: Dictionary = Enemies.ENEMIES[enemy_id]
	sprite.texture = load(def.sprite)
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	var def: Dictionary = Enemies.ENEMIES[enemy_id]
	var base_tint: Color = def.get("tint", Color(1, 1, 1, 1))
	var defeated: bool = GameState.wild_monsters_defeated.get(placement_key, false)
	# Darkens the species' own tint rather than boss.gd's flat grey, so a
	# defeated Ice Wraith still reads faintly blue instead of every dead
	# placement collapsing to the same look - darkened(0.55) lands at roughly
	# the same alive->dead contrast boss.gd's own two flat tints have.
	sprite.modulate = base_tint.darkened(0.55) if defeated else base_tint
	if _player_inside and not defeated and not Combat.in_combat and Input.is_action_just_pressed("interact"):
		Combat.start_wild_encounter(enemy_id, zone, placement_key)
