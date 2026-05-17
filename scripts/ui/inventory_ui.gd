# InventoryUI.gd
# 背包界面控制器
extends CanvasLayer

@onready var panel: Panel = $InventoryPanel
@onready var grid_container: GridContainer = $InventoryPanel/ScrollContainer/GridContainer
@onready var item_detail: Control = $InventoryPanel/ItemDetail
@onready var close_btn: Button = $InventoryPanel/CloseBtn
@onready var equip_btn: Button = $InventoryPanel/ItemDetail/EquipBtn

var inventory_items: Array = []
var selected_item_id: String = ""

func _ready() -> void:
	hide()
	close_btn.pressed.connect(hide)
	EventBus.menu_opened.connect(_on_menu_opened)

func _on_menu_opened(menu_name: String) -> void:
	if menu_name == "inventory":
		show()
		_refresh_display()
	else:
		hide()

func _refresh_display() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	for item in inventory_items:
		var item_data = DataManager.get_item(item["id"])
		if item_data.is_empty():
			continue
		var slot = _create_item_slot(item_data, item.get("count", 1))
		grid_container.add_child(slot)

func _create_item_slot(item_data: Dictionary, count: int) -> Control:
	var btn = Button.new()
	var item_name = item_data.get("name", "???")
	# 检查是否已装备
	var eq = GameManager.player_data.get("_equipment", null) as EquipmentManager
	var is_equipped = false
	if eq and item_data.has("slot"):
		var slot_enum = eq.slot_from_string(item_data["slot"])
		if slot_enum != -1 and eq.get_equipped(slot_enum) == item_data["id"]:
			is_equipped = true
	btn.text = "%s x%d" % [item_name, count]
	if is_equipped:
		btn.text = "[E] %s x%d" % [item_name, count]
		btn.modulate = Color.GOLD
	else:
		btn.modulate = _get_rarity_color(item_data.get("rarity", "common"))
	btn.custom_minimum_size = Vector2(80, 80)
	btn.pressed.connect(func():
		selected_item_id = item_data["id"]
		_show_item_detail(item_data)
	)
	return btn

func _show_item_detail(item_data: Dictionary) -> void:
	item_detail.show()
	item_detail.get_node("ItemName").text = item_data.get("name", "")
	item_detail.get_node("ItemDescription").text = item_data.get("description", "")

	var stats_text = ""
	for stat in item_data.get("baseStats", {}):
		stats_text += "%s: +%d\n" % [stat, item_data["baseStats"][stat]]
	item_detail.get_node("ItemStats").text = stats_text

	# 装备按钮：每次展示时重新连接信号
	var eq = GameManager.player_data.get("_equipment", null) as EquipmentManager
	if item_data.has("slot") and eq:
		var slot_str = item_data["slot"]
		var slot_id = item_data["id"]
		var slot_enum = eq.slot_from_string(slot_str)
		if slot_enum != -1:
			if eq.get_equipped(slot_enum) == slot_id:
				equip_btn.text = "卸下"
			else:
				equip_btn.text = "装备"
			# 断开旧连接，连新连接
			if equip_btn.pressed.is_connected(_do_equip):
				equip_btn.pressed.disconnect(_do_equip)
			equip_btn.pressed.connect(_do_equip.bind(slot_id, slot_enum, eq))
			equip_btn.show()
			return
	equip_btn.hide()

func _do_equip(item_id: String, slot_enum: int, eq: EquipmentManager) -> void:
	if eq.get_equipped(slot_enum) == item_id:
		eq.unequip(slot_enum)
	else:
		eq.equip(item_id)
	item_detail.hide()
	_refresh_display()

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color.WHITE
		"uncommon":  return Color.GREEN
		"rare":      return Color.BLUE
		"epic":      return Color.PURPLE
		"legendary": return Color.ORANGE
		"mythic":    return Color.GOLD
		_:           return Color.WHITE
