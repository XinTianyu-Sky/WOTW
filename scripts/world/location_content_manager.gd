# LocationContentManager.gd
# 位置内容管理器 — 从 world.json 查询当前位置的 NPC/怪物/资源
class_name LocationContentManager
extends RefCounted

static func get_cell_content(region_id: String, pos: Vector2i) -> Dictionary:
	var cell = DataManager.get_scene_by_grid_position(region_id, pos)
	if cell.is_empty():
		return {}
	var result = cell.duplicate()
	if cell.get("type") == "wilderness" and not cell.has("monsters"):
		result["monsters"] = _wilderness_monsters(region_id)
	if cell.get("type") == "wilderness" and not cell.has("resources"):
		result["resources"] = _wilderness_resources(region_id)
	return result

static func get_npcs_at(region_id: String, pos: Vector2i) -> Array:
	var cell = DataManager.get_scene_by_grid_position(region_id, pos)
	return cell.get("npcs", [])

static func get_monsters_at(region_id: String, pos: Vector2i) -> Array:
	var cell = DataManager.get_scene_by_grid_position(region_id, pos)
	if cell.is_empty():
		return []
	var monsters = cell.get("monsters", [])
	if monsters.is_empty() and cell.get("type") == "wilderness":
		monsters = _wilderness_monsters(region_id)
	return monsters

static func get_resources_at(region_id: String, pos: Vector2i) -> Array:
	var cell = DataManager.get_scene_by_grid_position(region_id, pos)
	if cell.is_empty():
		return []
	var resources = cell.get("resources", [])
	if resources.is_empty() and cell.get("type") == "wilderness":
		resources = _wilderness_resources(region_id)
	return resources

static func _wilderness_monsters(region_id: String) -> Array:
	var region = DataManager.get_region(region_id)
	var lr = region.get("levelRange", {"min": 1, "max": 5})
	var lmin = lr.get("min", 1)
	var lmax = lr.get("max", 5)
	return [
		{"monsterId": "bandit_thug", "minLevel": lmin, "maxLevel": clampi(lmin + 2, lmin, lmax), "spawnWeight": 0.5},
		{"monsterId": "wild_wolf", "minLevel": lmin, "maxLevel": clampi(lmin + 2, lmin, lmax), "spawnWeight": 0.35},
		{"monsterId": "poison_snake", "minLevel": clampi(lmin + 1, lmin, lmax), "maxLevel": clampi(lmin + 3, lmin, lmax), "spawnWeight": 0.15},
	]

static func _wilderness_resources(_region_id: String) -> Array:
	return ["zhixue_cao", "juqi_cao", "iron_ore", "copper_ore"]

## 从怪物模板构建敌人队伍
static func build_enemy_team(monster_data: Dictionary) -> Array:
	var templates = {
		"bandit_thug": {"name": "山贼喽啰", "skills": ["basic_stab"], "str_b": 5, "agi_b": 3, "con_b": 4, "int_b": 2, "wil_b": 2, "lck_b": 1, "color": Color(0.7, 0.2, 0.1)},
		"wild_wolf": {"name": "野狼", "skills": ["basic_strike"], "str_b": 5, "agi_b": 5, "con_b": 3, "int_b": 1, "wil_b": 2, "lck_b": 1, "color": Color(0.4, 0.35, 0.3)},
		"poison_snake": {"name": "毒蛇", "skills": ["basic_stab"], "str_b": 2, "agi_b": 6, "con_b": 2, "int_b": 1, "wil_b": 1, "lck_b": 1, "color": Color(0.1, 0.6, 0.2)},
		"bandit_chief": {"name": "山贼头目", "skills": ["basic_strike", "basic_stab"], "str_b": 8, "agi_b": 5, "con_b": 7, "int_b": 3, "wil_b": 4, "lck_b": 2, "color": Color(0.8, 0.15, 0.1)},
	}
	var mid = monster_data.get("monsterId", "bandit_thug")
	var t = templates.get(mid, templates["bandit_thug"])
	var lv = clampi(randi() % (monster_data.get("maxLevel", 3) - monster_data.get("minLevel", 1) + 1) + monster_data.get("minLevel", 1), 1, 99)

	var stats = PlayerStats.new()
	stats.str = t.str_b + lv
	stats.agi = t.agi_b + lv
	stats.con = t.con_b + lv
	stats.int_ = t.int_b + lv
	stats.wil = t.wil_b + lv
	stats.lck = t.lck_b + lv
	stats.level = lv
	stats.recalculate()
	stats.current_hp = stats.max_hp
	stats.current_qi = stats.max_qi

	var count = randi() % 2 + 1
	var team: Array = []
	for i in range(count):
		team.append({
			"id": "wild_%s_%d_%d" % [mid, Time.get_ticks_msec(), i],
			"name": t.name,
			"stats": stats,
			"skills": t.skills,
			"sprite": "",
		})
	return team

## 从可用怪物列表随机选一个触发战斗
static func pick_random_monster(monsters: Array) -> Dictionary:
	if monsters.is_empty():
		return {}
	var total: float = 0.0
	for m in monsters:
		total += m.get("spawnWeight", 0.5)
	var roll = randf() * total
	var cumulative: float = 0.0
	for m in monsters:
		cumulative += m.get("spawnWeight", 0.5)
		if roll <= cumulative:
			return m
	return monsters[0]
