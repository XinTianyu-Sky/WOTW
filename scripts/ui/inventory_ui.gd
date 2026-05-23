# InventoryUI.gd
# 背包界面控制器
extends CanvasLayer

@onready var panel: Panel = $InventoryPanel
@onready var grid_container: GridContainer = $InventoryPanel/ScrollContainer/GridContainer
@onready var item_detail: Control = $InventoryPanel/ItemDetail
@onready var close_btn: Button = $InventoryPanel/CloseBtn
@onready var equip_btn: Button = $InventoryPanel/ItemDetail/EquipBtn
@onready var use_btn: Button = $InventoryPanel/ItemDetail/UseBtn

var selected_item_id: String = ""
var _selected_item_data: Dictionary = {}

func _ready() -> void:
	hide()
	close_btn.pressed.connect(_close)
	EventBus.menu_opened.connect(_on_menu_opened)

func _close() -> void:
	hide()
	EventBus.menu_closed.emit("inventory")

func _on_menu_opened(menu_name: String) -> void:
	if menu_name == "inventory":
		show()
		_refresh_display()
	else:
		hide()

func _get_inventory() -> Array:
	return GameManager.inv_get_items()

func _refresh_display() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	var inventory_items = _get_inventory()
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
	_selected_item_data = item_data
	item_detail.get_node("ItemName").text = item_data.get("name", "")
	item_detail.get_node("ItemDescription").text = item_data.get("description", "")

	var stats_text = ""
	for stat in item_data.get("baseStats", {}):
		stats_text += "%s: +%d\n" % [stat, item_data["baseStats"][stat]]
	for stat in item_data.get("bonusStats", {}):
		stats_text += "%s: +%.0f%%\n" % [stat, item_data["bonusStats"][stat] * 100]
	item_detail.get_node("ItemStats").text = stats_text

	# 断开旧信号
	_disconnect_buttons()

	# 装备按钮
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
			equip_btn.pressed.connect(_do_equip.bind(slot_id, slot_enum, eq))
			equip_btn.show()
		else:
			equip_btn.hide()
	else:
		equip_btn.hide()

	# 使用按钮（消耗品、技能书）
	var item_type = item_data.get("type", "")
	if item_type in ["healing", "qiRestore", "buff", "cultivation", "skillBook"]:
		use_btn.text = "使用"
		use_btn.pressed.connect(_do_use.bind(item_data["id"]))
		use_btn.show()
	else:
		use_btn.hide()

func _disconnect_buttons() -> void:
	if equip_btn.pressed.is_connected(_do_equip):
		equip_btn.pressed.disconnect(_do_equip)
	if use_btn.pressed.is_connected(_do_use):
		use_btn.pressed.disconnect(_do_use)

func _do_use(item_id: String) -> void:
	var item_data = DataManager.get_item(item_id)
	if item_data.is_empty():
		return

	var item_type = item_data.get("type", "")

	# 技能书：学习武学
	if item_type == "skillBook":
		_learn_skill(item_data, item_id)
		return

	# 消耗品：应用效果
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if not stats:
		return

	var effects = item_data.get("effects", {})
	if effects.has("healAmount"):
		stats.current_hp = min(stats.current_hp + effects["healAmount"], stats.max_hp)
		NotificationManager.notify("恢复了 %d 生命值" % effects["healAmount"])
	if effects.has("qiRestore"):
		stats.current_qi = min(stats.current_qi + effects["qiRestore"], stats.max_qi)
		NotificationManager.notify("恢复了 %d 内力值" % effects["qiRestore"])
	if effects.has("attackBuff"):
		stats.attack += int(stats.attack * effects["attackBuff"])
		NotificationManager.notify("攻击力暂时提升")

	EventBus.attribute_changed.emit("hp", stats.current_hp)
	_remove_item(item_id)
	item_detail.hide()
	use_btn.hide()
	_refresh_display()

func _learn_skill(item_data: Dictionary, item_id: String) -> void:
	var skill_id = item_data.get("skillId", "")
	var skill_type = item_data.get("skillType", "")
	if skill_id.is_empty():
		return

	match skill_type:
		"external":
			var learned: Array = GameManager.player_data.get("learned_external", [])
			if skill_id in learned:
				NotificationManager.notify("已经学会此武学")
				return
			learned.append(skill_id)
			GameManager.player_data["learned_external"] = learned
			if GameManager.player_data.get("equipped_external", "").is_empty():
				GameManager.player_data["equipped_external"] = skill_id
		"internal":
			var learned: Array = GameManager.player_data.get("learned_internal", [])
			if skill_id in learned:
				NotificationManager.notify("已经学会此内功")
				return
			learned.append(skill_id)
			GameManager.player_data["learned_internal"] = learned
			if GameManager.player_data.get("equipped_internal", "").is_empty():
				GameManager.player_data["equipped_internal"] = skill_id
		"lightness":
			var learned: Array = GameManager.player_data.get("learned_lightness", [])
			if skill_id in learned:
				NotificationManager.notify("已经学会此轻功")
				return
			learned.append(skill_id)
			GameManager.player_data["learned_lightness"] = learned
			if GameManager.player_data.get("equipped_lightness", "").is_empty():
				GameManager.player_data["equipped_lightness"] = skill_id
		_:
			return

	EventBus.skill_learned.emit(skill_id)
	NotificationManager.notify("学会了 %s" % item_data.get("name", skill_id))
	_remove_item(item_id)
	item_detail.hide()
	use_btn.hide()
	_refresh_display()

func _remove_item(item_id: String) -> void:
	GameManager.inv_remove(item_id)

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
