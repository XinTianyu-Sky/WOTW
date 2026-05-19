# BattleUI.gd
# 战斗界面控制器 — 管理招式/目标/物品选择、战斗日志、HP条
class_name BattleUI
extends CanvasLayer

@onready var skill_panel: Panel = $SkillPanel
@onready var skill_list: HBoxContainer = $SkillPanel/SkillList
@onready var target_panel: Panel = $TargetPanel
@onready var target_list: HBoxContainer = $TargetPanel/TargetList
@onready var item_panel: Panel = $ItemPanel
@onready var item_list: HBoxContainer = $ItemPanel/ItemList
@onready var battle_log: RichTextLabel = $BattleLog
@onready var info_label: Label = $InfoLabel
@onready var player_hp_bar: ProgressBar = $UnitBars/PlayerBox/HPBar
@onready var player_qi_bar: ProgressBar = $UnitBars/PlayerBox/QiBar
@onready var player_name_label: Label = $UnitBars/PlayerBox/NameLabel
@onready var enemy_hp_bar: ProgressBar = $UnitBars/EnemyBox/HPBar
@onready var enemy_qi_bar: ProgressBar = $UnitBars/EnemyBox/QiBar
@onready var enemy_name_label: Label = $UnitBars/EnemyBox/NameLabel

var _ctrl: BattleController = null
var _current_unit: BattleUnit = null

const BTN_STYLE: Dictionary = {
	"bg": Color(0.22, 0.17, 0.1, 1),
	"text": Color(0.88, 0.82, 0.68, 1),
}

func _ready() -> void:
	_ctrl = get_parent() as BattleController
	_clear_ui()
	# 血条/气条颜色
	player_hp_bar.add_theme_color_override("fill_color", Color(0.82, 0.15, 0.1))
	player_qi_bar.add_theme_color_override("fill_color", Color(0.15, 0.35, 0.78))
	enemy_hp_bar.add_theme_color_override("fill_color", Color(0.78, 0.2, 0.1))
	enemy_qi_bar.add_theme_color_override("fill_color", Color(0.2, 0.4, 0.82))

func add_log(text: String) -> void:
	battle_log.append_text("[color=#c8b898]" + text + "[/color]\n")

func show_player_turn(unit: BattleUnit) -> void:
	_current_unit = unit
	info_label.text = "你 的 回 合"
	info_label.show()
	_show_skills(unit)

func _make_button(text: String, minsize: Vector2) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = minsize
	btn.add_theme_color_override("font_color", BTN_STYLE["text"])
	btn.add_theme_font_size_override("font_size", 13)
	var normal = StyleBoxFlat.new()
	normal.bg_color = BTN_STYLE["bg"]
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.4, 0.28, 0.12, 0.6)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", normal)
	return btn

func _show_skills(unit: BattleUnit) -> void:
	_clear_skills()
	var available = unit.get_available_skills()
	skill_panel.show()
	for tech in available:
		var btn = _make_button("%s\n气:%d" % [tech.get("name", "?"), tech.get("qiCost", 0)], Vector2(140, 58))
		btn.pressed.connect(func():
			skill_panel.hide()
			_show_targets()
			_ctrl.on_player_skill_selected(tech["id"])
		)
		skill_list.add_child(btn)

	var basic_btn = _make_button("基础攻击", Vector2(120, 58))
	basic_btn.pressed.connect(func():
		skill_panel.hide()
		_show_targets()
		_ctrl.on_player_skill_selected("__basic__")
	)
	skill_list.add_child(basic_btn)

	var item_btn = _make_button("物 品", Vector2(90, 58))
	item_btn.pressed.connect(func():
		skill_panel.hide()
		_show_items()
	)
	skill_list.add_child(item_btn)

func _show_items() -> void:
	_clear_items()
	var inv: Array = GameManager.player_data.get("inventory", [])
	var has_any = false
	for item_id in inv:
		var data = DataManager.get_item(item_id)
		if data.is_empty():
			continue
		var item_type = data.get("type", "")
		if item_type not in ["healing", "qiRestore", "buff"]:
			continue
		has_any = true
		var btn = _make_button(data.get("name", item_id), Vector2(150, 58))
		btn.pressed.connect(func():
			item_panel.hide()
			info_label.hide()
			_ctrl.on_player_item_selected(item_id)
		)
		item_list.add_child(btn)

	if not has_any:
		var label = Label.new()
		label.text = "没有可用物品"
		label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4, 1))
		item_list.add_child(label)

	var back_btn = _make_button("返 回", Vector2(80, 58))
	back_btn.pressed.connect(func():
		item_panel.hide()
		_show_skills(_current_unit)
	)
	item_list.add_child(back_btn)
	item_panel.show()

func _clear_items() -> void:
	for child in item_list.get_children():
		child.queue_free()

func _show_targets() -> void:
	_clear_targets()
	target_panel.show()
	var enemies = _ctrl.enemy_units
	for i in range(enemies.size()):
		var e = enemies[i]
		if not e.is_alive():
			continue
		var btn = _make_button("%s\nHP:%d" % [e.display_name, e.stats.current_hp], Vector2(140, 58))
		var idx = i
		btn.pressed.connect(func():
			target_panel.hide()
			info_label.hide()
			_ctrl.on_player_target_selected(idx)
		)
		target_list.add_child(btn)

	var back_btn = _make_button("返 回", Vector2(80, 58))
	back_btn.pressed.connect(func():
		target_panel.hide()
		_show_skills(_current_unit)
	)
	target_list.add_child(back_btn)

func _clear_ui() -> void:
	info_label.hide()
	skill_panel.hide()
	target_panel.hide()
	item_panel.hide()
	_clear_skills()
	_clear_targets()
	_clear_items()
	battle_log.clear()

func _clear_skills() -> void:
	for child in skill_list.get_children():
		child.queue_free()

func _clear_targets() -> void:
	for child in target_list.get_children():
		child.queue_free()

func update_hp_bars() -> void:
	var player = _ctrl.player_units[0] if _ctrl.player_units.size() > 0 else null
	var enemy = _ctrl.enemy_units[0] if _ctrl.enemy_units.size() > 0 else null
	if player:
		player_name_label.text = player.display_name
		player_hp_bar.max_value = player.stats.max_hp
		player_hp_bar.value = player.stats.current_hp
		player_hp_bar.get_node("Label").text = "HP %d/%d" % [player.stats.current_hp, player.stats.max_hp]
		player_qi_bar.max_value = player.stats.max_qi
		player_qi_bar.value = player.stats.current_qi
		player_qi_bar.get_node("Label").text = "气 %d/%d" % [player.stats.current_qi, player.stats.max_qi]
	if enemy:
		enemy_name_label.text = enemy.display_name
		enemy_hp_bar.max_value = enemy.stats.max_hp
		enemy_hp_bar.value = enemy.stats.current_hp
		enemy_hp_bar.get_node("Label").text = "HP %d/%d" % [enemy.stats.current_hp, enemy.stats.max_hp]
		enemy_qi_bar.max_value = enemy.stats.max_qi
		enemy_qi_bar.value = enemy.stats.current_qi
		enemy_qi_bar.get_node("Label").text = "气 %d/%d" % [enemy.stats.current_qi, enemy.stats.max_qi]
