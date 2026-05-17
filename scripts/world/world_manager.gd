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

# ---- 遇敌 ----
var encounter_manager: EncounterManager = null

func _ready() -> void:
	EventBus.scene_entered.connect(_on_scene_entered)
	_init_player()
	_init_hud()
	_setup_encounter()

func _setup_encounter() -> void:
	encounter_manager = EncounterManager.new()
	add_child(encounter_manager)
	var player = get_node_or_null("Player")
	var tilemap = get_node_or_null("TileMapLayer")
	if player and tilemap:
		encounter_manager.setup(player, tilemap)

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

func _init_hud() -> void:
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if not stats:
		return
	var hud = get_node_or_null("HUDLayer/HUD")
	if hud and hud.has_method("set_player_stats"):
		hud.set_player_stats(stats)

func _process(delta: float) -> void:
	weather_timer += delta
	if weather_timer >= weather_duration:
		_roll_new_weather()

	# 遇敌检测
	if encounter_manager and encounter_manager.check_encounter():
		_trigger_encounter()

func _trigger_encounter() -> void:
	var enemy_team = encounter_manager.build_enemy_team()
	var player_team = _build_player_team()
	var terrain = {"weather": WEATHER_NAMES[current_weather]}
	GameManager.start_battle(enemy_team, terrain)

func _build_player_team() -> Array:
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if not stats:
		return []
	var skill_id = GameManager.player_data.get("equipped_external", "")
	return [{
		"id": "player",
		"name": GameManager.player_data.get("name", "主角"),
		"stats": stats,
		"skills": [skill_id] if not skill_id.is_empty() else [],
		"sprite": "",
	}]

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