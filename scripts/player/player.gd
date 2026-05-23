# Player.gd
# 玩家角色控制器
# WASD/方向键移动，空格交互
class_name Player
extends CharacterBody2D

@export var walk_speed: float = 120.0
@export var run_speed: float = 200.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D = $InteractionArea

var is_sprinting: bool = false
var is_interacting: bool = false
var can_move: bool = true
var _last_interactable: Object = null

func _ready() -> void:
	add_to_group("player")
	_generate_player_sprite()
	interaction_area.area_entered.connect(_on_interact_area_entered)
	interaction_area.body_entered.connect(_on_interact_body_entered)
	interaction_area.area_exited.connect(_on_interact_area_exited)
	interaction_area.body_exited.connect(_on_interact_body_exited)
	GameManager.phase_changed.connect(func(_old, new):
		can_move = (new == GameManager.GamePhase.WORLD_EXPLORATION)
		if not can_move:
			velocity = Vector2.ZERO
	)
	EventBus.menu_opened.connect(func(_name): set_can_move(false))
	EventBus.menu_closed.connect(func(_name): set_can_move(true))

func _generate_player_sprite() -> void:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin = Color(0.92, 0.8, 0.65)
	var hair = Color(0.08, 0.06, 0.05)
	var robe = Color(0.25, 0.35, 0.5)
	var belt = Color(0.55, 0.4, 0.2)
	for y in range(4, 12):
		for x in range(12, 20):
			if sqrt((x - 16) * (x - 16) + (y - 8) * (y - 8)) < 3.8:
				img.set_pixel(x, y, skin)
	for y in range(3, 8):
		for x in range(11, 21):
			var dx = x - 16
			var dy = y - 7
			if dx * dx + dy * dy < 16:
				img.set_pixel(x, y, hair)
	for y in range(12, 28):
		for x in range(10, 22):
			img.set_pixel(x, y, robe)
	for y in range(18, 20):
		for x in range(10, 22):
			img.set_pixel(x, y, belt)
	for y in range(28, 32):
		for x in range(11, 15):
			img.set_pixel(x, y, Color(0.2, 0.15, 0.1))
		for x in range(17, 21):
			img.set_pixel(x, y, Color(0.2, 0.15, 0.1))

	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex

func _physics_process(_delta: float) -> void:
	if not can_move:
		return
	_move_by_input()

func _move_by_input() -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_sprinting = Input.is_action_pressed("sprint")
	var target_speed = run_speed if is_sprinting else walk_speed
	var target_velocity = input_dir * target_speed
	velocity = velocity.move_toward(target_velocity, acceleration if input_dir.length() > 0 else friction)
	move_and_slide()
	_update_animation(input_dir)

func _on_interact_area_entered(area: Area2D) -> void:
	_try_auto_interact(area)

func _on_interact_body_entered(body: Node2D) -> void:
	_try_auto_interact(body)

func _on_interact_area_exited(area: Area2D) -> void:
	if area == _last_interactable or area.get_parent() == _last_interactable:
		_last_interactable = null

func _on_interact_body_exited(body: Node2D) -> void:
	if body == _last_interactable:
		_last_interactable = null

func _try_auto_interact(node: Node) -> void:
	if not can_move:
		return
	if node == _last_interactable:
		return
	var target: Node = node
	if not target.is_in_group("interactable"):
		if target is Area2D and target.get_parent().is_in_group("interactable"):
			target = target.get_parent()
		else:
			return
	if target == _last_interactable:
		return
	_last_interactable = target
	if target.has_method("interact"):
		target.call_deferred("interact")

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

func set_can_move(value: bool) -> void:
	can_move = value
	if not can_move:
		velocity = Vector2.ZERO
