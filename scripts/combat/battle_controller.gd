# BattleController.gd
# 战斗主控制器
# 管理回合制战斗流程：初始化、回合交替、胜负判定
class_name BattleController
extends Node

# ---- 信号 ----
signal battle_ready()
signal turn_started(unit: BattleUnit, turn_number: int)
signal turn_ended(unit: BattleUnit)
signal battle_finished(result: Dictionary)
signal player_skill_selected(technique_id: String)
signal player_target_selected(target_index: int)

# ---- 战斗状态 ----
enum BattleState { INIT, PLAYER_TURN, ENEMY_TURN, ANIMATING, FINISHED }

var state: BattleState = BattleState.INIT
var turn_number: int = 0
var turn_order: Array = []
var current_turn_index: int = 0
var _selected_technique_id: String = ""
var _selected_target_idx: int = -1

# ---- 参战单位 ----
var player_units: Array = []
var enemy_units: Array = []
var all_units: Array = []

# ---- 战场 ----
var grid: BattleGrid = null

# ---- 战斗结束返回 ----
var _return_scene: String = ""

# ---- 引用 ----
@onready var grid_node: Node2D = $BattleGrid
@onready var ui_layer: CanvasLayer = $BattleUI

func _ready() -> void:
	grid = BattleGrid.new()
	_auto_init_battle()
	battle_finished.connect(_on_battle_finished)

func _auto_init_battle() -> void:
	var pending = GameManager.pending_battle
	if pending.is_empty():
		return

	_return_scene = pending.get("return_scene", "res://scenes/world/world.tscn")

	var player_team = [{
		"id": "player",
		"name": GameManager.player_data.get("name", "主角"),
		"stats": GameManager.player_data.get("_stats_ref", PlayerStats.new()),
		"skills": [],
		"sprite": "",
	}]
	var enemy_team = pending.get("enemy_team", [])
	var terrain = pending.get("terrain", {})

	GameManager.pending_battle = {}
	init_battle(player_team, enemy_team, terrain)
	start_battle()

func _on_battle_finished(result: Dictionary) -> void:
	GameManager.pending_battle = {}
	if result.get("result") == "victory":
		_grant_battle_rewards()
	elif result.get("result") == "defeat":
		NotificationManager.notify("战斗失败，重新加载...", "error")
		await get_tree().create_timer(1.0).timeout
		SaveManager.load_game(0)
	if not _return_scene.is_empty():
		GameManager.change_scene(_return_scene)

func _grant_battle_rewards() -> void:
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if not stats:
		return
	var exp = 50 + randi() % 51
	var leveled = stats.add_experience(exp)
	NotificationManager.notify("获得 %d 经验" % exp, "success")
	if leveled:
		NotificationManager.notify("升级！达到 Lv.%d" % stats.level, "success")

# ---- 战斗初始化 ----
func init_battle(player_team: Array, enemy_team: Array, terrain_data: Dictionary = {}) -> void:
	state = BattleState.INIT

	# 创建战斗单位
	player_units.clear()
	enemy_units.clear()

	for data in player_team:
		var unit = _create_unit(data, true)
		player_units.append(unit)

	for data in enemy_team:
		var unit = _create_unit(data, false)
		enemy_units.append(unit)

	all_units = player_units + enemy_units

	# 初始化战场
	grid.init_grid(8, 8, terrain_data)
	_place_units_on_grid()

	# 计算行动顺序
	_build_turn_order()

	battle_ready.emit()

func _create_unit(data: Dictionary, is_player: bool) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_id = data.get("id", "")
	unit.display_name = data.get("name", "Unknown")
	unit.is_player_side = is_player
	unit.stats = data.get("stats", PlayerStats.new())
	var skills: Array = data.get("skills", [])
	if skills.size() > 0:
		unit.external_skill_id = skills[0]
	unit.sprite_path = data.get("sprite", "")
	return unit

func _place_units_on_grid() -> void:
	# 玩家在左侧，敌人在右侧
	for i in range(player_units.size()):
		var pos = Vector2i(1, 1 + i * 2)
		if grid.is_in_bounds(pos):
			player_units[i].grid_position = pos

	for i in range(enemy_units.size()):
		var pos = Vector2i(6, 1 + i * 2)
		if grid.is_in_bounds(pos):
			enemy_units[i].grid_position = pos

func _build_turn_order() -> void:
	turn_order = all_units.duplicate()
	turn_order.sort_custom(func(a, b): return a.stats.speed > b.stats.speed)
	current_turn_index = 0

# ---- 战斗主循环 ----
func start_battle() -> void:
	turn_number = 1
	_next_turn()

func _next_turn() -> void:
	if state == BattleState.FINISHED:
		return

	current_turn_index = current_turn_index % turn_order.size()
	var unit = turn_order[current_turn_index]

	# 跳过已阵亡单位
	if not unit.is_alive():
		current_turn_index += 1
		_next_turn()
		return

	# 更新状态
	state = BattleState.PLAYER_TURN if unit.is_player_side else BattleState.ENEMY_TURN
	turn_started.emit(unit, turn_number)

	# 回合开始效果处理
	unit.on_turn_start()

	# 检查胜负
	if _check_battle_end():
		return

	# 敌人回合：AI 自动行动
	if not unit.is_player_side:
		await get_tree().create_timer(0.5).timeout
		_enemy_ai_act(unit)

	# 玩家回合：等待手动选择（UI 回调驱动后续流程）
	if unit.is_player_side:
		var ui = get_node_or_null("BattleUI")
		if ui and ui.has_method("show_player_turn"):
			ui.show_player_turn(unit)
			# 不 await，由 UI 按钮回调 → _execute_player_action → end_current_turn 驱动
			return
		else:
			await get_tree().create_timer(0.3).timeout
			_player_auto_act(unit)

func end_current_turn() -> void:
	var unit = turn_order[current_turn_index]
	unit.on_turn_end()
	turn_ended.emit(unit)

	current_turn_index += 1
	if current_turn_index >= turn_order.size():
		current_turn_index = 0
		turn_number += 1
		# 新回合开始，恢复内力
		for u in all_units:
			u.regen_qi()

	_next_turn()

# ---- 伤害计算 ----
func calculate_damage(attacker: BattleUnit, defender: BattleUnit, technique: Dictionary) -> int:
	# 基础伤害
	var base_damage: float = 0.0
	var formula = technique.get("damageFormula", {})
	var stat_type = formula.get("stat", "attack")

	if stat_type == "attack":
		base_damage = attacker.stats.attack * formula.get("multiplier", 1.0)
	else:
		base_damage = attacker.stats.inner_power * formula.get("multiplier", 1.0)

	# 防御减免
	base_damage -= defender.stats.defense * 0.5

	# 五行克制
	base_damage *= _get_element_multiplier(attacker, defender)

	# 暴击判定
	if randf() < attacker.stats.crit_rate:
		base_damage *= attacker.stats.crit_damage

	# 闪避判定
	if randf() < defender.stats.dodge_rate:
		return 0  # 闪避，0伤害

	# 随机浮动 ±10%
	base_damage *= randf_range(0.9, 1.1)

	return max(1, int(base_damage))

func _get_element_multiplier(attacker: BattleUnit, defender: BattleUnit) -> float:
	# 五行克制：金→木→土→水→火→金
	const ELEMENTS = ["metal", "wood", "earth", "water", "fire"]
	var atk_elem = attacker.get_element()
	var def_elem = defender.get_element()

	if atk_elem.is_empty() or def_elem.is_empty():
		return 1.0

	var atk_idx = ELEMENTS.find(atk_elem)
	var def_idx = ELEMENTS.find(def_elem)

	if atk_idx == -1 or def_idx == -1:
		return 1.0

	# 攻击方克制防御方
	if (atk_idx + 1) % 5 == def_idx:
		return 1.25
	# 攻击方被防御方克制
	if (def_idx + 1) % 5 == atk_idx:
		return 0.75

	return 1.0

# ---- 执行招式 ----
func execute_technique(attacker: BattleUnit, technique_id: String, targets: Array) -> void:
	state = BattleState.ANIMATING

	var external_skill_id = attacker.get_equipped_external_skill()
	var skill_data = DataManager.get_external_skill(external_skill_id)
	var technique: Dictionary = {}

	for tech in skill_data.get("techniques", []):
		if tech["id"] == technique_id:
			technique = tech
			break

	if technique.is_empty():
		state = BattleState.PLAYER_TURN
		return

	# 消耗内力
	attacker.stats.current_qi -= technique.get("qiCost", 0)

	for target in targets:
		var damage = calculate_damage(attacker, target, technique)
		if damage > 0:
			target.take_damage(damage)
			EventBus.unit_damaged.emit(target.unit_id, damage, attacker.unit_id)

		# 应用效果
		for effect in technique.get("effects", []):
			target.apply_status(effect)

		if not target.is_alive():
			EventBus.unit_defeated.emit(target.unit_id)
			_add_battle_log("%s 被击败！" % target.display_name)

	EventBus.skill_used.emit(attacker.unit_id, technique_id, targets.map(func(u): return u.unit_id))
	_refresh_battle_ui()

	await get_tree().create_timer(0.3).timeout

	if _check_battle_end():
		return

	state = BattleState.PLAYER_TURN

# ---- 胜负判定 ----
func _check_battle_end() -> bool:
	var players_alive = _count_alive(player_units)
	var enemies_alive = _count_alive(enemy_units)

	if players_alive == 0:
		_end_battle({"result": "defeat", "rating": "ding"})
		return true
	elif enemies_alive == 0:
		var rating = _calculate_rating()
		_end_battle({"result": "victory", "rating": rating})
		return true

	return false

func _count_alive(units: Array) -> int:
	var count = 0
	for u in units:
		if u.is_alive():
			count += 1
	return count

func _calculate_rating() -> String:
	var all_alive = true
	for u in player_units:
		if not u.is_alive():
			all_alive = false
			break
	if all_alive and turn_number <= 10:
		return "jia"
	if all_alive:
		return "yi"
	if _count_alive(player_units) >= player_units.size() - 1:
		return "bing"
	return "ding"

func _end_battle(result: Dictionary) -> void:
	state = BattleState.FINISHED
	_show_battle_result(result)
	await get_tree().create_timer(2.0).timeout
	battle_finished.emit(result)
	EventBus.battle_ended.emit(result)

func _show_battle_result(result: Dictionary) -> void:
	var ui = get_node_or_null("BattleUI")
	if not ui:
		return
	var banner = ui.get_node_or_null("BattleBanner")
	if banner:
		if result.get("result") == "victory":
			banner.text = "胜利！"
			banner.modulate = Color.GOLD
		else:
			banner.text = "战败..."
			banner.modulate = Color.RED
		banner.show()

# ---- 敌人 AI ----
func _enemy_ai_act(unit: BattleUnit) -> void:
	if not unit.is_alive():
		end_current_turn()
		return

	# 简单 AI：选择可用招式攻击最近的玩家目标
	var available_skills = unit.get_available_skills()
	var target = _find_nearest_player(unit)

	if available_skills.size() > 0 and target != null:
		var skill = available_skills[randi() % available_skills.size()]
		execute_technique(unit, skill["id"], [target])
	else:
		# 没有可用技能，基础攻击
		_basic_attack(unit, target)

	await get_tree().create_timer(0.5).timeout
	end_current_turn()

func _player_auto_act(unit: BattleUnit) -> void:
	if not unit.is_alive():
		end_current_turn()
		return

	var target = _find_nearest_enemy(unit)
	var available = unit.get_available_skills()

	if available.size() > 0 and target:
		var skill = available[0]
		execute_technique(unit, skill["id"], [target])
	else:
		_basic_attack(unit, target)

	await get_tree().create_timer(0.3).timeout
	end_current_turn()

func on_player_skill_selected(technique_id: String) -> void:
	_selected_technique_id = technique_id
	player_skill_selected.emit(technique_id)

func on_player_target_selected(target_index: int) -> void:
	_selected_target_idx = target_index
	_execute_player_action()
	player_target_selected.emit(target_index)

func _execute_player_action() -> void:
	var unit = turn_order[current_turn_index]
	var target = enemy_units[_selected_target_idx] if _selected_target_idx < enemy_units.size() else null
	if not target or not target.is_alive():
		target = _find_nearest_enemy(unit)
	if not target:
		end_current_turn()
		return

	if _selected_technique_id == "__basic__":
		_basic_attack(unit, target)
	else:
		execute_technique(unit, _selected_technique_id, [target])

	await get_tree().create_timer(0.3).timeout
	end_current_turn()

func _find_nearest_enemy(unit: BattleUnit) -> BattleUnit:
	var nearest: BattleUnit = null
	var min_dist = 999
	for e in enemy_units:
		if not e.is_alive():
			continue
		var dist = unit.grid_position.distance_to(e.grid_position)
		if dist < min_dist:
			min_dist = dist
			nearest = e
	return nearest

func _basic_attack(attacker: BattleUnit, defender: BattleUnit) -> void:
	var basic_technique = {"damageFormula": {"stat": "attack", "multiplier": 2.5}}
	var damage = calculate_damage(attacker, defender, basic_technique)
	if damage > 0:
		defender.take_damage(damage)
		_add_battle_log("%s 对 %s 造成 %d 点伤害" % [attacker.display_name, defender.display_name, damage])
		if not defender.is_alive():
			EventBus.unit_defeated.emit(defender.unit_id)
			_add_battle_log("%s 被击败！" % defender.display_name)
	else:
		_add_battle_log("%s 闪避了攻击！" % defender.display_name)
	_refresh_battle_ui()

func _add_battle_log(msg: String) -> void:
	var ui = get_node_or_null("BattleUI")
	if ui and ui.has_method("add_log"):
		ui.add_log(msg)

func _refresh_battle_ui() -> void:
	var ui = get_node_or_null("BattleUI")
	if ui and ui.has_method("update_hp_bars"):
		ui.update_hp_bars()

func _find_nearest_player(unit: BattleUnit) -> BattleUnit:
	var nearest: BattleUnit = null
	var min_dist = 999
	for p in player_units:
		if not p.is_alive():
			continue
		var dist = unit.grid_position.distance_to(p.grid_position)
		if dist < min_dist:
			min_dist = dist
			nearest = p
	return nearest
