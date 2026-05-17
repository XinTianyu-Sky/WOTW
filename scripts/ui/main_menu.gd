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

    _refresh_continue_btn()

    version_label.text = "v0.1.0"

func _refresh_continue_btn() -> void:
    var info = SaveManager.get_save_info(0)
    if info["exists"]:
        continue_btn.disabled = false
        continue_btn.text = "再续前缘 (Lv.%d)" % info.get("level", 1)
    else:
        continue_btn.disabled = true
        continue_btn.text = "再续前缘"

func _on_new_game() -> void:
    GameManager.change_scene("res://scenes/ui/character_creation.tscn")

func _on_continue() -> void:
    if SaveManager.load_game(0):
        GameManager.change_scene(GameManager.current_scene)

func _on_settings() -> void:
    pass

func _on_quit() -> void:
    get_tree().quit()
