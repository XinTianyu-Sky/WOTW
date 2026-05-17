# Player.gd
# 玩家角色控制器
# 支持 WASD/方向键 + 鼠标点击移动
class_name Player
extends CharacterBody2D

@export var walk_speed: float = 120.0
@export var run_speed: float = 200.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0
@export var click_stop_distance: float = 8.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D = $InteractionArea

var is_sprinting: bool = false
var is_interacting: bool = false
var can_move: bool = true

# ---- 鼠标点击移动 ----
var _target_position: Vector2 = Vector2.ZERO
var _use_click_move: bool = false

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	if not can_move:
		return

	if _use_click_move:
		_move_toward_click()
	else:
		_move_by_input()

func _move_toward_click() -> void:
	var to_target = _target_position - global_position
	if to_target.length() < click_stop_distance:
		_use_click_move = false
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return

	var input_dir = to_target.normalized()
	var target_velocity = input_dir * run_speed
	velocity = velocity.move_toward(target_velocity, acceleration)
	move_and_slide()
	_update_animation(input_dir)

func _move_by_input() -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 键盘输入打断鼠标移动
	if input_dir.length() > 0.1:
		_use_click_move = false

	is_sprinting = Input.is_action_pressed("sprint")
	var target_speed = run_speed if is_sprinting else walk_speed
	var target_velocity = input_dir * target_speed
	velocity = velocity.move_toward(target_velocity, acceleration if input_dir.length() > 0 else friction)
	move_and_slide()
	_update_animation(input_dir)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_move:
		_try_interact()

func _unhandled_input(event: InputEvent) -> void:
	# 鼠标左键点击移动到目标位置（仅未被 UI 消费时）
	if not can_move:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos = get_global_mouse_position()
		# 限制在地图范围内
		var bounds = _get_map_bounds()
		_target_position = click_pos.clamp(bounds.position, bounds.end)
		# 太近不移动
		if _target_position.distance_to(global_position) > click_stop_distance:
			_use_click_move = true

func _get_map_bounds() -> Rect2:
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("set_map_bounds"):
		return cam.map_bounds
	return Rect2(0, 0, 1280, 960)

func _update_animation(input_dir: Vector2) -> void:
	if input_dir.length() > 0.1:
		var anim = "walk"
		if is_sprinting: anim = "run"
		if input_dir.x > 0.5: anim += "_right"
		elif input_dir.x < -0.5: anim += "_left"
		elif input_dir.y > 0.5: anim += "_down"
		elif input_dir.y < -0.5: anim += "_up"
		if animation_player.has_animation(anim):
			animation_player.play(anim)
	else:
		if animation_player.has_animation("idle"):
			animation_player.play("idle")

func _try_interact() -> void:
	var areas = interaction_area.get_overlapping_areas()
	for area in areas:
		if area.is_in_group("interactable"):
			area.get_parent().interact()
			return
	var bodies = interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("interactable"):
			body.interact()
			return

func set_can_move(value: bool) -> void:
	can_move = value
	if not can_move:
		velocity = Vector2.ZERO
		_use_click_move = false
