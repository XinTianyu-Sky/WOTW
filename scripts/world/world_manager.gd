# WorldManager.gd
# 世界系统管理器
# 管理天气、昼夜、场景状态
class_name WorldManager
extends Node

# ---- 天气枚举 ----
enum Weather {
	CLEAR, CLOUDY, LIGHT_RAIN, HEAVY_RAIN, STORM,
	LIGHT_SNOW, BLIZZARD, SANDSTORM, MIASMA, METEOR_SHOWER
}

const WEATHER_NAMES: Dictionary = {
	Weather.CLEAR: "clear",
	Weather.CLOUDY: "cloudy",
	Weather.LIGHT_RAIN: "light_rain",
	Weather.HEAVY_RAIN: "heavy_rain",
	Weather.STORM: "storm",
	Weather.LIGHT_SNOW: "light_snow",
	Weather.BLIZZARD: "blizzard",
	Weather.SANDSTORM: "sandstorm",
	Weather.MIASMA: "miasma",
	Weather.METEOR_SHOWER: "meteor_shower",
}

# ---- 状态 ----
var current_weather: Weather = Weather.CLEAR
var current_region_id: String = ""
var current_scene_id: String = ""
var weather_timer: float = 0.0
var weather_duration: float = 0.0
var region_weather_pool: Array = []

# ---- 场景容器 ----
var world_scene: Node2D = null

func _ready() -> void:
	EventBus.scene_entered.connect(_on_scene_entered)
	EventBus.battle_ended.connect(_on_battle_ended)
	_init_player()
	_restore_return_position()
	_init_hud()
	_init_equipment()
	GameManager.set_phase(GameManager.GamePhase.WORLD_EXPLORATION)
	# 进入世界自动存档
	SaveManager.auto_save()

func _init_player() -> void:
	if GameManager.player_data.is_empty():
		return
	# 复用已有 PlayerStats 引用（战斗返回时保留 HP/QI 变化）
	var existing = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if existing:
		return
	var stats_data = GameManager.player_data.get("stats", {})
	if stats_data.is_empty():
		return
	var stats = PlayerStats.new()
	stats.from_dict(stats_data)
	GameManager.player_data["_stats_ref"] = stats

func _init_equipment() -> void:
	var existing = GameManager.player_data.get("_equipment", null) as EquipmentManager
	if existing:
		# 读档恢复的，只需重连信号
		EventBus.equipment_changed.connect(func(_slot, _id):
			var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
			if stats:
				stats.update_equipment_bonuses(existing.get_total_bonuses())
		)
		return
	var eq = EquipmentManager.new()
	GameManager.player_data["_equipment"] = eq
	EventBus.equipment_changed.connect(func(_slot, _id):
		var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
		if stats:
			stats.update_equipment_bonuses(eq.get_total_bonuses())
	)

func _restore_return_position() -> void:
	var ret = GameManager.pending_return
	if ret.is_empty():
		return
	var player = get_node_or_null("Player")
	if player:
		player.global_position = ret.get("position", Vector2(208, 336))
	GameManager.pending_return = {}

func _init_hud() -> void:
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if not stats:
		return
	var hud = get_node_or_null("HUDLayer/HUD")
	if hud and hud.has_method("set_player_stats"):
		hud.set_player_stats(stats)

	# 角色面板
	var char_sheet = get_node_or_null("UILayer/CharacterSheetUI")
	if char_sheet and char_sheet.has_method("set_stats"):
		char_sheet.set_stats(stats)

	# 背包面板 — 直接从 GameManager 读取，无需初始化

	# 武学面板
	var skills_ui = get_node_or_null("UILayer/SkillsUI")
	if skills_ui:
		skills_ui.learned_external = GameManager.player_data.get("learned_external", [])
		skills_ui.learned_internal = GameManager.player_data.get("learned_internal", [])
		skills_ui.learned_lightness = GameManager.player_data.get("learned_lightness", [])
		skills_ui.equipped_external = GameManager.player_data.get("equipped_external", "")
		skills_ui.equipped_internal = GameManager.player_data.get("equipped_internal", "")
		skills_ui.equipped_lightness = GameManager.player_data.get("equipped_lightness", "")

	# 商店
	var shop_ui = get_node_or_null("UILayer/ShopUI")
	if shop_ui:
		EventBus.open_shop.connect(func(sid: String): shop_ui.open_shop(sid))

func _process(delta: float) -> void:
	if GameManager.current_phase != GameManager.GamePhase.WORLD_EXPLORATION:
		return

	weather_timer += delta
	if weather_timer >= weather_duration:
		_roll_new_weather()

	# F5 快速存档
	if Input.is_action_just_pressed("quick_save"):
		SaveManager.save_game(0)

# ---- 战斗结果处理 ----
func _on_battle_ended(result: Dictionary) -> void:
	if result.get("result") != "victory":
		return
	var defeated = result.get("defeated_enemies", [])
	if defeated.is_empty():
		return

	# Boss击杀奖励
	for name in defeated:
		if name == "山贼头目":
			_boss_reward(name)
		elif name == "山贼":
			pass

	# 任务击杀目标追踪
	var active = GameManager.world_state.get("active_quests", [])
	for qid in active:
		var qdata = DataManager.get_quest(qid)
		if qdata.is_empty():
			continue
		var objs = qdata.get("objectives", [])
		for i in range(objs.size()):
			var obj = objs[i]
			if obj.get("type") != "kill":
				continue
			var progress = GameManager.world_state.get("quest_progress", {}).get(qid, [])
			if progress.has(i):
				continue
			var target = obj.get("targetId", "")
			for name in defeated:
				if name == target or target.is_empty():
					progress.append(i)
					GameManager.world_state["quest_progress"] = GameManager.world_state.get("quest_progress", {})
					GameManager.world_state["quest_progress"][qid] = progress
					EventBus.quest_progressed.emit(qid, i)
					_check_kill_quest_completion(qid, objs, progress)
					break

func _boss_reward(boss_name: String) -> void:
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	match boss_name:
		"山贼头目":
			if GameManager.world_state.get("boss_bandit_defeated", false):
				return
			GameManager.world_state["boss_bandit_defeated"] = true
			if stats:
				stats.add_experience(150)
			var copper = GameManager.player_data.get("copper", 0)
			GameManager.player_data["copper"] = copper + 300
			var inv: Array = GameManager.player_data.get("inventory", [])
			inv.append("iron_sword")
			GameManager.player_data["inventory"] = inv
			NotificationManager.notify("击败山贼头目！获得 铁剑 + 300铜钱", "success")

func _check_kill_quest_completion(qid: String, objectives: Array, completed_indices: Array) -> void:
	if completed_indices.size() >= objectives.size():
		EventBus.quest_completed.emit(qid)

# ---- 场景切换 ----
func _on_scene_entered(scene_id: String) -> void:
	current_scene_id = scene_id
	var scene_data = _find_scene_data(scene_id)
	if scene_data.is_empty():
		return

	# 更新区域天气池
	var region = _find_region_for_scene(scene_id)
	if not region.is_empty():
		current_region_id = region["id"]
		region_weather_pool = region.get("weatherPool", [])
		_roll_new_weather()

func _find_scene_data(scene_id: String) -> Dictionary:
	var world = DataManager.get_data("world")
	for region in world.get("regions", []):
		for scene in region.get("scenes", []):
			if scene["id"] == scene_id:
				return scene
	return {}

func _find_region_for_scene(scene_id: String) -> Dictionary:
	var world = DataManager.get_data("world")
	for region in world.get("regions", []):
		for scene in region.get("scenes", []):
			if scene["id"] == scene_id:
				return region
	return {}

# ---- 天气系统 ----
func _roll_new_weather() -> void:
	if region_weather_pool.is_empty():
		return

	var total_weight: float = 0.0
	for w in region_weather_pool:
		total_weight += w["weight"]

	var roll = randf() * total_weight
	var cumulative: float = 0.0
	for w in region_weather_pool:
		cumulative += w["weight"]
		if roll <= cumulative:
			var new_weather_str = w["weather"]
			var new_weather = _weather_from_string(new_weather_str)
			if new_weather != current_weather:
				var old_str = WEATHER_NAMES[current_weather]
				current_weather = new_weather
				EventBus.weather_changed.emit(old_str, new_weather_str)
			break

	weather_duration = randf_range(120.0, 480.0)  # 2-8分钟（游戏时间2-8小时）
	weather_timer = 0.0

func _weather_from_string(s: String) -> Weather:
	for key in WEATHER_NAMES:
		if WEATHER_NAMES[key] == s:
			return key
	return Weather.CLEAR

func get_weather_combat_modifiers() -> Dictionary:
	var world = DataManager.get_data("world")
	var weather_rules = world.get("weatherRules", {}).get("weatherEffects", {})
	var weather_str = WEATHER_NAMES[current_weather]
	return weather_rules.get(weather_str, {}).get("combatModifiers", {})

func get_weather_exploration_modifiers() -> Dictionary:
	var world = DataManager.get_data("world")
	var weather_rules = world.get("weatherRules", {}).get("weatherEffects", {})
	var weather_str = WEATHER_NAMES[current_weather]
	return weather_rules.get(weather_str, {}).get("explorationModifiers", {})

# ---- 时间相关 ----
func get_current_light_modifier() -> float:
	var hour = GameManager.get_game_hour()
	if hour >= 7 and hour < 17:  return 1.0   # 白天
	if hour >= 5 and hour < 7:   return 0.6   # 清晨
	if hour >= 17 and hour < 19: return 0.7   # 傍晚
	if hour >= 19 and hour < 23: return 0.3   # 夜晚
	return 0.15  # 深夜

func is_night_time() -> bool:
	var hour = GameManager.get_game_hour()
	return hour < 5 or hour >= 19

func get_monster_power_multiplier() -> float:
	var hour = GameManager.get_game_hour()
	if hour >= 19 and hour < 23: return 1.2
	if hour >= 23 or hour < 5:   return 1.3
	return 1.0
