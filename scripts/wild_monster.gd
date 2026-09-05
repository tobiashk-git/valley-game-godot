extends StaticBody2D
# A static, visible, farmable overworld monster - walk up, press E, same
# proximity convention as every other interactable (modeled directly on
# boss.gd, which this scene reuses the exact node shape of). Unlike Boss.tscn,
# one WildMonster.tscn instance needs to represent any of 12 different
# species across 5 shared sprite files, so nothing is baked into the scene at
# design time - the sprite texture, tint, scale, grounding offset AND the
# interact area's size are all applied here at runtime from `enemy_id`. Once
# beaten it stays beaten for the session (no respawn yet - see
# World.scatter_wild_monsters()'s header comment) and dims in place, same
# "inert landmark" treatment as a defeated boss.

# Half of Boss.tscn's 1.6x - these are farmable critters, not bosses, and at
# full boss size a 64px skeleton/spider became a ~102px sprite that dwarfed
# the player (user feedback after the first playtest).
const SPRITE_SCALE := 0.8
const ART_HEIGHT := 44.0 # default on-screen height of a painted creature (assets/enemies/art); a def's "art_height" overrides
# World px the sprite's bottom edge sits below the body centre, so the
# monster visibly stands ON its tile rather than floating above it (the
# boss's fixed -35.2 offset left the feet ~5px ABOVE the body at 1.6x).
const FEET_DROP := 10.0
# Slack added around the VISIBLE sprite on every side when sizing the
# InteractArea - covers the player's 10px half-width plus a few px of "I
# stopped just short of touching it".
const INTERACT_MARGIN := 24.0

@export var enemy_id := ""
@export var zone := -1 # a World.Zone value, passed through to Combat.start_wild_encounter()
@export var placement_key := "" # "<tile_x>_<tile_y>" - set by whoever instances this, see World.scatter_wild_monsters()

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var interact_shape: CollisionShape2D = $InteractArea/CollisionShape2D

var _player_inside := false
var _sleep_marker: SleepMarker

func _ready() -> void:
	var def: Dictionary = Enemies.ENEMIES[enemy_id]
	var tex: Texture2D = load(def.sprite)
	sprite.texture = tex
	var tex_size: Vector2 = tex.get_size()
	# Painted art (assets/enemies/art) is a ~256px illustration: draw it
	# smooth at a fixed on-screen height; the pixel placeholders keep their
	# fixed pixel scale.
	var art: bool = Enemies.is_art(def.sprite)
	var art_height: float = float(def.get("art_height", ART_HEIGHT))
	var scale_f: float = art_height / tex_size.y if art else SPRITE_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if art else CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(scale_f, scale_f)
	# Sprite2D.offset is in texture px and gets scaled with the node, so the
	# grounding maths works in texture space then lets the scale apply.
	sprite.offset = Vector2(0.0, FEET_DROP / scale_f - tex_size.y / 2.0)

	# The InteractArea has to cover the VISIBLE sprite, not just the 28x28
	# blocking collider at its feet: a real player walks up until their own
	# sprite touches the monster's and presses E right there, from whatever
	# side they came. With the scene's baked 48x48 area centred on the feet,
	# that press only ever landed from the south (the one side where the
	# blocking collider stops you inside the area) - east/west/north all left
	# the player 40-120px outside it, which read as "can't interact at all".
	# Per-instance shape (not the scene's shared SubResource) since every
	# species' sprite is a different size.
	var visual_size: Vector2 = tex_size * scale_f
	var visual_center: Vector2 = sprite.offset * scale_f
	var shape := RectangleShape2D.new()
	shape.size = visual_size + Vector2(INTERACT_MARGIN, INTERACT_MARGIN) * 2.0
	interact_shape.shape = shape
	interact_area.position = visual_center

	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	# "z z Z" just above the drawn sprite while it sleeps.
	_sleep_marker = SleepMarker.attach(self, visual_center.y - visual_size.y / 2.0 - 26.0)

func is_asleep() -> bool:
	return GameState.is_wild_monster_asleep(placement_key)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	var def: Dictionary = Enemies.ENEMIES[enemy_id]
	var base_tint: Color = def.get("tint", Color(1, 1, 1, 1))
	var defeated: bool = is_asleep()
	_sleep_marker.visible = defeated
	# Darkens the species' own tint rather than boss.gd's flat grey, so a
	# defeated Ice Wraith still reads faintly blue instead of every dead
	# placement collapsing to the same look - darkened(0.55) lands at roughly
	# the same alive->dead contrast boss.gd's own two flat tints have.
	sprite.modulate = base_tint.darkened(0.55) if defeated else base_tint
	if _player_inside and not defeated and not Combat.in_combat and not GameState.interact_blocked() and Input.is_action_just_pressed("interact"):
		Combat.start_wild_encounter(enemy_id, zone, placement_key)
