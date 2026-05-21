# GameManager.gd
# 游戏全局状态管理器 (Autoload)
# 管理游戏阶段、场景切换、全局状态
extends Node

# ---- 游戏阶段枚举 ----
enum GamePhase {
    MAIN_MENU,
    WORLD_EXPLORATION,
    BATTLE,
    DIALOGUE,
    MENU,
    CUTSCENE,
    LOADING
}

# ---- 全局状态 ----
var current_phase: GamePhase = GamePhase.MAIN_MENU
var current_scene: String = ""
var player_data: Dictionary = {}
var party_data: Array = []           # 出战同伴数据
var world_state: Dictionary = {}     # 世界状态（任务进度、旗帜等）
var settings: Dictionary = {}

# ---- 时间系统 ----
var game_time: float = 0.0           # 游戏内总秒数
var time_scale: float = 1.0          # 时间流速倍率
const SECONDS_PER_GAME_HOUR: float = 60.0  # 现实60秒 = 游戏1小时

# ---- 战斗临时数据 ----
var pending_battle: Dictionary = {}
var pending_return: Dictionary = {}   # 场景返回数据（从室内返回世界时使用）

# ---- 信号 ----
signal phase_changed(old_phase: GamePhase, new_phase: GamePhase)
signal scene_changed(scene_path: String)

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
    if current_phase == GamePhase.WORLD_EXPLORATION:
        game_time += delta * time_scale

# ---- 阶段切换 ----
func set_phase(new_phase: GamePhase) -> void:
    var old = current_phase
    current_phase = new_phase
    phase_changed.emit(old, new_phase)

# ---- 场景切换 ----
func change_scene(scene_path: String) -> void:
    current_scene = scene_path
    get_tree().change_scene_to_file(scene_path)
    scene_changed.emit(scene_path)

# ---- 战斗触发 ----
func start_battle(enemy_team: Array, terrain: Dictionary = {}) -> void:
    pending_battle = {
        "enemy_team": enemy_team,
        "terrain": terrain,
        "return_scene": current_scene,
    }
    set_phase(GamePhase.BATTLE)
    change_scene("res://scenes/battle/battle.tscn")

# ---- 游戏时间工具 ----
func get_game_hour() -> int:
    return int(game_time / SECONDS_PER_GAME_HOUR) % 24

func get_game_minute() -> int:
    return int((game_time / SECONDS_PER_GAME_HOUR) * 60) % 60

func get_game_day() -> int:
    return int(game_time / (SECONDS_PER_GAME_HOUR * 24))

func get_time_of_day() -> String:
    var hour = get_game_hour()
    if hour >= 5 and hour < 7:   return "dawn"
    if hour >= 7 and hour < 12:  return "morning"
    if hour >= 12 and hour < 17: return "afternoon"
    if hour >= 17 and hour < 19: return "dusk"
    if hour >= 19 and hour < 23: return "evening"
    return "night"

func get_current_season() -> String:
    var day = get_game_day()
    var season_day = day % 120  # 每季30天
    if season_day < 30:   return "spring"
    if season_day < 60:   return "summer"
    if season_day < 90:   return "autumn"
    return "winter"

func advance_game_time(hours: float) -> void:
    game_time += hours * SECONDS_PER_GAME_HOUR

# ---- 存档数据构建 ----
func build_save_data() -> Dictionary:
    _sync_stats_to_dict()
    _sync_equipment_to_dict()
    var save_player = player_data.duplicate(true)
    save_player.erase("_stats_ref")
    save_player.erase("_equipment")
    return {
        "version": "0.1.0",
        "game_time": game_time,
        "player_data": save_player,
        "party_data": party_data,
        "world_state": world_state,
        "current_scene": current_scene,
        "timestamp": Time.get_unix_time_from_system()
    }

func _sync_stats_to_dict() -> void:
    var stats = player_data.get("_stats_ref", null) as PlayerStats
    if not stats:
        return
    player_data["stats"] = stats.to_dict()

func _sync_equipment_to_dict() -> void:
    var eq = player_data.get("_equipment", null) as EquipmentManager
    if not eq:
        return
    player_data["_equipment_data"] = eq.to_dict()

func load_save_data(data: Dictionary) -> void:
    game_time = data.get("game_time", 0.0)
    player_data = data.get("player_data", {})
    party_data = data.get("party_data", [])
    world_state = data.get("world_state", {})
    current_scene = data.get("current_scene", "")
    # 清理旧存档残留的非对象字段
    player_data.erase("_stats_ref")
    if not (player_data.get("_equipment") is EquipmentManager):
        player_data.erase("_equipment")
    # 重建 EquipmentManager
    var eq_data = player_data.get("_equipment_data", {})
    if not eq_data.is_empty():
        var eq = EquipmentManager.new()
        eq.from_dict(eq_data)
        player_data["_equipment"] = eq
