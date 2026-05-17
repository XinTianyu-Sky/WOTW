# Npc.gd
# NPC 控制器：显示、交互、对话触发
class_name Npc
extends StaticBody2D

@export var npc_name: String = "NPC"
@export var dialogue_id: String = ""
@export var texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	add_to_group("interactable")
	if texture:
		sprite.texture = texture

func interact() -> void:
	if dialogue_id.is_empty():
		return
	EventBus.dialogue_triggered.emit(dialogue_id)
