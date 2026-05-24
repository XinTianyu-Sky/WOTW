# LocationPanel.gd
# 当前位置内容面板：NPC列表 / 资源采集 / 探索遇敌 / 设施
extends Panel

@onready var title_label: Label = %TitleLabel
@onready var desc_label: Label = %DescLabel
@onready var npc_container: VBoxContainer = %NpcContainer
@onready var resource_container: VBoxContainer = %ResourceContainer
@onready var explore_btn: Button = %ExploreBtn
@onready var inn_btn: Button = %InnBtn
@onready var shop_btn: Button = %ShopBtn
@onready var craft_btn: Button = %CraftBtn

var _current_cell_data: Dictionary = {}
var _current_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	EventBus.grid_cell_entered.connect(_on_cell_entered)
	explore_btn.pressed.connect(_on_explore)
	inn_btn.pressed.connect(_on_inn)
	shop_btn.pressed.connect(_on_shop)
	craft_btn.pressed.connect(_on_craft)
	hide()

func _on_cell_entered(cell: Vector2i, cell_data: Dictionary) -> void:
	_current_cell = cell
	_current_cell_data = cell_data
	_refresh()

func _refresh() -> void:
	if _current_cell_data.is_empty():
		hide()
		return

	show()
	var type_str = _current_cell_data.get("type", "wilderness")
	match type_str:
		"village", "city": title_label.text = "[城镇] " + _current_cell_data.get("name", "未知")
		"dungeon": title_label.text = "[洞穴] " + _current_cell_data.get("name", "未知")
		_: title_label.text = _current_cell_data.get("name", "荒野")

	desc_label.text = _current_cell_data.get("description", "")

	# NPC列表
	for child in npc_container.get_children():
		child.queue_free()
	var npcs: Array = _current_cell_data.get("npcs", [])
	for npc_id in npcs:
		var btn = Button.new()
		btn.text = _npc_name(npc_id)
		btn.pressed.connect(func(id=npc_id): _interact_npc(id))
		npc_container.add_child(btn)

	# 资源列表
	for child in resource_container.get_children():
		child.queue_free()
	var resources: Array = _current_cell_data.get("resources", [])
	for res_id in resources:
		var hbox = HBoxContainer.new()
		var label = Label.new()
		var item = DataManager.get_item(res_id)
		label.text = item.get("name", res_id)
		hbox.add_child(label)
		var btn = Button.new()
		btn.text = "采集"
		btn.pressed.connect(func(id=res_id): _gather(id))
		hbox.add_child(btn)
		resource_container.add_child(hbox)

	# 设施按钮
	var safe = _current_cell_data.get("isSafeZone", false)
	inn_btn.visible = safe and _current_cell_data.get("hasInn", false)
	shop_btn.visible = safe and _current_cell_data.get("hasShop", false)
	craft_btn.visible = safe and _current_cell_data.has("hasCraftStation")

	# 探索按钮（非安全区域）
	var monsters: Array = _current_cell_data.get("monsters", [])
	explore_btn.visible = not safe and not monsters.is_empty()

func _npc_name(npc_id: String) -> String:
	match npc_id:
		"old_beggar": return "老乞丐"
		"merchant_li": return "李掌柜"
		"village_guard": return "村卫"
		"teahouse_owner": return "茶馆老板"
		"wushi": return "武师·铁震天"
		"hermit": return "隐士"
		"bandit_scout": return "山贼斥候"
		"bandit_boss": return "山贼头目"
		_: return npc_id

func _interact_npc(npc_id: String) -> void:
	if GameManager.current_phase != GameManager.GamePhase.WORLD_EXPLORATION:
		return
	match npc_id:
		"old_beggar":
			EventBus.dialogue_triggered.emit("old_beggar_intro", "老乞丐")
		"merchant_li":
			EventBus.dialogue_triggered.emit("merchant_li", "李掌柜")
		"village_guard":
			EventBus.dialogue_triggered.emit("village_guard", "村卫")
		"teahouse_owner":
			EventBus.dialogue_triggered.emit("teahouse_owner", "茶馆老板")
		"wushi":
			EventBus.dialogue_triggered.emit("wushi", "武师·铁震天")
		"hermit":
			EventBus.dialogue_triggered.emit("hermit", "隐士")
		_:
			EventBus.dialogue_triggered.emit(npc_id, _npc_name(npc_id))

func _gather(res_id: String) -> void:
	if GameManager.current_phase != GameManager.GamePhase.WORLD_EXPLORATION:
		return
	var item = DataManager.get_item(res_id)
	if item.is_empty():
		return
	GameManager.inv_add(res_id)
	NotificationManager.notify("获得 %s" % item.get("name", res_id))
	EventBus.item_gathered.emit(res_id)

func _on_explore() -> void:
	if GameManager.current_phase != GameManager.GamePhase.WORLD_EXPLORATION:
		return
	var monsters: Array = _current_cell_data.get("monsters", [])
	if monsters.is_empty():
		NotificationManager.notify("此地暂无危险", "info")
		return
	var chosen = LocationContentManager.pick_random_monster(monsters)
	if chosen.is_empty():
		return
	var team = LocationContentManager.build_enemy_team(chosen)
	GameManager.start_battle(team)

func _on_inn() -> void:
	NotificationManager.notify("客栈：回复全部生命和内力", "info")
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if stats:
		stats.current_hp = stats.max_hp
		stats.current_qi = stats.max_qi
	EventBus.attribute_changed.emit("hp", stats.current_hp if stats else 0)

func _on_shop() -> void:
	EventBus.open_shop.emit("general")

func _on_craft() -> void:
	EventBus.menu_opened.emit("crafting")
