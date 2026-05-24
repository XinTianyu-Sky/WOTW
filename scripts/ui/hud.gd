# HUD.gd
# 游戏内HUD
# 显示生命、内力、经验、小地图入口、菜单按钮
extends CanvasLayer

# ---- 状态栏 ----
@onready var hp_bar: ProgressBar = $TopPanel/HPBar
@onready var qi_bar: ProgressBar = $TopPanel/QiBar
@onready var exp_bar: ProgressBar = $TopPanel/ExpBar
@onready var hp_label: Label = $TopPanel/HPBar/Label
@onready var qi_label: Label = $TopPanel/QiBar/Label
@onready var exp_label: Label = $TopPanel/ExpBar/Label
@onready var level_label: Label = $TopPanel/LevelLabel

# ---- 时间和天气 ----
@onready var time_label: Label = $TopPanel/TimeLabel
@onready var weather_icon: TextureRect = $TopPanel/WeatherIcon

# ---- 虚拟摇杆（移动端） ----
@onready var joystick: TouchScreenButton = $Joystick

# ---- 按钮 ----
@onready var save_btn: Button = $TopPanel/SaveBtn
@onready var menu_btn: Button = $TopPanel/MenuBtn
@onready var inventory_btn: Button = $BottomBar/InventoryBtn
@onready var character_btn: Button = $BottomBar/CharacterBtn
@onready var skills_btn: Button = $BottomBar/SkillsBtn
@onready var quest_btn: Button = $BottomBar/QuestBtn
@onready var craft_btn: Button = $BottomBar/CraftBtn
@onready var map_btn: Button = $TopPanel/MapBtn

# ---- 通知 ----
@onready var notification_label: Label = $NotificationLabel

# ---- 位置显示 ----
var location_label: Label = null

var player_stats: PlayerStats = null

func _ready() -> void:
	# 连接按钮
	menu_btn.pressed.connect(func(): EventBus.menu_opened.emit("pause"))
	inventory_btn.pressed.connect(func(): EventBus.menu_opened.emit("inventory"))
	character_btn.pressed.connect(func(): EventBus.menu_opened.emit("character"))
	skills_btn.pressed.connect(func(): EventBus.menu_opened.emit("skills"))
	quest_btn.pressed.connect(func(): EventBus.menu_opened.emit("quest"))
	craft_btn.pressed.connect(func(): EventBus.menu_opened.emit("crafting"))
	save_btn.pressed.connect(func(): SaveManager.save_game(0))
	map_btn.pressed.connect(func(): EventBus.menu_opened.emit("map"))

	# HUD 视觉样式
	hp_bar.add_theme_color_override("fill_color", Color(0.82, 0.15, 0.1))
	qi_bar.add_theme_color_override("fill_color", Color(0.15, 0.35, 0.78))
	exp_bar.add_theme_color_override("fill_color", Color(0.9, 0.8, 0.2))
	level_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	time_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 1))

	# 监听事件
	EventBus.player_leveled_up.connect(_on_player_leveled)
	EventBus.attribute_changed.connect(func(_a, _v): _update_display())
	EventBus.notification_shown.connect(_show_notification)
	EventBus.grid_cell_entered.connect(_on_grid_cell_entered)
	EventBus.region_changed.connect(_on_region_changed)

	# 动态创建位置标签
	var top = $TopPanel
	location_label = Label.new()
	location_label.name = "LocationLabel"
	location_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1))
	location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(location_label)
	top.move_child(location_label, top.get_child_count())

	# 初始化显示
	_update_time_display()
	_update_location_display()

func _process(_delta: float) -> void:
	_update_time_display()
	if player_stats:
		_update_display()

func set_player_stats(stats: PlayerStats) -> void:
	player_stats = stats
	_update_display()

func _update_display() -> void:
	if player_stats == null:
		return
	hp_bar.max_value = player_stats.max_hp
	hp_bar.value = player_stats.current_hp
	hp_label.text = "%d / %d" % [player_stats.current_hp, player_stats.max_hp]

	qi_bar.max_value = player_stats.max_qi
	qi_bar.value = player_stats.current_qi
	qi_label.text = "%d / %d" % [player_stats.current_qi, player_stats.max_qi]

	var exp_next = player_stats.get_exp_for_next_level()
	exp_bar.max_value = exp_next
	exp_bar.value = player_stats.experience
	exp_label.text = "EXP %d / %d" % [player_stats.experience, exp_next]

	level_label.text = "Lv.%d" % player_stats.level

func _update_time_display() -> void:
	var hour = GameManager.get_game_hour()
	var minute = GameManager.get_game_minute()
	var tod = GameManager.get_time_of_day()

	var tod_text = ""
	match tod:
		"dawn":    tod_text = "清晨"
		"morning": tod_text = "上午"
		"afternoon": tod_text = "下午"
		"dusk":    tod_text = "傍晚"
		"evening": tod_text = "夜晚"
		"night":   tod_text = "深夜"

	time_label.text = "%s %02d:%02d" % [tod_text, hour, minute]

func _on_grid_cell_entered(_cell: Vector2i, cell_data: Dictionary) -> void:
	var region = DataManager.get_region(GameManager.player_grid_region)
	var region_name = region.get("name", GameManager.player_grid_region)
	var cell_name = cell_data.get("name", "荒野")
	location_label.text = "%s · %s" % [region_name, cell_name]

func _on_region_changed(_old: String, _new: String) -> void:
	_update_location_display()

func _update_location_display() -> void:
	var region = DataManager.get_region(GameManager.player_grid_region)
	var region_name = region.get("name", GameManager.player_grid_region)
	location_label.text = region_name

func _on_player_leveled(new_level: int) -> void:
	_show_notification("升级！达到 Lv.%d" % new_level, "success")

func _show_notification(message: String, level: String) -> void:
	notification_label.text = message
	match level:
		"error": notification_label.modulate = Color.RED
		"success": notification_label.modulate = Color.GREEN
		_: notification_label.modulate = Color.WHITE

	var tween = create_tween()
	tween.tween_property(notification_label, "modulate:a", 1.0, 0.1)
	tween.tween_interval(2.0)
	tween.tween_property(notification_label, "modulate:a", 0.0, 0.5)
