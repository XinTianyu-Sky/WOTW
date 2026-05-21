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

	# 连接休息按钮
	var rest_btn = get_node_or_null("UILayer/RestBtn")
	if rest_btn:
		rest_btn.pressed.connect(_on_rest_pressed)

func _on_exit_pressed() -> void:
	var ret = GameManager.pending_return
	GameManager.pending_return = {}
	GameManager.change_scene(ret.get("scene", "res://scenes/world/world.tscn"))

func _on_rest_pressed() -> void:
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if not stats:
		return
	if stats.current_hp >= stats.max_hp and stats.current_qi >= stats.max_qi:
		NotificationManager.notify("不需要休息")
		return
	stats.current_hp = stats.max_hp
	stats.current_qi = stats.max_qi
	EventBus.attribute_changed.emit("hp", stats.current_hp)
	GameManager.advance_game_time(2)
	NotificationManager.notify("小憩片刻，精神焕发", "success")
