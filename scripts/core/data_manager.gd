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

## 获取所有配方
func get_recipes() -> Array:
	var data = get_data("items")
	return data.get("recipes", [])

## 按 ID 获取配方
func get_recipe(id: String) -> Dictionary:
	for recipe in get_recipes():
		if recipe["id"] == id:
			return recipe
	return {}

# ---- 网格地图查询 ----

## 获取区域的网格地图数据
func get_region_grid(region_id: String) -> Dictionary:
	var data = get_data("world")
	for region in data.get("regions", []):
		if region["id"] == region_id:
			return region.get("gridMap", {})
	return {}

## 根据网格坐标查找场景
func get_scene_by_grid_position(region_id: String, pos: Vector2i) -> Dictionary:
	var data = get_data("world")
	for region in data.get("regions", []):
		if region["id"] != region_id:
			continue
		for scene in region.get("scenes", []):
			var gp = scene.get("gridPosition", {})
			if gp.get("x", -1) == pos.x and gp.get("y", -1) == pos.y:
				return scene
		for wc in region.get("wildernessCells", []):
			if wc.get("x", -1) == pos.x and wc.get("y", -1) == pos.y:
				return {"id": "wilderness_%d_%d" % [pos.x, pos.y], "name": wc.get("name", "荒野"), "type": "wilderness", "terrain": wc.get("terrain", "plains"), "isSafeZone": false}
		break
	return {}

## 获取相邻可达格子列表
func get_adjacent_locations(region_id: String, pos: Vector2i) -> Array[Vector2i]:
	var grid = get_region_grid(region_id)
	if grid.is_empty():
		return []
	var w: int = grid.get("width", 12)
	var h: int = grid.get("height", 10)
	var adj: Array[Vector2i] = []
	for d in [[0, -1], [1, 0], [0, 1], [-1, 0]]:
		var nx = pos.x + d[0]
		var ny = pos.y + d[1]
		if nx >= 0 and nx < w and ny >= 0 and ny < h:
			adj.append(Vector2i(nx, ny))
	return adj

## 获取区域数据
func get_region(region_id: String) -> Dictionary:
	var data = get_data("world")
	for region in data.get("regions", []):
		if region["id"] == region_id:
			return region
	return {}

## 获取区域所有 location（scene + wildernessCells 合并坐标索引）
func get_region_locations_index(region_id: String) -> Dictionary:
	var region = get_region(region_id)
	if region.is_empty():
		return {}
	var index: Dictionary = {}
	for scene in region.get("scenes", []):
		var gp = scene.get("gridPosition", {})
		var key = "%d,%d" % [gp.get("x", 0), gp.get("y", 0)]
		index[key] = scene
	for wc in region.get("wildernessCells", []):
		var key = "%d,%d" % [wc.get("x", 0), wc.get("y", 0)]
		if not index.has(key):
			index[key] = {"id": "wilderness_%s" % key.replace(",", "_"), "name": wc.get("name", "荒野"), "type": "wilderness", "terrain": wc.get("terrain", "plains"), "isSafeZone": false, "monsters": wc.get("monsters", []), "resources": wc.get("resources", [])}
	return index
