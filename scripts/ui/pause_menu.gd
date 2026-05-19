# PauseMenu.gd
# 暂停菜单 — 继续、存档、读档、返回标题、退出
class_name PauseMenu
extends CanvasLayer

@onready var panel: Panel = $PausePanel
@onready var continue_btn: Button = $PausePanel/ContinueBtn
@onready var save_btn: Button = $PausePanel/SaveBtn
@onready var load_btn: Button = $PausePanel/LoadBtn
@onready var quit_btn: Button = $PausePanel/QuitBtn
@onready var save_panel: Panel = $SavePanel
@onready var load_panel: Panel = $LoadPanel

func _ready() -> void:
	hide()
	EventBus.menu_opened.connect(_on_menu_opened)
	continue_btn.pressed.connect(_on_continue)
	save_btn.pressed.connect(_show_save_panel)
	load_btn.pressed.connect(_show_load_panel)
	quit_btn.pressed.connect(_on_quit)

	# 存档面板
	for i in range(5):
		var slot = i + 1
		var btn = save_panel.get_node("Slot%d" % slot)
		btn.pressed.connect(func(): _do_save(slot))

	var save_back = save_panel.get_node("BackBtn")
	save_back.pressed.connect(func():
		save_panel.hide()
		panel.show()
	)

	# 读档面板
	for i in range(5):
		var slot = i + 1
		var btn = load_panel.get_node("Slot%d" % slot)
		btn.pressed.connect(func(s=slot): _do_load(s))

	var load_back = load_panel.get_node("BackBtn")
	load_back.pressed.connect(func():
		load_panel.hide()
		panel.show()
	)

func _on_menu_opened(menu_name: String) -> void:
	if menu_name == "pause":
		show()
		panel.show()
		save_panel.hide()
		load_panel.hide()
	else:
		hide()

func _on_continue() -> void:
	hide()
	EventBus.menu_closed.emit("pause")

func _show_save_panel() -> void:
	panel.hide()
	save_panel.show()
	for i in range(5):
		var slot = i + 1
		var info = SaveManager.get_save_info(slot)
		var btn = save_panel.get_node("Slot%d" % slot)
		if info.get("exists"):
			btn.text = "存档 %d\n%s Lv.%d" % [slot, info.get("date_str", ""), info.get("level", 1)]
		else:
			btn.text = "存档 %d\n[空]" % slot

func _show_load_panel() -> void:
	panel.hide()
	load_panel.show()
	for i in range(5):
		var slot = i + 1
		var info = SaveManager.get_save_info(slot)
		var btn = load_panel.get_node("Slot%d" % slot)
		if info.get("exists"):
			btn.text = "存档 %d\n%s Lv.%d" % [slot, info.get("date_str", ""), info.get("level", 1)]
		else:
			btn.text = "存档 %d\n[空]" % slot
			btn.disabled = true

func _do_save(slot: int) -> void:
	SaveManager.save_game(slot)
	save_panel.hide()
	panel.show()

func _do_load(slot: int) -> void:
	var info = SaveManager.get_save_info(slot)
	if not info.get("exists"):
		return
	SaveManager.load_game(slot)
	hide()
	EventBus.menu_closed.emit("pause")
	GameManager.change_scene(GameManager.current_scene)

func _on_quit() -> void:
	GameManager.change_scene("res://scenes/ui/main_menu.tscn")
