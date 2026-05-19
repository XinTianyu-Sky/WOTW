# HUD.gd
# 游戏内HUD
# 显示生命、内力、小地图入口、菜单按钮
extends CanvasLayer

# ---- 状态栏 ----
@onready var hp_bar: ProgressBar = $TopPanel/HPBar
@onready var qi_bar: ProgressBar = $TopPanel/QiBar
@onready var hp_label: Label = $TopPanel/HPBar/Label
@onready var qi_label: Label = $TopPanel/QiBar/Label
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
	level_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	time_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 1))

	# 监听事件
	EventBus.player_leveled_up.connect(_on_player_leveled)
	EventBus.attribute_changed.connect(func(_a, _v): _update_display())
	EventBus.notification_shown.connect(_show_notification)

	# 初始化显示
	_update_time_display()

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
