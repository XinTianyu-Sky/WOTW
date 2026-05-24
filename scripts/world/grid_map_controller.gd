# GridMapController.gd
# 网格地图核心控制器
# 替代 world_manager.gd — 管理网格移动、天气/时间、战斗结算
extends Node

# ---- 引用 ----
@onready var grid_ui: Control = %GridUI
@onready var location_panel: Panel = %LocationPanel
@onready var border_dialog: ConfirmationDialog = %BorderDialog

# ---- 天气状态 ----
var current_weather_str: String = "clear"
var weather_timer: float = 0.0
var weather_duration: float = 0.0
var region_weather_pool: Array = []

func _ready() -> void:
	_init_player()
	_init_equipment()
	_init_hud()

	# 信号连接
	EventBus.grid_cell_clicked.connect(_on_cell_clicked)
	EventBus.battle_ended.connect(_on_battle_ended)

	# 加载当前区域
	_load_region(GameManager.player_grid_region, GameManager.player_grid_pos)

	# 天气初始化
	_roll_new_weather()

	GameManager.set_phase(GameManager.GamePhase.WORLD_EXPLORATION)
	SaveManager.auto_save()

func _process(delta: float) -> void:
	if GameManager.current_phase != GameManager.GamePhase.WORLD_EXPLORATION:
		return

	weather_timer += delta
	if weather_timer >= weather_duration:
		_roll_new_weather()

	_handle_input()

	if Input.is_action_just_pressed("quick_save"):
		SaveManager.save_game(0)

# ---- 输入处理 ----
func _handle_input() -> void:
	var dir = Vector2i.ZERO
	if Input.is_action_just_pressed("move_up"):    dir = Vector2i(0, -1)
	elif Input.is_action_just_pressed("move_down"):  dir = Vector2i(0, 1)
	elif Input.is_action_just_pressed("move_left"):  dir = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("move_right"): dir = Vector2i(1, 0)
	else:
		return

	var target = GameManager.player_grid_pos + dir
	var grid = DataManager.get_region_grid(GameManager.player_grid_region)
	var w: int = grid.get("width", 12)
	var h: int = grid.get("height", 10)

	if target.x >= 0 and target.x < w and target.y >= 0 and target.y < h:
		# 检查是否相邻
		var adj = DataManager.get_adjacent_locations(GameManager.player_grid_region, GameManager.player_grid_pos)
		var is_adjacent = false
		for a in adj:
			if a == target:
				is_adjacent = true
				break
		if is_adjacent:
			move_to(target)
	else:
		# 尝试边界穿越
		var direction = ""
		if dir == Vector2i(0, -1): direction = "north"
		elif dir == Vector2i(0, 1): direction = "south"
		elif dir == Vector2i(-1, 0): direction = "west"
		elif dir == Vector2i(1, 0): direction = "east"
		_attempt_border_travel(direction)

# ---- 网格移动 ----
func _on_cell_clicked(cell: Vector2i) -> void:
	var adj = DataManager.get_adjacent_locations(GameManager.player_grid_region, GameManager.player_grid_pos)
	for a in adj:
		if a == cell:
			move_to(cell)
			return

func move_to(target: Vector2i) -> void:
	GameManager.player_grid_pos = target
	var key = "%d,%d" % [target.x, target.y]
	if key not in GameManager.visited_cells:
		GameManager.visited_cells.append(key)
	_enter_cell(target)

func _enter_cell(pos: Vector2i) -> void:
	var content = LocationContentManager.get_cell_content(GameManager.player_grid_region, pos)
	EventBus.grid_cell_entered.emit(pos, content)

# ---- 区域加载 ----
func _load_region(region_id: String, start_pos: Vector2i) -> void:
	var region = DataManager.get_region(region_id)
	if region.is_empty():
		return

	current_weather_str = "clear"
	weather_timer = 0.0
	region_weather_pool = region.get("weatherPool", [])

	# 构建位置名索引给 Grid UI
	var index = DataManager.get_region_locations_index(region_id)
	var names: Dictionary = {}
	for key in index:
		names[key] = index[key].get("name", "")
	if grid_ui and grid_ui.has_method("set_cell_names"):
		grid_ui.set_cell_names(names)

	# 同步已探索格子
	if grid_ui and grid_ui.has_method("set_visited"):
		grid_ui.set_visited(GameManager.visited_cells)

	# 更新 Grid UI 的当前位置
	grid_ui.current_cell = start_pos
	grid_ui.adjacent = DataManager.get_adjacent_locations(region_id, start_pos)
	grid_ui.queue_redraw()

	_enter_cell(start_pos)

# ---- 边界穿越 ----
var _pending_border_direction: String = ""

func _attempt_border_travel(direction: String) -> void:
	var grid = DataManager.get_region_grid(GameManager.player_grid_region)
	var bt = grid.get("borderTravel", {}).get(direction, {})
	if bt.is_empty():
		return

	_pending_border_direction = direction
	var label = bt.get("label", "前往未知区域")
	border_dialog.dialog_text = "是否%s？" % label
	border_dialog.popup_centered()

func _on_border_confirmed() -> void:
	var direction = _pending_border_direction
	_pending_border_direction = ""

	var grid = DataManager.get_region_grid(GameManager.player_grid_region)
	var bt = grid.get("borderTravel", {}).get(direction, {})
	if bt.is_empty():
		return

	var target_region = bt.get("targetRegion", "")
	var tc = bt.get("targetCell", {"x": 5, "y": 5})

	var old_region = GameManager.player_grid_region
	GameManager.player_grid_region = target_region
	GameManager.player_grid_pos = Vector2i(tc.get("x", 5), tc.get("y", 5))

	EventBus.region_changed.emit(old_region, target_region)
	_load_region(target_region, GameManager.player_grid_pos)

# ---- 玩家初始化 ----
func _init_player() -> void:
	if GameManager.player_data.is_empty():
		return
	var existing = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if existing:
		return
	var stats_data = GameManager.player_data.get("stats", {})
	if stats_data.is_empty():
		return
	var stats = PlayerStats.new()
	stats.from_dict(stats_data)
	GameManager.player_data["_stats_ref"] = stats

func _init_equipment() -> void:
	var existing = GameManager.player_data.get("_equipment", null) as EquipmentManager
	if existing:
		EventBus.equipment_changed.connect(_on_equipment_changed)
		return
	var eq = EquipmentManager.new()
	GameManager.player_data["_equipment"] = eq
	EventBus.equipment_changed.connect(_on_equipment_changed)

func _on_equipment_changed(_slot: String, _id: String) -> void:
	var eq = GameManager.player_data.get("_equipment", null) as EquipmentManager
	if not eq:
		return
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if stats:
		stats.update_equipment_bonuses(eq.get_total_bonuses())

func _init_hud() -> void:
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	if not stats:
		return
	var hud = get_node_or_null("HUDLayer/HUD")
	if hud and hud.has_method("set_player_stats"):
		hud.set_player_stats(stats)

	var char_sheet = get_node_or_null("UILayer/CharacterSheetUI")
	if char_sheet and char_sheet.has_method("set_stats"):
		char_sheet.set_stats(stats)

	var skills_ui = get_node_or_null("UILayer/SkillsUI")
	if skills_ui:
		skills_ui.learned_external = GameManager.player_data.get("learned_external", [])
		skills_ui.learned_internal = GameManager.player_data.get("learned_internal", [])
		skills_ui.learned_lightness = GameManager.player_data.get("learned_lightness", [])
		skills_ui.equipped_external = GameManager.player_data.get("equipped_external", "")
		skills_ui.equipped_internal = GameManager.player_data.get("equipped_internal", "")
		skills_ui.equipped_lightness = GameManager.player_data.get("equipped_lightness", "")

	var shop_ui = get_node_or_null("UILayer/ShopUI")
	if shop_ui:
		EventBus.open_shop.connect(shop_ui.open_shop)

# ---- 战斗结算 ----
func _on_battle_ended(result: Dictionary) -> void:
	if result.get("result") != "victory":
		return
	var defeated = result.get("defeated_enemies", [])
	if defeated.is_empty():
		return

	for name in defeated:
		if name == "山贼头目":
			_boss_reward(name)

	var active = GameManager.world_state.get("active_quests", [])
	for qid in active:
		var qdata = DataManager.get_quest(qid)
		if qdata.is_empty():
			continue
		var objs = qdata.get("objectives", [])
		for i in range(objs.size()):
			var obj = objs[i]
			if obj.get("type") != "kill":
				continue
			var progress = GameManager.world_state.get("quest_progress", {}).get(qid, [])
			if progress.has(i):
				continue
			var target = obj.get("targetId", "")
			for name in defeated:
				if name == target or target.is_empty():
					progress.append(i)
					GameManager.world_state["quest_progress"] = GameManager.world_state.get("quest_progress", {})
					GameManager.world_state["quest_progress"][qid] = progress
					EventBus.quest_progressed.emit(qid, i)
					if progress.size() >= objs.size():
						EventBus.quest_completed.emit(qid)
					break

func _boss_reward(boss_name: String) -> void:
	var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
	match boss_name:
		"山贼头目":
			if GameManager.world_state.get("boss_bandit_defeated", false):
				return
			GameManager.world_state["boss_bandit_defeated"] = true
			if stats:
				stats.add_experience(150)
			var copper = GameManager.player_data.get("copper", 0)
			GameManager.player_data["copper"] = copper + 300
			GameManager.inv_add("iron_sword")
			NotificationManager.notify("击败山贼头目！获得 铁剑 + 300铜钱", "success")

# ---- 天气 ----
func _roll_new_weather() -> void:
	if region_weather_pool.is_empty():
		return
	var total: float = 0.0
	for w in region_weather_pool:
		total += w.get("weight", 0.0)
	var roll = randf() * total
	var cumulative: float = 0.0
	for w in region_weather_pool:
		cumulative += w.get("weight", 0.0)
		if roll <= cumulative:
			var new_str = w.get("weather", "clear")
			if new_str != current_weather_str:
				EventBus.weather_changed.emit(current_weather_str, new_str)
				current_weather_str = new_str
			break
	weather_duration = randf_range(120.0, 480.0)
	weather_timer = 0.0
