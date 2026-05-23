# DialogueUI.gd
# 对话界面控制器
# 处理对话树展示、选项交互
class_name DialogueUI
extends CanvasLayer

# ---- UI 元素 ----
@onready var panel: Panel = $DialoguePanel
@onready var speaker_name: Label = $DialoguePanel/SpeakerName
@onready var dialogue_text: Label = $DialoguePanel/DialogueText
@onready var choices_container: VBoxContainer = $DialoguePanel/ChoicesContainer
@onready var next_indicator: Control = $DialoguePanel/NextIndicator

# ---- 对话状态 ----
var current_dialogue_id: String = ""
var current_node_id: String = ""
var dialogue_data: Dictionary = {}
var is_typing: bool = false
var full_text: String = ""
var type_timer: float = 0.0
const TYPE_SPEED: float = 0.05  # 每个字输出间隔

signal dialogue_ended()

var _npc_triggered: String = ""

func _ready() -> void:
	hide()
	if not EventBus.dialogue_triggered.is_connected(_on_dialogue_triggered):
		EventBus.dialogue_triggered.connect(_on_dialogue_triggered)

func _on_dialogue_triggered(dialogue_id, npc_id) -> void:
	start_dialogue(dialogue_id, npc_id)

func _process(delta: float) -> void:
	if is_typing:
		type_timer -= delta
		if type_timer <= 0:
			_reveal_next_char()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		if is_typing:
			_skip_typing()
		elif choices_container.get_child_count() == 0:
			_advance_dialogue()

# ---- 启动对话 ----
func start_dialogue(dialogue_id: String, npc_id: String = "") -> void:
	GameManager.set_phase(GameManager.GamePhase.DIALOGUE)
	current_dialogue_id = dialogue_id
	_npc_triggered = npc_id

	var quest_data = DataManager.get_data("quests")
	var dialogues: Array = quest_data.get("dialogues", [])
	if typeof(dialogues) != TYPE_ARRAY:
		push_error("DialogueUI: dialogues 不是 Array, 类型=%d" % typeof(dialogues))
		dialogues = []
	for i in range(dialogues.size()):
		var dlg = dialogues[i]
		if not dlg is Dictionary:
			push_error("DialogueUI: dlg[%d] 不是 Dictionary, 类型=%d" % [i, typeof(dlg)])
			continue
		if dlg.get("id", "") == dialogue_id:
			dialogue_data = dlg
			break

	if dialogue_data.is_empty():
		var ids: Array = []
		for d in dialogues:
			if d is Dictionary:
				ids.append(d.get("id", "?MISSING"))
		push_error("DialogueUI: 对话 '%s' 不存在，已加载: [%s]" % [dialogue_id, ", ".join(ids)])
		end_dialogue()
		return

	show()
	_show_node(dialogue_data["startNode"])

# ---- 节点显示 ----
func _show_node(node_id: String) -> void:
	choices_container.hide()
	_clear_choices()

	var node = dialogue_data.get("nodes", {}).get(node_id, {})
	if node.is_empty():
		end_dialogue()
		return

	current_node_id = node_id

	speaker_name.text = _get_speaker_display_name(node.get("speaker", ""))

	full_text = node.get("text", "")
	_start_typing()

	var choices = node.get("choices", [])
	if choices.size() > 0:
		_populate_choices(choices)
	else:
		next_indicator.show()

# ---- 打字机效果 ----
func _start_typing() -> void:
	is_typing = true
	dialogue_text.text = ""
	type_timer = TYPE_SPEED

func _reveal_next_char() -> void:
	var current_len = dialogue_text.text.length()
	if current_len >= full_text.length():
		is_typing = false
		return

	dialogue_text.text = full_text.substr(0, current_len + 1)
	type_timer = TYPE_SPEED

func _skip_typing() -> void:
	is_typing = false
	dialogue_text.text = full_text

# ---- 选项 ----
func _populate_choices(choices: Array) -> void:
	_clear_choices()
	next_indicator.hide()
	choices_container.show()

	for i in range(choices.size()):
		var choice = choices[i]
		if not _check_conditions(choice.get("conditions", {})):
			continue

		var btn = Button.new()
		btn.text = "%d. %s" % [i + 1, choice.get("text", "")]
		btn.pressed.connect(_on_choice_selected.bind(choice))
		choices_container.add_child(btn)

func _on_choice_selected(choice: Dictionary) -> void:
	var effects = choice.get("effects", {})
	_apply_effects(effects)

	EventBus.choice_made.emit(current_dialogue_id, choice.get("id", ""))

	var next_node = choice.get("nextNode", "")
	if next_node.is_empty() or next_node == "node_end":
		end_dialogue()
	else:
		_show_node(next_node)

func _advance_dialogue() -> void:
	var node = dialogue_data.get("nodes", {}).get(current_node_id, {})
	var next_node = node.get("nextNode", "")

	_apply_effects(node.get("effects", {}))
	if node.has("acceptQuest"):
		EventBus.quest_accepted.emit(node["acceptQuest"])

	if next_node.is_empty() or next_node == "node_end":
		end_dialogue()
	else:
		_show_node(next_node)

func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()

# ---- 效果应用 ----
func _apply_effects(effects: Dictionary) -> void:
	if effects.has("affinityChange"):
		pass
	if effects.has("startQuest"):
		EventBus.quest_accepted.emit(effects["startQuest"])
	if effects.has("completeQuest"):
		EventBus.quest_completed.emit(effects["completeQuest"])
	if effects.has("setFlag"):
		GameManager.world_state[effects["setFlag"]] = true
	if effects.has("triggerBattle"):
		var battle_data = effects["triggerBattle"]
		_trigger_battle(battle_data)

func _trigger_battle(battle_data: Dictionary) -> void:
	var enemy_team: Array = []
	var templates = battle_data.get("enemies", [])
	for tmpl in templates:
		var count = tmpl.get("count", 1)
		var stats = PlayerStats.new()
		var lv = tmpl.get("level", 1)
		stats.str = tmpl.get("str", 5) + lv
		stats.agi = tmpl.get("agi", 5) + lv
		stats.con = tmpl.get("con", 5) + lv
		stats.int_ = tmpl.get("int", 2) + lv
		stats.wil = tmpl.get("wil", 2) + lv
		stats.lck = tmpl.get("lck", 1) + lv
		stats.level = lv
		stats.recalculate()
		stats.current_hp = stats.max_hp
		stats.current_qi = stats.max_qi
		for i in range(count):
			enemy_team.append({
				"id": "%s_%d" % [tmpl.get("name", "enemy"), i],
				"name": tmpl.get("name", "敌人"),
				"stats": stats,
				"skills": tmpl.get("skills", ["basic_strike"]),
				"sprite": "",
			})
	hide()
	dialogue_data.clear()
	GameManager.start_battle(enemy_team)

func _check_conditions(conditions: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	if conditions.has("minAffinity"):
		return true
	return true

func _get_speaker_display_name(speaker_id: String) -> String:
	match speaker_id:
		"player": return "主角"
		"system": return ""
		"old_beggar": return "老乞丐"
		"village_guard": return "村庄守卫"
		"teahouse_owner": return "茶馆老板"
		"merchant_li": return "李货郎"
		"wushi": return "武师"
		"hermit": return "采药老人"
		"bandit_scout": return "山贼探子"
		"bandit_boss": return "山贼头目"
		_: return speaker_id

func end_dialogue() -> void:
	_track_quest_progress()
	hide()
	dialogue_data.clear()
	GameManager.set_phase(GameManager.GamePhase.WORLD_EXPLORATION)
	dialogue_ended.emit()

func _track_quest_progress() -> void:
	var related_npc = dialogue_data.get("relatedNpc", "")
	if related_npc.is_empty():
		return
	var active = GameManager.world_state.get("active_quests", [])
	for qid in active:
		var qdata = DataManager.get_quest(qid)
		if qdata.is_empty():
			continue
		var objs = qdata.get("objectives", [])
		for i in range(objs.size()):
			var obj = objs[i]
			if obj.get("type") == "talk" and obj.get("targetId") == related_npc:
				var progress = GameManager.world_state.get("quest_progress", {}).get(qid, [])
				if not progress.has(i):
					progress.append(i)
					GameManager.world_state["quest_progress"] = GameManager.world_state.get("quest_progress", {})
					GameManager.world_state["quest_progress"][qid] = progress
					EventBus.quest_progressed.emit(qid, i)
					_check_quest_completion(qid, objs, progress)

func _check_quest_completion(qid: String, objectives: Array, completed_indices: Array) -> void:
	if completed_indices.size() >= objectives.size():
		EventBus.quest_completed.emit(qid)
