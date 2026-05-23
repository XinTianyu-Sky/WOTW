# EnemySpawner.gd
# 固定位置野怪刷新点 — 玩家靠近按 E 触发战斗
class_name EnemySpawner
extends StaticBody2D

@export var min_level: int = 1
@export var max_level: int = 3
@export var respawn_minutes: float = 1.0  # 现实分钟
@export var spawner_id: String = ""

const TEMPLATES: Array[Dictionary] = [
	{ "name": "山贼喽啰", "skills": ["basic_stab"],   "str_b": 5, "agi_b": 3, "con_b": 4, "int_b": 2, "wil_b": 2, "lck_b": 1, "weight": 5, "color": Color(0.7, 0.2, 0.1) },
	{ "name": "野狼",     "skills": ["basic_strike"], "str_b": 5, "agi_b": 5, "con_b": 3, "int_b": 1, "wil_b": 2, "lck_b": 1, "weight": 3, "color": Color(0.4, 0.35, 0.3) },
	{ "name": "毒蛇",     "skills": ["basic_stab"],   "str_b": 2, "agi_b": 6, "con_b": 2, "int_b": 1, "wil_b": 1, "lck_b": 1, "weight": 2, "color": Color(0.1, 0.6, 0.2) },
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var respawn_timer: Timer = $RespawnTimer

func _ready() -> void:
	add_to_group("interactable")
	if spawner_id.is_empty():
		spawner_id = "spawner_%d_%d" % [int(global_position.x), int(global_position.y)]

	_generate_sprite()
	_check_cooldown()
	respawn_timer.timeout.connect(_on_respawn)

func _generate_sprite() -> void:
	var img = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	var base = Color(0.35, 0.3, 0.25)
	for y in range(28):
		for x in range(28):
			var dx = x - 14
			var dy = y - 18
			if dx * dx + dy * dy < 100:
				img.set_pixel(x, y, base)
	# 眼睛
	img.set_pixel(11, 8, Color.RED)
	img.set_pixel(16, 8, Color.RED)
	# 嘴
	for x in range(10, 18):
		img.set_pixel(x, 14, Color.BLACK)
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.scale = Vector2(1.2, 1.2)

func _check_cooldown() -> void:
	var cd = GameManager.world_state.get("spawner_cooldowns", {}).get(spawner_id, 0.0)
	var now = Time.get_ticks_msec() / 1000.0
	if now < cd:
		_set_active(false)
		respawn_timer.start(cd - now)
	else:
		_set_active(true)

func interact() -> void:
	if not visible:
		return
	# 构建随机敌人队伍
	var enemy_team = _build_enemy_team()
	GameManager.start_battle(enemy_team)
	# 战斗结束后会重新加载场景，cooldown 在 _ready 中检查
	_start_cooldown()

func _build_enemy_team() -> Array:
	var player_lv = 1
	var stats = GameManager.player_data.get("_stats_ref", null)
	if stats:
		player_lv = stats.level

	var total_weight = 0
	for t in TEMPLATES:
		total_weight += t.weight
	var roll = randi() % total_weight
	var template: Dictionary = TEMPLATES[0]
	var cumulative = 0
	for t in TEMPLATES:
		cumulative += t.weight
		if roll < cumulative:
			template = t
			break

	var lv = clampi(randi() % (max_level - min_level + 1) + min_level, 1, 99)
	var enemy_stats = PlayerStats.new()
	enemy_stats.str = template.str_b + lv
	enemy_stats.agi = template.agi_b + lv
	enemy_stats.con = template.con_b + lv
	enemy_stats.int_ = template.int_b + lv
	enemy_stats.wil = template.wil_b + lv
	enemy_stats.lck = template.lck_b + lv
	enemy_stats.level = lv
	enemy_stats.recalculate()
	enemy_stats.current_hp = enemy_stats.max_hp
	enemy_stats.current_qi = enemy_stats.max_qi

	var count = randi() % 2 + 1
	var team: Array = []
	for i in range(count):
		team.append({
			"id": "spawn_%s_%d" % [spawner_id, i],
			"name": template.name,
			"stats": enemy_stats,
			"skills": template.skills,
			"sprite": "",
		})
	return team

func _start_cooldown() -> void:
	var cd_seconds = respawn_minutes * 60.0
	var cd_end = Time.get_ticks_msec() / 1000.0 + cd_seconds
	var cds = GameManager.world_state.get("spawner_cooldowns", {})
	cds[spawner_id] = cd_end
	GameManager.world_state["spawner_cooldowns"] = cds

func _on_respawn() -> void:
	_set_active(true)

func _set_active(active: bool) -> void:
	visible = active
	if interaction_area:
		interaction_area.monitoring = active
		interaction_area.monitorable = active
