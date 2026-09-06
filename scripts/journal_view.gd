extends Control
# The character sheet's Journal tab (UI redesign Phase 3c, the last screen
# off the old list layout). Left: every quest present in Quests.quest_state
# (not-yet-offered quests don't show) as a row under Active / Completed
# headers - name plus a live status line (progress with an inline item
# icon, "Ready to turn in!", or "Completed"). Right (below, on a phone):
# the selected quest's giver, goal, progress, reward and a Track / Untrack
# button that pins it to the always-visible QuestTracker overlay (capped at
# Quests.MAX_TRACKED; completed quests can't be tracked).
#
# Skeleton from tools/setup_character_sheet.gd; character_sheet.gd calls
# apply_layout() and refresh() and owns open/close/tab switching.

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

var selected_quest := ""
var _row_width := 424.0

func _ready() -> void:
	track_btn.pressed.connect(_on_track_pressed)

# --- layout (the sheet hides its header on this tab) ---

func _place(c: Control, pos: Vector2, size: Vector2) -> void:
	c.position = pos
	c.size = size

func apply_layout(narrow: bool, view_size: Vector2) -> void:
	var pane_h: float
	if not narrow:
		_row_width = 424.0
		_place(list_scroll, Vector2(20, 0), Vector2(424, 430))
		pane_h = 430.0
		_place(detail_pane, Vector2(452, 0), Vector2(248, pane_h))
		hint_label.position = Vector2(20, 436)
		hint_label.visible = true
	else:
		var iw: float = view_size.x
		_row_width = iw - 40.0
		var list_h := 4 * ROW_HEIGHT + 3 * 4.0 + 24.0
		_place(list_scroll, Vector2(20, 0), Vector2(iw - 40.0, list_h))
		pane_h = maxf(200.0, view_size.y - list_h - 8.0 - 4.0)
		_place(detail_pane, Vector2(20, list_h + 8.0), Vector2(iw - 40.0, pane_h))
		hint_label.visible = false
	var pw: float = detail_pane.size.x
	_place(quest_name, Vector2(12, 10), Vector2(pw - 24.0, 44))
	quest_giver.position = Vector2(12, 56)
	_place(quest_goal, Vector2(12, 76), Vector2(pw - 24.0, 60))
	_place(quest_progress, Vector2(12, 140), Vector2(pw - 24.0, 40))
	_place(quest_reward, Vector2(12, 184), Vector2(pw - 24.0, 36))
	_place(track_btn, Vector2(12, 228), Vector2(pw - 24.0, 40))

# --- quests ---

func _active_ids() -> Array:
	var out: Array = []
	for quest_id in Quests.quest_state.keys():
		if Quests.quest_state[quest_id] != "completed":
			out.append(quest_id)
	return out

func _completed_ids() -> Array:
	var out: Array = []
	for quest_id in Quests.quest_state.keys():
		if Quests.quest_state[quest_id] == "completed":
			out.append(quest_id)
	return out

# Status line for a row: live progress, ready, or done.
func status_text(quest_id: String) -> String:
	if Quests.quest_state.get(quest_id, "") == "completed":
		return "Completed"
	if Quests.objective_met(quest_id):
		return "Ready to turn in!"
	return Quests.objective_progress_text(quest_id)

# One sentence describing the objective, with inline item icons.
func goal_text(quest_id: String) -> String:
	var def: Dictionary = Quests.QUEST_DEFS[quest_id]
	var objective: Dictionary = def.objective
	if objective.has("goal"):
		return objective.goal
	var giver: String = def.get("giver_name", "")
	var to_giver: String = " and bring it to the %s" % giver if giver != "" else ""
	if objective.type == "gather":
		return "Gather %d %s%s." % [objective.amount, Items.get_item_name_bbcode(objective.item_id), to_giver]
	if objective.type == "gather_multi":
		var parts: Array = []
		for entry in objective.items:
			parts.append("%d %s" % [entry.amount, Items.get_item_name_bbcode(entry.item_id)])
		return "Gather %s%s." % [" and ".join(parts), to_giver.replace("bring it", "bring them")]
	if objective.type == "talk_to_npcs":
		return "Talk to every villager (%d of them)." % objective.npc_ids.size()
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

# Picks a sensible default: the selected quest if it's still listed, else
# the first active one, else the first completed one.
func select_default() -> void:
	var ids: Array = _active_ids() + _completed_ids()
	if not (selected_quest in ids):
		selected_quest = ids[0] if not ids.is_empty() else ""

func select_quest(quest_id: String) -> void:
	selected_quest = quest_id
	refresh()

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.name = "Dying" + str(child.get_index())
		child.visible = false
		child.queue_free()

func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"PanelTitle"
	l.add_theme_font_size_override("font_size", 14)
	quest_list.add_child(l)

# A row is a tab-styled button with the name and status line laid over it
# (labels ignore the mouse so the tap reaches the button).
func _row(quest_id: String) -> void:
	var def: Dictionary = Quests.QUEST_DEFS[quest_id]
	var btn := Button.new()
	btn.name = quest_id.to_pascal_case() + "Row"
	btn.custom_minimum_size = Vector2(_row_width, ROW_HEIGHT)
	btn.theme_type_variation = &"TabButtonActive" if quest_id == selected_quest else &"TabButton"
	btn.pressed.connect(select_quest.bind(quest_id))
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = def.name + ("   (tracked)" if Quests.is_tracked(quest_id) else "")
	name_label.position = Vector2(12, 6)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if quest_id == selected_quest:
		name_label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.04))
	btn.add_child(name_label)
	var status := RichTextLabel.new()
	status.name = "Status"
	status.bbcode_enabled = true
	status.fit_content = true
	status.scroll_active = false
	status.text = status_text(quest_id)
	status.position = Vector2(12, 26)
	status.size = Vector2(_row_width - 24.0, 22)
	status.add_theme_font_size_override("normal_font_size", 12)
	status.add_theme_color_override("default_color", Color(0.1, 0.08, 0.04) if quest_id == selected_quest else Color(0.7, 0.7, 0.7))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(status)
	quest_list.add_child(btn)

func refresh() -> void:
	if not visible:
		return
	select_default()
	_clear(quest_list)
	var active: Array = _active_ids()
	var completed: Array = _completed_ids()
	if active.is_empty() and completed.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(no quests yet)"
		empty_label.theme_type_variation = &"DimLabel"
		quest_list.add_child(empty_label)
	if not active.is_empty():
		_section("Active (%d)" % active.size())
		for quest_id in active:
			_row(quest_id)
	if not completed.is_empty():
		_section("Completed (%d)" % completed.size())
		for quest_id in completed:
			_row(quest_id)

	if selected_quest == "":
		quest_name.text = "No quests yet"
		quest_giver.text = ""
		quest_goal.text = "Talk to the villagers - someone will have work for you."
		quest_progress.text = ""
		quest_reward.text = ""
		track_btn.visible = false
		return
	var def: Dictionary = Quests.QUEST_DEFS[selected_quest]
	var done: bool = Quests.quest_state.get(selected_quest, "") == "completed"
	quest_name.text = def.name
	quest_giver.text = "From the %s" % def.giver_name if def.has("giver_name") else "Village tutorial"
	quest_goal.text = goal_text(selected_quest)
	if done:
		quest_progress.text = "[color=#8ee07f]Completed[/color]"
	elif Quests.objective_met(selected_quest):
		quest_progress.text = "[color=#8ee07f]Ready to turn in!%s[/color]" % (" Go back to the %s." % def.giver_name if def.has("giver_name") else "")
	else:
		quest_progress.text = "Progress: " + Quests.objective_progress_text(selected_quest)
	quest_reward.text = reward_text(selected_quest)
	track_btn.visible = not done
	if not done:
		var tracked: bool = Quests.is_tracked(selected_quest)
		track_btn.text = "Untrack" if tracked else "Track on screen"
		track_btn.disabled = not tracked and Quests.tracked_quests.size() >= Quests.MAX_TRACKED
		track_btn.theme_type_variation = &"SecondaryButton" if tracked else &"PrimaryButton"

func _on_track_pressed() -> void:
	if selected_quest != "":
		Quests.toggle_track(selected_quest)
