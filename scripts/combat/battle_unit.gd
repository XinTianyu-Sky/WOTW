# BattleUnit.gd
# 战斗单位
# 代表战斗中一个角色（玩家/同伴/敌人），管理战斗中的状态
class_name BattleUnit
extends RefCounted

# ---- 基础信息 ----
var unit_id: String = ""
var display_name: String = ""
var is_player_side: bool = false
var sprite_path: String = ""

# ---- 属性 ----
var stats: PlayerStats = null

# ---- 武学 ----
var external_skill_id: String = ""
var internal_skill_id: String = ""
var lightness_skill_id: String = ""

# ---- 战斗状态 ----
var grid_position: Vector2i = Vector2i.ZERO
var active_statuses: Array = []     # 当前异常状态
var skill_cooldowns: Dictionary = {} # skill_id -> remaining cooldown
var is_guarding: bool = false

func _init():
	stats = PlayerStats.new()
	stats.current_hp = stats.max_hp
	stats.current_qi = stats.max_qi

func is_alive() -> bool:
	return stats.current_hp > 0

func take_damage(amount: int) -> void:
	if not is_alive():
		return

	# 检查护盾
	var shield = _get_shield_amount()
	if shield > 0:
		if shield >= amount:
			_reduce_shield(amount)
			return
		else:
			_reduce_shield(shield)
			amount -= shield

	stats.current_hp = max(0, stats.current_hp - amount)

func take_qi_damage(amount: int) -> void:
	stats.current_qi = max(0, stats.current_qi - amount)

func regen_qi() -> void:
	var regen = max(1, int(stats.wil * 0.3))
	stats.current_qi = min(stats.max_qi, stats.current_qi + regen)

func heal(amount: int) -> void:
	if not is_alive():
		return
	stats.current_hp = min(stats.max_hp, stats.current_hp + amount)

func restore_qi(amount: int) -> void:
	stats.current_qi = min(stats.max_qi, stats.current_qi + amount)

# ---- 状态效果 ----
func apply_status(effect_data: Dictionary) -> void:
	var status_id = effect_data.get("id", "")
	if status_id.is_empty():
		return

	# 检查是否免疫
	if _is_immune_to(status_id):
		return

	# 检查是否可叠加
	var existing = _find_status(status_id)
	if existing and effect_data.get("stackable", false):
		existing["stacks"] = mini(existing.get("stacks", 1) + 1, effect_data.get("maxStacks", 5))
	else:
		var new_status = effect_data.duplicate()
		new_status["remainingDuration"] = effect_data.get("duration", 1)
		new_status["stacks"] = 1
		active_statuses.append(new_status)

	EventBus.status_applied.emit(unit_id, status_id)

func remove_status(status_id: String) -> void:
	for i in range(active_statuses.size() - 1, -1, -1):
		if active_statuses[i]["id"] == status_id:
			active_statuses.remove_at(i)
			EventBus.status_removed.emit(unit_id, status_id)
			return

func on_turn_start() -> void:
	# 回合开始时的持续效果
	for status in active_statuses:
		match status.get("id", ""):
			"poison":
				take_damage(int(stats.max_hp * 0.03 * status.get("stacks", 1)))
			"burn":
				take_damage(int(stats.max_hp * 0.05))
			"inner_wound":
				take_qi_damage(5 * status.get("stacks", 1))

	# 减少持续时间
	for i in range(active_statuses.size() - 1, -1, -1):
		var s = active_statuses[i]
		if s.get("duration", -1) == -1:  # 永久效果
			continue
		s["remainingDuration"] -= 1
		if s["remainingDuration"] <= 0:
			active_statuses.remove_at(i)

	# 减少冷却
	for skill_id in skill_cooldowns:
		if skill_cooldowns[skill_id] > 0:
			skill_cooldowns[skill_id] -= 1

func on_turn_end() -> void:
	is_guarding = false

# ---- 技能查询 ----
func get_equipped_external_skill() -> String:
	return external_skill_id

func get_available_skills() -> Array:
	if external_skill_id.is_empty():
		return []

	var skill_data = DataManager.get_external_skill(external_skill_id)
	var available: Array = []

	for tech in skill_data.get("techniques", []):
		var tech_id = tech["id"]
		# 检查冷却
		if skill_cooldowns.get(tech_id, 0) > 0:
			continue
		# 检查内力
		if stats.current_qi < tech.get("qiCost", 0):
			continue
		available.append(tech)

	return available

func get_element() -> String:
	if internal_skill_id.is_empty():
		return ""
	var data = DataManager.get_internal_skill(internal_skill_id)
	return data.get("element", "")

# ---- 内部方法 ----
func _find_status(status_id: String) -> Dictionary:
	for s in active_statuses:
		if s["id"] == status_id:
			return s
	return {}

func _is_immune_to(status_id: String) -> bool:
	# 根据内功特殊效果判断免疫
	if internal_skill_id == "jiuyang_shengong":
		if status_id == "poison": return true
		# 五重以上免疫冰冻灼烧
		if status_id in ["frozen", "burn"]: return true
	return false

func _get_shield_amount() -> int:
	var total = 0
	for s in active_statuses:
		if s.get("id") == "shield":
			total += s.get("effects", {}).get("shieldAmount", 0)
	return total

func _reduce_shield(amount: int) -> void:
	for s in active_statuses:
		if s.get("id") == "shield":
			var current = s.get("effects", {}).get("shieldAmount", 0)
			if current <= amount:
				active_statuses.erase(s)
			else:
				s["effects"]["shieldAmount"] = current - amount
			return