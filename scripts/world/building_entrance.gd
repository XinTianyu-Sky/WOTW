# BuildingEntrance.gd
# 建筑入口 — 玩家靠近按 E 进入室内场景
class_name BuildingEntrance
extends StaticBody2D

@export var interior_scene: String = ""
@export var exit_position: Vector2 = Vector2.ZERO
@export var entrance_label: String = "进入"

@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	add_to_group("interactable")
	_generate_sprite()

func _generate_sprite() -> void:
	var img = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	var wood = Color(0.45, 0.25, 0.1)
	var dark = Color(0.25, 0.12, 0.05)
	for y in range(16):
		for x in range(32):
			if y < 2 or y > 13 or x < 2 or x > 29:
				img.set_pixel(x, y, dark)
			else:
				img.set_pixel(x, y, wood)
	# door frame
	for y in range(2, 14):
		for x in range(10, 22):
			img.set_pixel(x, y, dark.darkened(0.2))
	var tex = ImageTexture.create_from_image(img)
	$Sprite2D.texture = tex
	$Sprite2D.scale = Vector2(1.2, 1.2)

func interact() -> void:
	if interior_scene.is_empty():
		return

	GameManager.pending_return = {
		"scene": GameManager.current_scene,
		"position": exit_position,
	}
	GameManager.change_scene(interior_scene)
