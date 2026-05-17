# PlayerStats.gd
# 玩家属性系统
# 管理六维主属性、战斗属性计算、等级成长
class_name PlayerStats
extends Resource

# ---- 主属性 ----
@export var str: int = 5       # 膂力
@export var agi: int = 5       # 身法
@export var con: int = 5       # 根骨
@export var int_: int = 5      # 悟性
@export var wil: int = 5       # 定力
@export var lck: int = 5       # 机缘

# ---- 等级与经验 ----
@export var level: int = 1
@export var experience: int = 0
@export var free_points: int = 10

# ---- 派生战斗属性 ----
var max_hp: int = 0
var current_hp: int = 0
var max_qi: int = 0
var current_qi: int = 0
var attack: int = 0
var defense: int = 0
var inner_power: int = 0
var inner_defense: int = 0
var speed: int = 0
var hit_rate: float = 0.85
var dodge_rate: float = 0.0
var crit_rate: float = 0.0
var crit_damage: float = 1.5
var tenacity: float = 0.0

# ---- 装备加成缓存 ----
var _equipment_bonuses: Dictionary = {}

# ---- 内功加成缓存 ----
var _internal_skill_bonuses: Dictionary = {}

func _init(p_str: int = 5, p_agi: int = 5, p_con: int = 5, p_int: int = 5, p_wil: int = 5, p_lck: int = 5):
	str = p_str
	agi = p_agi
	con = p_con
	int_ = p_int
	wil = p_wil
	lck = p_lck
	recalculate()

# ---- 属性计算 ----
func recalculate() -> void:
	max_hp = con * 20 + _equipment_bonuses.get("hp", 0)
	max_hp = int(max_hp * (1.0 + _internal_skill_bonuses.get("hp", 0.0)))

	max_qi = wil * 10 + _equipment_bonuses.get("qi", 0)
	max_qi = int(max_qi * (1.0 + _internal_skill_bonuses.get("qi", 0.0)))

	attack = str * 2 + _equipment_bonuses.get("attack", 0)
	attack = int(attack * (1.0 + _internal_skill_bonuses.get("attack", 0.0)))

	defense = con * 1 + _equipment_bonuses.get("defense", 0)
	defense = int(defense * (1.0 + _internal_skill_bonuses.get("defense", 0.0)))

	inner_power = int(wil * 1.5 + _equipment_bonuses.get("innerPower", 0))
	inner_power = int(inner_power * (1.0 + _internal_skill_bonuses.get("innerPower", 0.0)))

	inner_defense = int_ * 1 + _equipment_bonuses.get("innerDefense", 0)
	inner_defense = int(inner_defense * (1.0 + _internal_skill_bonuses.get("innerDefense", 0.0)))

	speed = agi * 1 + _equipment_bonuses.get("speed", 0)
	speed = int(speed * (1.0 + _internal_skill_bonuses.get("speed", 0.0)))

	hit_rate = 0.85 + agi * 0.001 + _equipment_bonuses.get("hitRate", 0.0)
	dodge_rate = agi * 0.005 + _equipment_bonuses.get("dodgeRate", 0.0)
	crit_rate = agi * 0.003 + _equipment_bonuses.get("critRate", 0.0)
	crit_damage = 1.5 + _equipment_bonuses.get("critDamage", 0.0)
	tenacity = _internal_skill_bonuses.get("tenacity", 0.0)

	# 确保 HP/QI 不超过上限
	current_hp = min(current_hp, max_hp)
	current_qi = min(current_qi, max_qi)

# ---- 经验与升级 ----
func add_experience(amount: int) -> bool:
	experience += amount
	var required = _exp_for_level(level + 1)
	if experience >= required:
		return level_up()
	return false

func level_up() -> bool:
	level += 1
	free_points += 5
	experience -= _exp_for_level(level)
	recalculate()
	EventBus.player_leveled_up.emit(level)
	return true

func _exp_for_level(lv: int) -> int:
	return int(100 * pow(lv, 1.5))

# ---- 属性点分配 ----
func allocate_point(attr_name: String) -> bool:
	if free_points <= 0:
		return false
	match attr_name:
		"str": str += 1
		"agi": agi += 1
		"con": con += 1
		"int": int_ += 1
		"wil": wil += 1
		"lck": lck += 1
		_:
			return false
	free_points -= 1
	recalculate()
	EventBus.attribute_changed.emit(attr_name, get(attr_name))
	return true

# ---- 装备加成更新 ----
func update_equipment_bonuses(bonuses: Dictionary) -> void:
	_equipment_bonuses = bonuses
	recalculate()

# ---- 内功加成更新 ----
func update_internal_skill_bonuses(bonuses: Dictionary) -> void:
	_internal_skill_bonuses = bonuses
	recalculate()

# ---- 序列化 ----
func to_dict() -> Dictionary:
	return {
		"str": str, "agi": agi, "con": con, "int": int_, "wil": wil, "lck": lck,
		"level": level, "experience": experience, "free_points": free_points,
		"current_hp": current_hp, "current_qi": current_qi
	}

func from_dict(data: Dictionary) -> void:
	str = data.get("str", 5)
	agi = data.get("agi", 5)
	con = data.get("con", 5)
	int_ = data.get("int", 5)
	wil = data.get("wil", 5)
	lck = data.get("lck", 5)
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	free_points = data.get("free_points", 10)
	recalculate()
	current_hp = data.get("current_hp", max_hp)
	current_qi = data.get("current_qi", max_qi)