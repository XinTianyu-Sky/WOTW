# CameraController.gd
# 摄像机控制器
# 跟随玩家、地图边界限制、平滑滚动、缩放
class_name CameraController
extends Camera2D

# ---- 参数 ----
@export var follow_speed: float = 5.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var map_bounds: Rect2 = Rect2(0, 0, 2000, 2000)

# ---- 引用 ----
var target: Node2D = null

func _ready() -> void:
	enabled = true
	# 尝试自动查找玩家
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _process(delta: float) -> void:
	if target == null:
		return

	# 平滑跟随
	var target_pos = target.global_position
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	# 地图边界限制
	_clamp_to_bounds()

	# 缩放控制（PC端鼠标滚轮）
	if InputMap.has_action("zoom_in") and Input.is_action_just_pressed("zoom_in"):
		_apply_zoom(-zoom_speed)
	if InputMap.has_action("zoom_out") and Input.is_action_just_pressed("zoom_out"):
		_apply_zoom(zoom_speed)

func set_target(new_target: Node2D) -> void:
	target = new_target

func set_map_bounds(bounds: Rect2) -> void:
	map_bounds = bounds

func _clamp_to_bounds() -> void:
	var viewport = get_viewport_rect()
	var half_w = viewport.size.x / (2 * zoom.x)
	var half_h = viewport.size.y / (2 * zoom.y)

	global_position.x = clamp(global_position.x, map_bounds.position.x + half_w, map_bounds.end.x - half_w)
	global_position.y = clamp(global_position.y, map_bounds.position.y + half_h, map_bounds.end.y - half_h)

func _apply_zoom(delta: float) -> void:
	var new_zoom = zoom.x + delta
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)