# Gatherable.gd
# 可采集资源节点 — 矿石、草药等
class_name Gatherable
extends StaticBody2D

@export var item_id: String = ""
@export var respawn_time: float = 30.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var timer: Timer = $RespawnTimer

var _gathered: bool = false

func _ready() -> void:
	add_to_group("interactable")
	timer.timeout.connect(_respawn)
	_generate_sprite()

func _generate_sprite() -> void:
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var item_data = DataManager.get_item(item_id)
	var item_type = item_data.get("type", "material")
	var base_color: Color
	if item_id.contains("ore"):
		base_color = Color(0.55, 0.45, 0.35)
	else:
		base_color = Color(0.22, 0.55, 0.28)
	# rock or plant shape
	for y in range(4, 22):
		for x in range(2, 22):
			var cx = 12; var cy = 13
			var r = 9.0 + sin(x * 0.5 + y * 0.3) * 2.0
			if sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) < r:
				var n = (sin(x * 1.7 + y * 2.1) * 0.05)
				var c = base_color
				c.r = clamp(c.r + n, 0.0, 1.0)
				c.g = clamp(c.g + n, 0.0, 1.0)
				c.b = clamp(c.b + n * 0.5, 0.0, 1.0)
				img.set_pixel(x, y, c)
	# sparkle dot
	img.set_pixel(8, 10, Color(1, 1, 0.7, 0.7))
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.scale = Vector2(0.8, 0.8)

func interact() -> void:
	if _gathered:
		return

	var item_data = DataManager.get_item(item_id)
	if item_data.is_empty():
		return

GameManager.inv_add(item_id)

	NotificationManager.notify("获得 %s" % item_data.get("name", item_id))
	EventBus.item_gathered.emit(item_id)

	_gathered = true
	sprite.hide()
	timer.start(respawn_time)

func _respawn() -> void:
	_gathered = false
	sprite.show()
