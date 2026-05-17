# MainMenu.gd
# 主菜单控制器
extends Control

@onready var new_game_btn: Button = $VBoxContainer/NewGameBtn
@onready var continue_btn: Button = $VBoxContainer/ContinueBtn
@onready var settings_btn: Button = $VBoxContainer/SettingsBtn
@onready var quit_btn: Button = $VBoxContainer/QuitBtn
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	GameManager.set_phase(GameManager.GamePhase.MAIN_MENU)

	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

	# 检查是否有存档
	var save_exists = FileAccess.file_exists("user://save_data.json")
	continue_btn.disabled = not save_exists

	version_label.text = "v0.1.0"

func _on_new_game() -> void:
	# 进入角色创建
	GameManager.change_scene("res://scenes/ui/character_creation.tscn")

func _on_continue() -> void:
	var file = FileAccess.open("user://save_data.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		file.close()
		if json:
			GameManager.load_save_data(json)
			GameManager.change_scene(GameManager.current_scene)
			return

	NotificationManager.notify("存档加载失败", "error")

func _on_settings() -> void:
	# TODO: 打开设置面板
	pass

func _on_quit() -> void:
	get_tree().quit()