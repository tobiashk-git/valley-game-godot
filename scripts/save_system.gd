extends Node
# Autoload (last) — save / load / new game. One JSON file per slot under
# user:// (the web export keeps user:// in the browser's persistent storage,
# so a save survives closing the tab). What's saved: GameState's progress
# flags, the backpack + gear instances (with enhancements) + the uid
# counter, stats + equipment, quest state / tracking / villagers met, chest
# contents, and where the player is (scene + position; maze interiors
# regenerate and use their own spawn). Never mid-fight.
#
# Autosave: on every scene change (two frames after, so the spawn override
# has been consumed) and, debounced, after anything that changes progress
# (quests, chests, fights ending, stats, inventory). On boot, a save in the
# AUTO slot is continued automatically (the title screen phase will put a
# New Game / Continue choice in front of this). Both are switched off in
# `--script` runs so verify scripts never read or write real saves.

signal saved(slot: String)
signal loaded(slot: String)

const AUTO_SLOT := "auto"
const SAVE_VERSION := 1
const DEBOUNCE_SECONDS := 2.0

var last_saved_unix := 0
var enabled := true # false in --script runs (see _ready)
var _dirty := false
var _dirty_since := 0.0
var _last_scene: Node = null
var _save_in_frames := -1
var _loading := false

func _ready() -> void:
	# A --script run (verify/builder scripts) attaches its script to the
	# SceneTree itself; the real game never does. (OS.get_cmdline_args()
	# doesn't list engine flags like --script, so it can't tell.)
	enabled = get_tree().get_script() == null
	Quests.changed.connect(_mark_dirty)
	Storage.changed.connect(_mark_dirty)
	Inventory.changed.connect(_mark_dirty)
	Character.changed.connect(_mark_dirty)
	Combat.ended.connect(func(_victory: bool) -> void: _mark_dirty())
	if enabled and has_save(AUTO_SLOT):
		_boot_continue()

func slot_path(slot: String) -> String:
	return "user://save_%s.json" % slot

func has_save(slot: String = AUTO_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot))

# --- snapshot / apply ---

static func _v2(v: Vector2) -> Array:
	return [v.x, v.y]

static func _to_v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() == 2 else Vector2.ZERO

static func _gear_out(inst: Dictionary) -> Dictionary:
	var mods: Array = []
	for m in inst.get("mods", []):
		mods.append({"id": m.id, "label": m.label, "kind": m.kind, "value": int(m.value)})
	return {"uid": int(inst.uid), "base": inst.base, "mods": mods}

static func _gear_in(d: Dictionary) -> Dictionary:
	var mods: Array = []
	for m in d.get("mods", []):
		mods.append({"id": str(m.id), "label": str(m.label), "kind": str(m.kind), "value": int(m.value)})
	return {"uid": int(d.uid), "base": str(d.base), "mods": mods}

static func _int_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[str(k)] = int(d[k])
	return out

func snapshot() -> Dictionary:
	var scene: Node = get_tree().current_scene
	var scene_path: String = scene.scene_file_path if scene != null and scene.scene_file_path != "" else "res://scenes/Overworld.tscn"
	var player: Node2D = scene.get_node_or_null("YSort/Player") if scene != null else null
	var gear: Array = []
	for inst in Inventory.gear:
		gear.append(_gear_out(inst))
	var equipment: Dictionary = {}
	for slot in Character.SLOTS:
		var inst: Dictionary = Character.equipped(slot)
		equipment[slot] = _gear_out(inst) if not inst.is_empty() else {}
	var chests: Dictionary = {}
	for storage_id in Storage.storages.keys():
		chests[storage_id] = _int_dict(Storage.storages[storage_id])
	var chest_gear: Dictionary = {}
	for storage_id in Storage.gear_storages.keys():
		var list: Array = []
		for inst in Storage.gear_storages[storage_id]:
			list.append(_gear_out(inst))
		chest_gear[storage_id] = list
	return {
		"version": SAVE_VERSION,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"scene": scene_path,
		"position": _v2(player.position) if player != null else [0, 0],
		"game_state": {
			"boss_defeated": GameState.boss_defeated.duplicate(),
			"wild_monsters_defeated": GameState.wild_monsters_defeated.duplicate(),
			"village_gates_open": GameState.village_gates_open,
			"discovered_pois": GameState.discovered_pois.duplicate(),
			"world_progress": GameState.world_progress.duplicate(),
			"biome_paths_open": GameState.biome_paths_open.duplicate(),
		},
		"inventory": {"backpack": _int_dict(Inventory.backpack), "gear": gear, "next_uid": Inventory._next_uid},
		"character": {"stats": _int_dict(Character.stats), "equipment": equipment},
		"quests": {"state": Quests.quest_state.duplicate(), "npcs_met": Quests.npcs_met.duplicate(), "tracked": Array(Quests.tracked_quests)},
		"storage": {"items": chests, "gear": chest_gear},
	}

# Restores every autoload's state from a snapshot (not the scene - see
# load_game() / _boot_continue() for that). Emits the change signals so the
# HUD, sheet and tracker redraw.
func apply(data: Dictionary) -> void:
	_loading = true
	var gs: Dictionary = data.get("game_state", {})
	for key in ["boss_defeated", "wild_monsters_defeated", "discovered_pois", "world_progress", "biome_paths_open"]:
		if gs.has(key):
			var target: Dictionary = GameState.get(key)
			for k in gs[key].keys():
				target[k] = gs[key][k]
	GameState.village_gates_open = bool(gs.get("village_gates_open", false))

	var inv: Dictionary = data.get("inventory", {})
	Inventory.backpack = _int_dict(inv.get("backpack", {}))
	Inventory.gear = []
	for d in inv.get("gear", []):
		Inventory.gear.append(_gear_in(d))
	Inventory._next_uid = int(inv.get("next_uid", 1))

	var ch: Dictionary = data.get("character", {})
	for k in ch.get("stats", {}).keys():
		Character.stats[k] = int(ch.stats[k])
	for slot in Character.SLOTS:
		var d = ch.get("equipment", {}).get(slot, {})
		Character.equipment[slot] = _gear_in(d) if d is Dictionary and not d.is_empty() else {}

	var q: Dictionary = data.get("quests", {})
	Quests.quest_state = q.get("state", {}).duplicate()
	Quests.npcs_met = q.get("npcs_met", {}).duplicate()
	Quests.tracked_quests.clear()
	for id in q.get("tracked", []):
		Quests.tracked_quests.append(str(id))

	var st: Dictionary = data.get("storage", {})
	Storage.storages = {}
	for storage_id in st.get("items", {}).keys():
		Storage.storages[storage_id] = _int_dict(st.items[storage_id])
	Storage.gear_storages = {}
	for storage_id in st.get("gear", {}).keys():
		var list: Array = []
		for d in st.gear[storage_id]:
			list.append(_gear_in(d))
		Storage.gear_storages[storage_id] = list
	if not Storage.storages.has("house_chest"):
		Storage.storages["house_chest"] = {}

	Combat.player_status.clear()
	last_saved_unix = int(data.get("saved_unix", 0))
	_loading = false
	Inventory.changed.emit()
	Character.changed.emit()
	Quests.changed.emit()
	Storage.changed.emit()

# --- save / load / new ---

func save_game(slot: String = AUTO_SLOT) -> bool:
	if Combat.in_combat or _loading:
		return false
	var data: Dictionary = snapshot()
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: cannot write %s" % slot_path(slot))
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	last_saved_unix = data.saved_unix
	_dirty = false
	saved.emit(slot)
	return true

func read_save(slot: String = AUTO_SLOT) -> Dictionary:
	if not has_save(slot):
		return {}
	var text: String = FileAccess.get_file_as_string(slot_path(slot))
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

# Restores the state and travels to the saved scene/position (the target
# scene consumes the spawn override in its own _ready(), as fast travel
# does; maze interiors ignore it and use their own spawn).
func load_game(slot: String = AUTO_SLOT) -> bool:
	var data: Dictionary = read_save(slot)
	if data.is_empty():
		return false
	if Combat.in_combat:
		Combat.in_combat = false
	apply(data)
	GameState.set_next_spawn(_to_v2(data.get("position", [0, 0])))
	get_tree().change_scene_to_file(str(data.get("scene", "res://scenes/Overworld.tscn")))
	_last_scene = null # the scene-change autosave will fire for the new scene
	loaded.emit(slot)
	return true

func delete_save(slot: String = AUTO_SLOT) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))

# Fresh start: every autoload back to its defaults, the auto slot removed,
# and the overworld loaded at its default spawn.
func new_game() -> void:
	delete_save(AUTO_SLOT)
	GameState.reset()
	Inventory.reset()
	Character.reset()
	Quests.reset()
	Storage.reset()
	Combat.reset()
	last_saved_unix = 0
	_dirty = false
	get_tree().change_scene_to_file("res://scenes/Overworld.tscn")
	_last_scene = null

func _boot_continue() -> void:
	var data: Dictionary = read_save(AUTO_SLOT)
	if data.is_empty():
		return
	apply(data)
	var scene: String = str(data.get("scene", "res://scenes/Overworld.tscn"))
	var pos: Vector2 = _to_v2(data.get("position", [0, 0]))
	if scene == "res://scenes/Overworld.tscn":
		# The main scene IS the overworld and hasn't run its _ready() yet -
		# it will consume this spawn on its own.
		GameState.set_next_spawn(pos)
	else:
		# Let the main scene come up, then travel (deferred: after its
		# _ready(), which would otherwise consume the override itself).
		_travel_deferred.call_deferred(scene, pos)

func _travel_deferred(scene: String, pos: Vector2) -> void:
	GameState.set_next_spawn(pos)
	get_tree().change_scene_to_file(scene)

# --- autosave ---

func _mark_dirty() -> void:
	if _loading:
		return
	if not _dirty:
		_dirty_since = Time.get_ticks_msec() / 1000.0
	_dirty = true

func saved_ago_text() -> String:
	if last_saved_unix == 0:
		return "Not saved yet"
	var ago: int = int(Time.get_unix_time_from_system()) - last_saved_unix
	if ago < 60:
		return "Saved just now"
	if ago < 3600:
		return "Saved %d min ago" % int(ago / 60)
	return "Saved %d h ago" % int(ago / 3600)

func _process(_delta: float) -> void:
	if not enabled:
		return
	var scene: Node = get_tree().current_scene
	if scene != _last_scene and scene != null:
		_last_scene = scene
		_save_in_frames = 2
	if _save_in_frames > 0:
		_save_in_frames -= 1
		if _save_in_frames == 0 and not Combat.in_combat:
			save_game(AUTO_SLOT)
	elif _dirty and not Combat.in_combat and Time.get_ticks_msec() / 1000.0 - _dirty_since >= DEBOUNCE_SECONDS:
		save_game(AUTO_SLOT)
