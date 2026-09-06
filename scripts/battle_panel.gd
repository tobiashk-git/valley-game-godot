extends CanvasLayer
# Autoload — the battle screen (UI redesign, combat pass). Visibility mirrors
# Combat.in_combat. A framed STAGE shows up to 3 enemies at 96px with name
# and HP bar; while Combat.selecting_target is set the stage says "Choose a
# target", alive slots wear a gold frame and a tap on one calls
# Combat.select_target(index). The LOG keeps the last few lines with the
# newest bright and older ones dimmed. COMMANDS are styled kit buttons
# (Attack gold); Magic/Item open the SUBMENU of kit rows (icon + name +
# cost, Back) in place of the command row. Damage and healing float up as
# numbers over the enemy hit (the player's own show on the HUD, hud.gd),
# and a hit flashes the sprite. The player's HP/MP live in the HUD, which
# stays uncovered (this panel starts below it).

const MAX_ENEMY_SLOTS := 3
const HIT_FLASH := Color(1.0, 0.45, 0.45)

@onready var panel: Panel = $Panel
@onready var stage: PanelContainer = $Panel/Margin/VBox/Stage
@onready var target_hint: Label = $Panel/Margin/VBox/Stage/StageBox/TargetHint
@onready var enemies_row: HBoxContainer = $Panel/Margin/VBox/Stage/StageBox/EnemiesRow
@onready var enemy_slots: Array = []
@onready var log_panel: PanelContainer = $Panel/Margin/VBox/LogPanel
@onready var log_label: RichTextLabel = $Panel/Margin/VBox/LogPanel/LogMargin/LogLabel
@onready var commands: HBoxContainer = $Panel/Margin/VBox/Commands
@onready var attack_btn: Button = $Panel/Margin/VBox/Commands/AttackBtn
@onready var magic_btn: Button = $Panel/Margin/VBox/Commands/MagicBtn
@onready var item_btn: Button = $Panel/Margin/VBox/Commands/ItemBtn
@onready var defend_btn: Button = $Panel/Margin/VBox/Commands/DefendBtn
@onready var run_btn: Button = $Panel/Margin/VBox/Commands/RunBtn
@onready var submenu: VBoxContainer = $Panel/Margin/VBox/Submenu
# Shown in the commands' place once the fight is won: the screen holds on
# the victory summary until it's pressed (user feedback: the loot line used
# to vanish with the panel before it could be read).
var continue_btn: Button

var narrow := false
# Per-slot last known HP, to turn a change into a floating number.
var _last_hp: Array = []
var _target_style: StyleBoxFlat
var _empty_style := StyleBoxEmpty.new()

func _ready() -> void:
	panel.visible = false
	for i in range(MAX_ENEMY_SLOTS):
		var slot: Control = enemies_row.get_node("EnemySlot%d" % i)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		enemy_slots.append(slot)
	_target_style = StyleBoxFlat.new()
	_target_style.bg_color = Color(0.7, 0.55, 0.2, 0.18)
	_target_style.border_color = Color(1.0, 0.85, 0.4)
	_target_style.set_border_width_all(2)
	_target_style.set_corner_radius_all(6)
	Combat.changed.connect(_refresh)
	Character.changed.connect(_refresh)
	Layout.changed.connect(_apply_layout)
	_apply_layout()
	# A tap on the message (or E, see _process) hurries the current beat.
	log_panel.gui_input.connect(_on_log_gui_input)
	attack_btn.pressed.connect(Combat.player_attack)
	magic_btn.pressed.connect(Combat.open_magic_menu)
	item_btn.pressed.connect(Combat.open_item_menu)
	defend_btn.pressed.connect(Combat.player_defend)
	run_btn.pressed.connect(Combat.player_run)
	continue_btn = Button.new()
	continue_btn.name = "ContinueBtn"
	continue_btn.text = "Continue"
	continue_btn.theme_type_variation = &"PrimaryButton"
	continue_btn.custom_minimum_size = Vector2(0, 48)
	continue_btn.add_theme_font_size_override("font_size", 17)
	continue_btn.visible = false
	continue_btn.pressed.connect(Combat.finish_combat)
	commands.get_parent().add_child(continue_btn)
	commands.get_parent().move_child(continue_btn, commands.get_index() + 1)

# 560x420 centred-anchored at y=164 on the 800x600 base; on a phone it
# spans the width minus a 12px margin, sprites shrink a step and the
# command font drops so five buttons share the row.
func _apply_layout() -> void:
	narrow = Layout.is_narrow()
	var w: float = Layout.width - 24.0 if narrow else 560.0
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	# y=164..584 on the 800x600 base: under the HUD column (which ends by
	# ~y=160 with a two-line biome name and the XP bar), inside the viewport.
	panel.offset_top = -136.0
	panel.offset_bottom = 284.0
	for btn in [attack_btn, magic_btn, item_btn, defend_btn, run_btn]:
		btn.add_theme_font_size_override("font_size", 13 if narrow else 16)
		btn.custom_minimum_size = Vector2(0, 44 if narrow else 48)
	var sprite_px: float = 80.0 if narrow else 96.0
	for slot in enemy_slots:
		slot.get_node("Box/Sprite").custom_minimum_size = Vector2(sprite_px, sprite_px)
		slot.get_node("Box/BarBox/HPBar").custom_minimum_size = Vector2(96 if narrow else 120, 16)

func _on_log_gui_input(event: InputEvent) -> void:
	if not Combat.playing:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		Combat.skip_beat()

func _process(_delta: float) -> void:
	if Combat.in_combat and Input.is_action_just_pressed("interact"):
		if Combat.playing:
			Combat.skip_beat()
		elif Combat.awaiting_exit:
			Combat.finish_combat()

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Combat.select_target(index)
	elif event is InputEventScreenTouch and event.pressed:
		Combat.select_target(index)

func _refresh() -> void:
	panel.visible = Combat.in_combat
	if not Combat.in_combat:
		_last_hp = []
		return

	var targeting: bool = Combat.selecting_target != ""
	target_hint.modulate.a = 1.0 if targeting else 0.0
	var fresh: bool = _last_hp.size() != Combat.current_enemies.size()
	if fresh:
		_last_hp = []
		for enemy in Combat.current_enemies:
			_last_hp.append(enemy.hp if enemy != null else 0)
	for i in range(MAX_ENEMY_SLOTS):
		var slot: PanelContainer = enemy_slots[i]
		var enemy = Combat.current_enemies[i] if i < Combat.current_enemies.size() else null
		slot.visible = enemy != null
		if enemy == null:
			continue
		var sprite: TextureRect = slot.get_node("Box/Sprite")
		sprite.texture = load(enemy.sprite)
		# Painted art scales down smoothly; the old pixel sprites stay crisp.
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if Enemies.is_art(enemy.sprite) else CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = enemy.get("tint", Color(1, 1, 1, 1))
		slot.get_node("Box/NameLabel").text = enemy.name
		var hp_bar: ProgressBar = slot.get_node("Box/BarBox/HPBar")
		hp_bar.max_value = enemy.max_hp
		hp_bar.value = enemy.hp
		hp_bar.get_node("HPLabel").text = "%d / %d" % [enemy.hp, enemy.max_hp]
		slot.add_theme_stylebox_override("panel", _target_style if targeting else _empty_style)
		# A change since the last refresh floats up as a number.
		if not fresh and i < _last_hp.size() and enemy.hp != _last_hp[i]:
			_spawn_popup(sprite, enemy.hp - _last_hp[i])
			if enemy.hp < _last_hp[i]:
				_flash(sprite)
		if i < _last_hp.size():
			_last_hp[i] = enemy.hp

	# The message: the current beat big and bright, the two before it small
	# and dim above (so a result never gets lost in a scrolling log).
	var lines: Array = []
	var n: int = Combat.battle_log.size()
	for i in range(max(0, n - 3), n):
		var line: String = Combat.battle_log[i]
		if i == n - 1:
			lines.append("[font_size=%d][color=#ffffff]%s[/color][/font_size]" % [17 if narrow else 19, line])
		else:
			lines.append("[font_size=12][color=#8a8a8a]%s[/color][/font_size]" % line)
	log_label.text = "\n".join(lines)

	_refresh_submenu()

# "-7" in red rising and fading over the sprite (or "+5" in green).
func _spawn_popup(over: Control, delta: int) -> void:
	if delta < 0:
		Audio.play_sfx("hit")
	var label := Label.new()
	label.name = "DamagePopup"
	label.text = ("+%d" if delta > 0 else "%d") % delta
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.5) if delta > 0 else Color(1.0, 0.35, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 10
	var rect: Rect2 = over.get_global_rect()
	panel.add_child(label) # in the tree first, so global_position means what it says
	label.global_position = Vector2(rect.get_center().x - 20.0, rect.position.y + 8.0)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 44.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.tween_callback(label.queue_free)

func _flash(sprite: TextureRect) -> void:
	sprite.self_modulate = HIT_FLASH
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.35)

func _clear_submenu() -> void:
	for child in submenu.get_children():
		child.queue_free()

# One kit-style row: icon (capped at 24px), left-aligned text, 44px tall.
func _add_submenu_row(text: String, disabled: bool, on_pick: Callable, icon: Texture2D = null) -> void:
	var btn := Button.new()
	btn.text = text
	btn.icon = icon
	btn.add_theme_constant_override("icon_max_width", 24)
	btn.add_theme_constant_override("h_separation", 10)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 44)
	btn.theme_type_variation = &"SecondaryButton"
	btn.add_theme_font_size_override("font_size", 15)
	btn.disabled = disabled
	btn.pressed.connect(on_pick)
	submenu.add_child(btn)

func _refresh_submenu() -> void:
	# Commands (and the ability to open a submenu) are unavailable while a
	# target is being chosen - only tapping an enemy slot does anything then.
	var targeting: bool = Combat.selecting_target != ""
	var open: bool = Combat.active_submenu != "" and not targeting
	# While beats play the commands are gone - you wait the enemy's turn out.
	# Once the fight is won only Continue remains.
	commands.visible = not open and not targeting and not Combat.playing and not Combat.awaiting_exit
	continue_btn.visible = Combat.awaiting_exit
	# The submenu takes the log's space while it's open (its rows are taller
	# than the command row and would run out of the panel otherwise).
	log_panel.visible = not open
	submenu.visible = open
	submenu.size_flags_vertical = Control.SIZE_EXPAND_FILL if open else Control.SIZE_FILL
	if not open:
		return

	_clear_submenu()
	if Combat.active_submenu == "magic":
		for spell_id in Spells.SPELLS.keys():
			var spell: Dictionary = Spells.SPELLS[spell_id]
			var label := "%s (%d MP)" % [spell.name, spell.mp_cost]
			_add_submenu_row(label, Character.stats.mp < spell.mp_cost, Combat.cast_spell.bind(spell_id), Spells.get_spell_icon(spell_id))
	elif Combat.active_submenu == "item":
		var usable := false
		for item_id in Inventory.backpack.keys():
			if Items.is_usable(item_id) and Inventory.backpack[item_id] > 0:
				usable = true
				var label := "%s x%d" % [Items.get_item_name(item_id), Inventory.backpack[item_id]]
				_add_submenu_row(label, false, Combat.use_item.bind(item_id), Items.get_item_icon(item_id))
		if not usable:
			var empty_label := Label.new()
			empty_label.text = "No usable items."
			empty_label.theme_type_variation = &"DimLabel"
			submenu.add_child(empty_label)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.theme_type_variation = &"TabButton"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.pressed.connect(Combat.close_submenu)
	submenu.add_child(back_btn)
