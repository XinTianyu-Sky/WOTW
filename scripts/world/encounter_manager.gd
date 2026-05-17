# EncounterManager.gd
# 野外遇敌管理器
class_name EncounterManager
extends Node

const ENCOUNTER_RATES: Dictionary = {
    0: 0.03,  # grass
    1: 0.01,  # dirt
    4: 0.05,  # tree
}
const DEFAULT_ENCOUNTER_RATE: float = 0.0
const MIN_STEPS_BETWEEN: int = 20
const STEP_PX: float = 16.0  # 半格瓦片 = 一次"步"

var _player_ref: Node2D = null
var _tilemap: TileMapLayer = null
var _last_player_pos: Vector2 = Vector2(-1, -1)
var _accumulated_dist: float = 0.0
var _step_count: int = 0
var _steps_since_encounter: int = MIN_STEPS_BETWEEN

func setup(player: Node2D, tilemap: TileMapLayer) -> void:
    _player_ref = player
    _tilemap = tilemap
    _last_player_pos = player.global_position
    _accumulated_dist = 0.0

func check_encounter() -> bool:
    if not _player_ref or not _tilemap:
        return false

    var pos = _player_ref.global_position
    _accumulated_dist += pos.distance_to(_last_player_pos)
    _last_player_pos = pos

    if _accumulated_dist < STEP_PX:
        return false

    # 一步触发
    _accumulated_dist -= STEP_PX
    _step_count += 1
    _steps_since_encounter += 1

    if _steps_since_encounter < MIN_STEPS_BETWEEN:
        return false

    var tile_pos = _tilemap.local_to_map(pos)
    var source_id = _tilemap.get_cell_source_id(tile_pos)
    if source_id == -1:
        return false

    var atlas_coords = _tilemap.get_cell_atlas_coords(tile_pos)
    var tile_idx = atlas_coords.x
    var rate = ENCOUNTER_RATES.get(tile_idx, DEFAULT_ENCOUNTER_RATE)
    if rate <= 0.0:
        return false

    if randf() < rate:
        _steps_since_encounter = 0
        _accumulated_dist = 0.0
        return true

    return false

func build_enemy_team() -> Array:
    var player_lv = 1
    var stats = GameManager.player_data.get("_stats_ref", null)
    if stats:
        player_lv = stats.level

    var bandit_count = randi() % 2 + 1
    var team = []

    for i in range(bandit_count):
        var lv = player_lv + randi() % 3 - 1
        lv = max(1, lv)

        var enemy_stats = PlayerStats.new()
        enemy_stats.str = 4 + lv
        enemy_stats.agi = 3 + lv
        enemy_stats.con = 4 + lv
        enemy_stats.int_ = 2 + lv
        enemy_stats.wil = 2 + lv
        enemy_stats.lck = 1 + lv
        enemy_stats.level = lv
        enemy_stats.experience = 0
        enemy_stats.free_points = 0
        enemy_stats.recalculate()
        enemy_stats.current_hp = enemy_stats.max_hp
        enemy_stats.current_qi = enemy_stats.max_qi

        var data = {
            "id": "bandit_%d" % i,
            "name": "山贼喽啰",
            "stats": enemy_stats,
            "skills": ["basic_stab"],
            "sprite": "",
        }
        team.append(data)

    return team
