# EncounterManager.gd
# 野外遇敌管理器
class_name EncounterManager
extends Node

# 不同地形的遇敌概率（每步）
const ENCOUNTER_RATES: Dictionary = {
	0: 0.06,  # grass
	1: 0.02,  # dirt
	4: 0.10,  # tree
}
const DEFAULT_ENCOUNTER_RATE: float = 0.0

# 最低步数间隔（防止连续遇敌）
const MIN_STEPS_BETWEEN: int = 8

var _player_ref: Node2D = null
var _tilemap: TileMapLayer = null
var _step_count: int = 0
var _steps_since_encounter: int = MIN_STEPS_BETWEEN
var _last_player_pos: Vector2 = Vector2(-1, -1)

func setup(player: Node2D, tilemap: TileMapLayer) -> void:
	_player_ref = player
	_tilemap = tilemap
	_last_player_pos = player.global_position

func check_encounter() -> bool:
	if not _player_ref or not _tilemap:
		return false

	var pos = _player_ref.global_position
	var dist = pos.distance_to(_last_player_pos)
	_last_player_pos = pos

	# 只有移动超过半个瓦片才计数
	if dist < 16.0:
		return false

	_step_count += 1
	_steps_since_encounter += 1

	# 步数冷却中
	if _steps_since_encounter < MIN_STEPS_BETWEEN:
		return false

	# 检查当前瓦片类型
	var tile_pos = _tilemap.local_to_map(pos)
	var tile_data = _tilemap.get_cell_tile_data(tile_pos)
	if not tile_data:
		return false

	# 通过瓦片坐标反推瓦片类型
	var source_id = _tilemap.get_cell_source_id(tile_pos)
	var atlas_coords = _tilemap.get_cell_atlas_coords(tile_pos)
	if source_id == -1:
		return false

	var tile_idx = atlas_coords.x
	var rate = ENCOUNTER_RATES.get(tile_idx, DEFAULT_ENCOUNTER_RATE)
	if rate <= 0.0:
		return false

	if randf() < rate:
		_steps_since_encounter = 0
		return true

	return false

func build_enemy_team() -> Array:
	# MVP 简单敌人：根据玩家等级生成
	var player_lv = 1
	var stats = GameManager.player_data.get("_stats_ref", null)
	if stats:
		player_lv = stats.level

	var bandit_count = randi() % 2 + 1  # 1-2个敌人
	var team = []

	for i in range(bandit_count):
		var lv = player_lv + randi() % 3 - 1  # ±1级
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
