# ExitPortal.gd
# 室内出口 — 玩家踩上去或按 E 返回世界场景
class_name ExitPortal
extends Area2D

var _can_exit: bool = false
var _exiting: bool = false

func _ready() -> void:
	add_to_group("interactable")
	monitoring = true
	monitorable = true
	collision_layer = 1
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_exit = true
		_do_exit()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_exit = false

func interact() -> void:
	_do_exit()

func _do_exit() -> void:
	if _exiting:
		return
	_exiting = true
	set_deferred("monitoring", false)
	var ret = GameManager.pending_return
	GameManager.pending_return = {}
	var return_scene = ret.get("scene", "res://scenes/world/world.tscn")
	GameManager.change_scene(return_scene)
