extends Control
# The character sheet's Journal tab (UI redesign Phase 3c; quest lines
# revamp phase 2, 2026-09-07). Two sub-tabs above the list:
#   Story - every chapter (Quests.CHAPTERS) as a section with its state,
#           the chapter's quests in chain order once they've been handed
#           out, plus the next step the moment it becomes available
#           ("See the Village Elder"), so the chain's shape shows;
#   Side  - side quests under Active / Completed, and a started chain's
#           next step under Available.
# Rows carry a "Step i/n" tag when they belong to a chain. Right (below, on
# a phone): the selected quest's giver, its place in the chain ("follows
# ...", "leads on to ..."), goal, progress, reward and a Track / Untrack
# button that pins it to the always-visible QuestTracker overlay (capped at
# Quests.MAX_TRACKED; completed and not-yet-accepted quests can't be tracked).
#
# Skeleton from tools/setup_character_sheet.gd (the sub-tab strip is added
# here in _ready()); character_sheet.gd calls apply_layout() and refresh()
# and owns open/close/tab switching.

@onready var list_scroll: ScrollContainer = $ListScroll
@onready var quest_list: VBoxContainer = $ListScroll/QuestList
@onready var detail_pane: Panel = $DetailPane
@onready var quest_name: Label = $DetailPane/QuestName
@onready var quest_giver: Label = $DetailPane/QuestGiver
@onready var quest_goal: RichTextLabel = $DetailPane/QuestGoal
@onready var quest_progress: RichTextLabel = $DetailPane/QuestProgress
@onready var quest_reward: Label = $DetailPane/QuestReward
@onready var track_btn: Button = $DetailPane/TrackBtn
@onready var hint_label: Label = $HintLabel

const ROW_HEIGHT := 50.0
const LINE_TAB_HEIGHT := 34.0
const LINES := ["story", "side"]
const LINE_LABELS := {"story": "Story", "side": "Side quests"}

var selected_quest := ""
var line_tab := "story"
var _row_width := 424.0
var line_tabs: HBoxContainer
var _line_buttons: Dictionary = {}

func _ready() -> void:
	track_btn.pressed.connect(_on_track_pressed)
	line_tabs = HBoxContainer.new()
	line_tabs.name = "LineTabs"
	line_tabs.add_theme_constant_override("separation", 6)
	add_child(line_tabs)
	for line in LINES:
		var b := Button.new()
		b.name = line.to_pascal_case() + "Tab"
		b.text = LINE_LABELS[line]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, LINE_TAB_HEIGHT)
		b.pressed.connect(show_line.bind(line))
		line_tabs.add_child(b)
		_line_buttons[line] = b
	_style_line_tabs()

func _style_line_tabs() -> void:
	for line in _line_buttons.keys():
		_line_buttons[line].theme_type_variation = &"TabButtonActive" if line == line_tab else &"TabButton"

func show_line(line: String) -> void:
	line_tab = line
	_style_line_tabs()
	selected_quest = ""
	refresh()

# --- layout (the sheet hides its header on this tab) ---

func _place(c: Control, pos: Vector2, size: Vector2) -> void:
	c.position = pos
	c.size = size

func apply_layout(narrow: bool, view_size: Vector2) -> void:
	var pane_h: float
	var list_top: float = LINE_TAB_HEIGHT + 6.0
	if not narrow:
		_row_width = 424.0
		_place(line_tabs, Vector2(20, 0), Vector2(424, LINE_TAB_HEIGHT))
		_place(list_scroll, Vector2(20, list_top), Vector2(424, 430 - list_top))
		pane_h = 430.0
		_place(detail_pane, Vector2(452, 0), Vector2(248, pane_h))
		hint_label.position = Vector2(20, 436)
		hint_label.visible = true
	else:
		var iw: float = view_size.x
		_row_width = iw - 40.0
		_place(line_tabs, Vector2(20, 0), Vector2(iw - 40.0, LINE_TAB_HEIGHT))
		var list_h := 4 * ROW_HEIGHT + 3 * 4.0 + 24.0
		_place(list_scroll, Vector2(20, list_top), Vector2(iw - 40.0, list_h))
		pane_h = maxf(200.0, view_size.y - list_top - list_h - 8.0 - 4.0)
		_place(detail_pane, Vector2(20, list_top + list_h + 8.0), Vector2(iw - 40.0, pane_h))
		hint_label.visible = false
	var pw: float = detail_pane.size.x
	_place(quest_name, Vector2(12, 10), Vector2(pw - 24.0, 44))
	_place(quest_giver, Vector2(12, 56), Vector2(pw - 24.0, 34))
	_place(quest_goal, Vector2(12, 92), Vector2(pw - 24.0, 60))
	_place(quest_progress, Vector2(12, 156), Vector2(pw - 24.0, 40))
	_place(quest_reward, Vector2(12, 200), Vector2(pw - 24.0, 36))
	_place(track_btn, Vector2(12, 244), Vector2(pw - 24.0, 40))

# --- which quests show ---

func _state(quest_id: String) -> String:
	return Quests.quest_state.get(quest_id, "")

# A quest shows once handed out, or as the announced next step of a chain
# whose previous step is done (never a chain's first step before it's
# accepted - that stays a discovery).
func _shows(quest_id: String) -> bool:
	if _state(quest_id) != "":
		return true
	var prev: String = Quests.prev_of(quest_id)
	return prev != "" and _state(prev) == "completed" and Quests.is_available(quest_id)

func _line_ids(line: String) -> Array:
	var out: Array = []
	for quest_id in Quests.QUEST_DEFS.keys():
		if Quests.line_of(quest_id) == line and _shows(quest_id):
			out.append(quest_id)
	return out

# Chain order: by first step, then step index.
func _chain_sorted(ids: Array) -> Array:
	var sorted: Array = ids.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool:
		var ca: String = Quests.chain_of(a)[0]
		var cb: String = Quests.chain_of(b)[0]
		if ca != cb:
			return ca < cb
		return Quests.step_of(a)[0] < Quests.step_of(b)[0]
	)
	return sorted

func _active_ids() -> Array:
	return _line_ids(line_tab).filter(func(id: String) -> bool: return _state(id) == "accepted")

func _completed_ids() -> Array:
	return _line_ids(line_tab).filter(func(id: String) -> bool: return _state(id) == "completed")

func _available_ids() -> Array:
	return _line_ids(line_tab).filter(func(id: String) -> bool: return _state(id) == "")

# --- text ---

# Status line for a row: live progress, ready, done, or where to pick it up.
func status_text(quest_id: String) -> String:
	if _state(quest_id) == "":
		return "See %s" % Quests.giver_label(quest_id)
	if _state(quest_id) == "completed":
		return "Completed"
	if Quests.objective_met(quest_id):
		return "Ready to turn in!"
	return Quests.objective_progress_text(quest_id)

# "Step 2 of 2" for a chained quest, "" for a single action.
func step_text(quest_id: String) -> String:
	var step: Array = Quests.step_of(quest_id)
	return "Step %d of %d" % [step[0], step[1]] if step[1] > 1 else ""

# The quest's neighbours in its chain, for the pane: what it follows and
# what it leads on to (the next step is named once it can be picked up).
func chain_text(quest_id: String) -> String:
	var parts: Array = []
	var step: String = step_text(quest_id)
	if step != "":
		parts.append(step)
	var prev: String = Quests.prev_of(quest_id)
	if prev != "":
		parts.append("follows %s" % Quests.QUEST_DEFS[prev].name)
	var nexts: Array = Quests.next_of(quest_id)
	if not nexts.is_empty():
		var nxt: String = nexts[0]
		var known: bool = _state(nxt) != "" or Quests.is_available(nxt)
		parts.append("leads on to %s" % (Quests.QUEST_DEFS[nxt].name if known else "..."))
	return "  -  ".join(parts)

# One sentence describing the objective, with inline item icons.
func goal_text(quest_id: String) -> String:
	var def: Dictionary = Quests.QUEST_DEFS[quest_id]
	var objective: Dictionary = def.objective
	if objective.has("goal"):
		return objective.goal
	var giver: String = def.get("giver_name", "")
	var to_giver: String = " and bring it to %s" % Quests.giver_label(quest_id) if giver != "" else ""
	if objective.type == "gather":
		return "Gather %d %s%s." % [objective.amount, Items.get_item_name_bbcode(objective.item_id), to_giver]
	if objective.type == "gather_multi":
		var parts: Array = []
		for entry in objective.items:
			parts.append("%d %s" % [entry.amount, Items.get_item_name_bbcode(entry.item_id)])
		return "Gather %s%s." % [" and ".join(parts), to_giver.replace("bring it", "bring them")]
	if objective.type == "talk_to_npcs":
		return "Talk to every villager (%d of them)." % objective.npc_ids.size()
	if objective.type == "defeat_bosses":
		return "Put %d boss%s to sleep." % [objective.boss_ids.size(), "" if objective.boss_ids.size() == 1 else "es"]
	return ""

func reward_text(quest_id: String) -> String:
	var reward: Dictionary = Quests.QUEST_DEFS[quest_id].get("reward", {})
	var parts: Array = []
	if reward.get("xp", 0) > 0:
		parts.append("%d XP" % reward.xp)
	if quest_id == "meet_villagers":
		parts.append("the village gates open")
	if reward.get("gold", 0) > 0:
		parts.append("%d gold" % reward.gold)
	if reward.has("item_id"):
		parts.append("%d %s" % [reward.get("item_amount", 1), Items.get_item_name(reward.item_id)])
	return "Reward: " + ", ".join(parts)

func chapter_title(chapter: Dictionary) -> String:
	var state: String = Quests.chapter_state(chapter.id)
	if state == "complete":
		return "%s  -  complete" % chapter.title
	if state == "in_progress":
		return "%s  -  in progress" % chapter.title
	return chapter.title

# --- selection ---

# Picks a sensible default on the current sub-tab: the selected quest if
# it's still listed, else the first active one, then available, then done.
func select_default() -> void:
	var ids: Array = _active_ids() + _available_ids() + _completed_ids()
	if not (selected_quest in ids):
		selected_quest = ids[0] if not ids.is_empty() else ""

func select_quest(quest_id: String) -> void:
	selected_quest = quest_id
	refresh()

# --- building the list ---

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.name = "Dying" + str(child.get_index())
		child.visible = false
		child.queue_free()

func _section(text: String, name_hint: String = "") -> void:
	var l := Label.new()
	if name_hint != "":
		l.name = name_hint
	l.text = text
	l.theme_type_variation = &"PanelTitle"
	l.add_theme_font_size_override("font_size", 14)
	quest_list.add_child(l)

func _dim_line(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"DimLabel"
	l.add_theme_font_size_override("font_size", 12)
	quest_list.add_child(l)

# A row is a tab-styled button with the name, a step tag and the status
# line laid over it (labels ignore the mouse so the tap reaches the button).
func _row(quest_id: String) -> void:
	var def: Dictionary = Quests.QUEST_DEFS[quest_id]
	var selected: bool = quest_id == selected_quest
	var pending: bool = _state(quest_id) == ""
	var ink := Color(0.1, 0.08, 0.04) if selected else (Color(0.62, 0.6, 0.55) if pending else Color(1, 1, 1))
	var btn := Button.new()
	btn.name = quest_id.to_pascal_case() + "Row"
	btn.custom_minimum_size = Vector2(_row_width, ROW_HEIGHT)
	btn.theme_type_variation = &"TabButtonActive" if selected else &"TabButton"
	btn.mouse_filter = Control.MOUSE_FILTER_PASS # a touch drag on a row scrolls the list (phone)
	btn.pressed.connect(select_quest.bind(quest_id))
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = def.name + ("   (tracked)" if Quests.is_tracked(quest_id) else "")
	name_label.position = Vector2(12, 6)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", ink)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_label)
	var step: String = step_text(quest_id)
	if step != "":
		var step_label := Label.new()
		step_label.name = "Step"
		step_label.text = step
		step_label.add_theme_font_size_override("font_size", 11)
		step_label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.04) if selected else Color(0.9, 0.75, 0.35))
		step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		step_label.position = Vector2(_row_width - 112.0, 8)
		step_label.size = Vector2(100, 16)
		step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(step_label)
	var status := RichTextLabel.new()
	status.name = "Status"
	status.bbcode_enabled = true
	status.fit_content = true
	status.scroll_active = false
	status.text = status_text(quest_id)
	status.position = Vector2(12, 26)
	status.size = Vector2(_row_width - 24.0, 22)
	status.add_theme_font_size_override("normal_font_size", 12)
	status.add_theme_color_override("default_color", Color(0.1, 0.08, 0.04) if selected else Color(0.7, 0.7, 0.7))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(status)
	quest_list.add_child(btn)

func _build_story() -> void:
	for chapter in Quests.CHAPTERS:
		_section(chapter_title(chapter), chapter.id.to_pascal_case() + "Chapter")
		var ids: Array = _chain_sorted(_line_ids("story").filter(func(id: String) -> bool: return Quests.chapter_of(id) == chapter.id))
		if ids.is_empty():
			_dim_line("    " + chapter.blurb)
		for quest_id in ids:
			_row(quest_id)

func _build_side() -> void:
	var active: Array = _chain_sorted(_active_ids())
	var available: Array = _chain_sorted(_available_ids())
	var completed: Array = _chain_sorted(_completed_ids())
	if active.is_empty() and available.is_empty() and completed.is_empty():
		_dim_line("(no side quests yet - the villagers will have work for you)")
	if not active.is_empty():
		_section("Active (%d)" % active.size())
		for quest_id in active:
			_row(quest_id)
	if not available.is_empty():
		_section("Available (%d)" % available.size())
		for quest_id in available:
			_row(quest_id)
	if not completed.is_empty():
		_section("Completed (%d)" % completed.size())
		for quest_id in completed:
			_row(quest_id)

func refresh() -> void:
	if not visible:
		return
	select_default()
	_clear(quest_list)
	if line_tab == "story":
		_build_story()
	else:
		_build_side()

	if selected_quest == "":
		quest_name.text = "No quests yet" if line_tab == "story" else "No side quests yet"
		quest_giver.text = ""
		quest_goal.text = "Talk to the villagers - someone will have work for you."
		quest_progress.text = ""
		quest_reward.text = ""
		track_btn.visible = false
		return
	var def: Dictionary = Quests.QUEST_DEFS[selected_quest]
	var state: String = _state(selected_quest)
	var done: bool = state == "completed"
	quest_name.text = def.name
	var from: String = "From %s" % Quests.giver_label(selected_quest) if def.has("giver_name") else "Village tutorial"
	var chain: String = chain_text(selected_quest)
	quest_giver.text = from + ("\n" + chain if chain != "" else "")
	quest_goal.text = goal_text(selected_quest)
	if state == "":
		quest_progress.text = "[color=#d8c890]Not yet accepted - see %s.[/color]" % Quests.giver_label(selected_quest)
	elif done:
		quest_progress.text = "[color=#8ee07f]Completed[/color]"
	elif Quests.objective_met(selected_quest):
		quest_progress.text = "[color=#8ee07f]Ready to turn in!%s[/color]" % (" Go back to %s." % Quests.giver_label(selected_quest) if def.has("giver_name") else "")
	else:
		quest_progress.text = "Progress: " + Quests.objective_progress_text(selected_quest)
	quest_reward.text = reward_text(selected_quest)
	track_btn.visible = state == "accepted"
	if state == "accepted":
		var tracked: bool = Quests.is_tracked(selected_quest)
		track_btn.text = "Untrack" if tracked else "Track on screen"
		track_btn.disabled = not tracked and Quests.tracked_quests.size() >= Quests.MAX_TRACKED
		track_btn.theme_type_variation = &"SecondaryButton" if tracked else &"PrimaryButton"

func _on_track_pressed() -> void:
	if selected_quest != "" and _state(selected_quest) == "accepted":
		Quests.toggle_track(selected_quest)
