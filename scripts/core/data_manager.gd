# DataManager.gd
# 游戏数据管理器 (Autoload)
# 负责加载 JSON 数据文件，提供统一的数据查询接口
extends Node

# ---- 数据缓存 ----
var _cache: Dictionary = {}

# ---- 数据路径映射 ----
const DATA_PATHS: Dictionary = {
	"external_skills": "res://assets/data/skills/external_skills.json",
	"internal_skills": "res://assets/data/skills/internal_skills.json",
	"lightness_skills": "res://assets/data/skills/lightness_skills.json",
	"status_effects": "res://assets/data/skills/status_effects.json",
	"items": "res://assets/data/items/items.json",
	"origins": "res://assets/data/characters/origins.json",
	"companions": "res://assets/data/characters/companions.json",
	"meridians": "res://assets/data/characters/meridians.json",
	"quests": "res://assets/data/quests/quests.json",
	"world": "res://assets/data/world/world.json",
}

# ---- 预加载 ----
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload_data()

func preload_data() -> void:
	for key in DATA_PATHS:
		load_dataset(key)

# ---- 加载与查询 ----
func load_dataset(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]

	var path = DATA_PATHS.get(key, "")
	if path.is_empty():
		push_error("DataManager: 未知数据集 '%s'" % key)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataManager: 无法加载 '%s'" % path)
		return {}

	var json = JSON.parse_string(file.get_as_text())
	file.close()

	if json == null:
		push_error("DataManager: JSON 解析失败 '%s'" % path)
		return {}

	_cache[key] = json
	return json

func get_data(key: String) -> Dictionary:
	if not _cache.has(key):
		return load_dataset(key)
	return _cache[key]

# ---- 专项查询 ----

## 按 ID 获取外功
func get_external_skill(id: String) -> Dictionary:
	var data = get_data("external_skills")
	for skill in data.get("externalSkills", []):
		if skill["id"] == id:
			return skill
	return {}

## 按 ID 获取内功
func get_internal_skill(id: String) -> Dictionary:
	var data = get_data("internal_skills")
	for skill in data.get("internalSkills", []):
		if skill["id"] == id:
			return skill
	return {}

## 按 ID 获取轻功
func get_lightness_skill(id: String) -> Dictionary:
	var data = get_data("lightness_skills")
	for skill in data.get("lightnessSkills", []):
		if skill["id"] == id:
			return skill
	return {}

## 按 ID 获取物品
func get_item(id: String) -> Dictionary:
	var data = get_data("items")
	for category in ["equipment", "consumables", "materials", "skillBooks"]:
		for item in data.get(category, []):
			if item["id"] == id:
				return item
	return {}

## 按 ID 获取同伴数据
func get_companion(id: String) -> Dictionary:
	var data = get_data("companions")
	for comp in data.get("companions", []):
		if comp["id"] == id:
			return comp
	return {}

## 按 ID 获取出身数据
func get_origin(id: String) -> Dictionary:
	var data = get_data("origins")
	for origin in data.get("origins", []):
		if origin["id"] == id:
			return origin
	return {}

## 按 ID 获取经脉数据
func get_meridian(id: String) -> Dictionary:
	var data = get_data("meridians")
	for m in data.get("meridians", []):
		if m["id"] == id:
			return m
	return {}

## 获取所有外功列表
func get_all_external_skills() -> Array:
	var data = get_data("external_skills")
	return data.get("externalSkills", [])

## 获取所有内功列表
func get_all_internal_skills() -> Array:
	var data = get_data("internal_skills")
	return data.get("internalSkills", [])

## 按区域获取场景列表
func get_scenes_by_region(region_id: String) -> Array:
	var data = get_data("world")
	for region in data.get("regions", []):
		if region["id"] == region_id:
			return region.get("scenes", [])
	return []

## 按 ID 获取任务
func get_quest(id: String) -> Dictionary:
	var data = get_data("quests")
	for category in ["mainQuests", "sideQuests", "dailyQuests"]:
		for quest in data.get(category, []):
			if quest["id"] == id:
				return quest
	return {}

## 按 ID 获取状态效果
func get_status_effect(id: String) -> Dictionary:
	var data = get_data("status_effects")
	for effect in data.get("statusEffects", []):
		if effect["id"] == id:
			return effect
	return {}