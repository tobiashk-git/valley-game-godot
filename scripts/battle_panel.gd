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
# Companions (Combat.COMPANIONS): a row of bust buttons above the commands,
# hidden until they are unlocked, each dimmed once its charge is spent. The
# called companion's figure pops in at the right end of the message box
# (the cameo - beside its own lines, clear of the enemy slots), shakes on
# its blow like an enemy's strike cue, and stays while it tanks: a small HP
# bar above it drains as the enemies hit it, then it pops out.
var companion_row: HBoxContainer
var companion_btns: Dictionary = {} # id -> Button (bust icon)
var cameo: TextureRect
var cameo_bar: ProgressBar
var cameo_id := ""
var _cameo_tween: Tween

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
	Combat.enemy_turn_started.connect(_on_enemy_turn_started)
	Combat.enemy_struck.connect(_on_enemy_struck)
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
	_build_companions()

func _build_companions() -> void:
	companion_row = HBoxContainer.new()
	companion_row.name = "CompanionRow"
	companion_row.add_theme_constant_override("separation", 8)
	companion_row.visible = false
	commands.get_parent().add_child(companion_row)
	commands.get_parent().move_child(companion_row, commands.get_index())
	var caption := Label.new()
	caption.name = "Caption"
	caption.text = "Companions"
	caption.add_theme_font_size_override("font_size", 12)
	caption.modulate = Color(1, 1, 1, 0.6)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	companion_row.add_child(caption)
	for id in Combat.COMPANIONS.keys():
		var def: Dictionary = Combat.COMPANIONS[id]
		# A kit button carrying just the bust, so it reads as a command.
		var btn := Button.new()
		btn.name = "%sBtn" % id.capitalize()
		btn.theme_type_variation = &"SecondaryButton"
		btn.custom_minimum_size = Vector2(60, 44)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_constant_override("icon_max_width", 36)
		if ResourceLoader.exists(def.portrait):
			btn.icon = load(def.portrait)
		btn.tooltip_text = "%s - %s" % [def.name, def.move]
		btn.pressed.connect(Combat.open_companion_menu.bind(id)) # the two-move menu
		companion_row.add_child(btn)
		companion_btns[id] = btn
	cameo = TextureRect.new()
	cameo.name = "Cameo"
	cameo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cameo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cameo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	cameo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cameo.z_index = 5
	cameo.visible = false
	panel.add_child(cameo)
	cameo_bar = ProgressBar.new()
	cameo_bar.name = "CameoBar"
	cameo_bar.theme_type_variation = &"HPBar"
	cameo_bar.show_percentage = false
	cameo_bar.custom_minimum_size = Vector2(64, 14)
	cameo_bar.size = Vector2(64, 14)
	cameo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cameo_bar.z_index = 6
	cameo_bar.visible = false
	var bar_label := Label.new()
	bar_label.name = "HPLabel"
	bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_label.add_theme_font_size_override("font_size", 11)
	bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cameo_bar.add_child(bar_label)
	panel.add_child(cameo_bar)
	Combat.companion_called.connect(_on_companion_called)
	Combat.companion_struck.connect(_on_companion_struck)
	Combat.companion_hit.connect(_on_companion_hit)
	Combat.companion_left.connect(_on_companion_left)

func _refresh_companions() -> void:
	companion_row.visible = Combat.in_combat and commands.visible and not Combat.companion_charges.is_empty()
	if not Combat.in_combat and cameo_id != "":
		cameo_id = ""
		cameo.visible = false
	for id in companion_btns.keys():
		var btn: Button = companion_btns[id]
		btn.visible = Combat.companion_charges.has(id) # only those who came along
		var ready: bool = Combat.companion_ready(id)
		btn.disabled = not ready
		btn.modulate = Color.WHITE if ready else Color(0.45, 0.45, 0.45, 1.0)
		var charges: int = Combat.companion_charges.get(id, 0)
		btn.text = "x%d" % charges if charges > 1 else "" # more than one call this fight
	# The cameo stays while its companion tanks, and through its own round
	# (and a bite's target pick) in any case.
	if cameo_id != "" and Combat.companion_active != cameo_id and not Combat.playing and Combat.selecting_target != "bite":
		_cameo_out()
	if cameo_id != "":
		cameo_bar.max_value = max(1, Combat.companion_max_hp)
		cameo_bar.value = Combat.companion_hp
		cameo_bar.get_node("HPLabel").text = "%d / %d" % [Combat.companion_hp, Combat.companion_max_hp]

# The called companion springs onto the stage.
func _on_companion_called(id: String) -> void:
	var def: Dictionary = Combat.COMPANIONS[id]
	if not ResourceLoader.exists(def.sprite):
		return
	if _cameo_tween != null and _cameo_tween.is_valid():
		_cameo_tween.kill()
	cameo_id = id
	var tex: Texture2D = load(def.sprite)
	cameo.texture = tex
	var h: float = 72.0 if narrow else 84.0
	var w: float = h * tex.get_width() / max(1.0, float(tex.get_height()))
	cameo.size = Vector2(w, h)
	cameo.pivot_offset = Vector2(w / 2.0, h)
	var rect: Rect2 = log_panel.get_global_rect()
	cameo.global_position = Vector2(rect.end.x - w - 10.0, rect.end.y - h - 6.0)
	cameo.rotation = 0.0
	cameo.self_modulate = Color.WHITE
	cameo.scale = Vector2(0.2, 0.2)
	cameo.visible = true
	cameo_bar.global_position = Vector2(cameo.global_position.x + (w - cameo_bar.size.x) / 2.0, cameo.global_position.y - cameo_bar.size.y - 2.0)
	cameo_bar.visible = true
	_refresh_companions()
	_cameo_tween = create_tween()
	_cameo_tween.tween_property(cameo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# The blow: the same shake and flash an enemy gets.
func _on_companion_struck(id: String) -> void:
	if cameo_id != id or not cameo.visible:
		return
	if _cameo_tween != null and _cameo_tween.is_valid():
		_cameo_tween.kill()
	cameo.scale = Vector2.ONE
	cameo.self_modulate = STRIKE_FLASH
	_cameo_tween = create_tween()
	_cameo_tween.tween_property(cameo, "rotation", -0.12, 0.05)
	_cameo_tween.tween_property(cameo, "rotation", 0.12, 0.07)
	_cameo_tween.tween_property(cameo, "rotation", -0.08, 0.06)
	_cameo_tween.tween_property(cameo, "rotation", 0.06, 0.06)
	_cameo_tween.tween_property(cameo, "rotation", 0.0, 0.06)
	_cameo_tween.parallel().tween_property(cameo, "self_modulate", Color.WHITE, 0.45)

# An enemy blow on the tank: the number floats up and the figure flashes.
func _on_companion_hit(id: String, damage: int) -> void:
	if cameo_id != id or not cameo.visible:
		return
	_spawn_popup(cameo, -damage)
	_flash(cameo)

func _on_companion_left(id: String) -> void:
	if cameo_id == id:
		_cameo_out()

func _cameo_out() -> void:
	cameo_id = ""
	cameo_bar.visible = false
	if _cameo_tween != null and _cameo_tween.is_valid():
		_cameo_tween.kill()
	_cameo_tween = create_tween()
	_cameo_tween.tween_property(cameo, "scale", Vector2(0.2, 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_cameo_tween.tween_callback(func() -> void:
		if cameo_id == "":
			cameo.visible = false)

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
		_refresh_companions()
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

# --- who is acting (Combat.enemy_turn_started / enemy_struck) ---
# The figure sits in a container, which owns its position and size but not
# its rotation or scale - so the cues use those, around a centred pivot.
const WINDUP_SCALE := 1.1
const STRIKE_FLASH := Color(2.2, 2.0, 1.6, 1.0)
var acting_index := -1  # the slot winding up or striking, -1 between turns
var last_struck := -1
var _act_tween: Tween

func _acting_sprite(index: int) -> TextureRect:
	if index < 0 or index >= enemy_slots.size():
		return null
	return enemy_slots[index].get_node("Box/Sprite")

func _settle_acting() -> void:
	var prev: TextureRect = _acting_sprite(acting_index)
	if prev != null:
		prev.scale = Vector2.ONE
		prev.rotation = 0.0
		prev.self_modulate = Color.WHITE

# The wind-up: the figure leans in (scales up a touch, warms) and holds.
func _on_enemy_turn_started(index: int) -> void:
	if _act_tween != null and _act_tween.is_valid():
		_act_tween.kill()
	_settle_acting()
	acting_index = index
	var sprite: TextureRect = _acting_sprite(index)
	if sprite == null:
		return
	sprite.pivot_offset = sprite.size / 2.0
	_act_tween = create_tween()
	_act_tween.tween_property(sprite, "scale", Vector2.ONE * WINDUP_SCALE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_act_tween.parallel().tween_property(sprite, "self_modulate", Color(1.15, 1.05, 0.9, 1.0), 0.18)

# The blow: a sharp shake and a bright flash, then back to rest.
func _on_enemy_struck(index: int) -> void:
	if _act_tween != null and _act_tween.is_valid():
		_act_tween.kill()
	if index != acting_index:
		_settle_acting()
		acting_index = index
	last_struck = index
	Audio.play_sfx("swing") # the enemy's swing; the HUD adds the thud if it lands
	var sprite: TextureRect = _acting_sprite(index)
	if sprite == null:
		return
	sprite.pivot_offset = sprite.size / 2.0
	sprite.self_modulate = STRIKE_FLASH
	_act_tween = create_tween()
	_act_tween.tween_property(sprite, "rotation", -0.12, 0.05)
	_act_tween.tween_property(sprite, "rotation", 0.12, 0.07)
	_act_tween.tween_property(sprite, "rotation", -0.08, 0.06)
	_act_tween.tween_property(sprite, "rotation", 0.06, 0.06)
	_act_tween.tween_property(sprite, "rotation", 0.0, 0.06)
	_act_tween.parallel().tween_property(sprite, "self_modulate", Color.WHITE, 0.45)
	_act_tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.45).set_delay(0.2)
	_act_tween.tween_callback(func() -> void:
		if acting_index == index:
			acting_index = -1)

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
	btn.add_theme_font_size_override("font_size", 13 if narrow else 15)
	# A row never widens the submenu past the panel: a long label (the
	# companion moves' hints) is clipped instead (user, 2026-09-12: the
	# options spilled off the right of the phone).
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_refresh_companions()
	# The submenu takes the log's space while it's open (its rows are taller
	# than the command row and would run out of the panel otherwise).
	log_panel.visible = not open
	submenu.visible = open
	# The cameo lives over the message box, which the submenu replaces.
	if cameo_id != "":
		cameo.visible = not open
		cameo_bar.visible = not open
	submenu.size_flags_vertical = Control.SIZE_EXPAND_FILL if open else Control.SIZE_FILL
	if not open:
		return

	_clear_submenu()
	if Combat.active_submenu == "magic":
		for spell_id in Spells.SPELLS.keys():
			var spell: Dictionary = Spells.SPELLS[spell_id]
			var label := "%s (%d MP)" % [spell.name, spell.mp_cost]
			_add_submenu_row(label, Character.stats.mp < spell.mp_cost, Combat.cast_spell.bind(spell_id), Spells.get_spell_icon(spell_id))
	elif Combat.active_submenu.begins_with("companion:"):
		# The companion's two moves (Combat.COMPANION_MOVES), its bust on each.
		var cid: String = Combat.active_submenu.substr(10)
		var icon: Texture2D = companion_btns[cid].icon if companion_btns.has(cid) else null
		for move in Combat.COMPANION_MOVES[cid]:
			_add_submenu_row("%s - %s" % [move.name, move.hint], not Combat.companion_ready(cid), Combat.companion_act.bind(cid, move.id), icon)
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
