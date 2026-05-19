# InteriorScene.gd
# 室内场景基控制器
class_name InteriorScene
extends Node2D

@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	GameManager.set_phase(GameManager.GamePhase.WORLD_EXPLORATION)
	if player and player.has_method("set_can_move"):
		player.set_can_move(true)

	# 连接出口按钮
	var exit_btn = get_node_or_null("UILayer/ExitBtn")
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)

func _on_exit_pressed() -> void:
	var ret = GameManager.pending_return
	GameManager.pending_return = {}
	GameManager.change_scene(ret.get("scene", "res://scenes/world/world.tscn"))
