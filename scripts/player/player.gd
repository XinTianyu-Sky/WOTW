# Player.gd
# 玩家角色控制器
# 处理移动、交互、动画
class_name Player
extends CharacterBody2D

# ---- 移动参数 ----
@export var walk_speed: float = 120.0
@export var run_speed: float = 200.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0

# ---- 组件引用 ----
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D = $InteractionArea

# ---- 状态 ----
var is_sprinting: bool = false
var is_interacting: bool = false
var can_move: bool = true

func _ready() -> void:
    add_to_group("player")

func _physics_process(_delta: float) -> void:
    if not can_move:
        return

    var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    is_sprinting = Input.is_action_pressed("sprint")

    var target_speed = run_speed if is_sprinting else walk_speed
    var target_velocity = input_dir * target_speed

    velocity = velocity.move_toward(target_velocity, acceleration if input_dir.length() > 0 else friction)
    move_and_slide()

    _update_animation(input_dir)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and can_move:
        _try_interact()

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