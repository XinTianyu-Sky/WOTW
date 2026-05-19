# Npc.gd
# NPC 控制器：显示、交互、对话触发
class_name Npc
extends StaticBody2D

@export var npc_name: String = "NPC"
@export var dialogue_id: String = ""
@export var shop_id: String = ""
@export var texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	add_to_group("interactable")
	if texture:
		sprite.texture = texture
	else:
		_generate_npc_sprite()

func _generate_npc_sprite() -> void:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var seed = npc_name.hash()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	var skin = Color(0.9, 0.78, 0.6).lightened(rng.randf_range(-0.1, 0.1))
	var robe_hue = rng.randf_range(0.0, 1.0)
	var robe = Color.from_hsv(robe_hue, 0.5, 0.6)
	var hair_c = Color.from_hsv(rng.randf_range(0.05, 0.15), 0.3, 0.3)
	# head
	for y in range(4, 12):
		for x in range(12, 20):
			if sqrt((x - 16) * (x - 16) + (y - 8) * (y - 8)) < 3.8:
				img.set_pixel(x, y, skin)
	# hair
	for y in range(3, 8):
		for x in range(11, 21):
			var dx = x - 16; var dy = y - 7
			if dx * dx + dy * dy < 16:
				img.set_pixel(x, y, hair_c)
	# robe
	for y in range(12, 28):
		for x in range(10, 22):
			img.set_pixel(x, y, robe)
	# belt
	for y in range(18, 20):
		for x in range(10, 22):
			img.set_pixel(x, y, robe.darkened(0.3))
	# legs
	for y in range(28, 32):
		for x in range(11, 15):
			img.set_pixel(x, y, Color(0.2, 0.15, 0.1))
		for x in range(17, 21):
			img.set_pixel(x, y, Color(0.2, 0.15, 0.1))
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex

func interact() -> void:
	if not shop_id.is_empty():
		EventBus.open_shop.emit(shop_id)
	elif not dialogue_id.is_empty():
		EventBus.dialogue_triggered.emit(dialogue_id, npc_name)
