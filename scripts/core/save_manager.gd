# SaveManager.gd
# 存档管理器
# 管理存档、读档、自动存档
extends Node

const SAVE_PATH: String = "user://save_data.json"
const AUTO_SAVE_PATH: String = "user://auto_save.json"
const MAX_SAVE_SLOTS: int = 5

var current_slot: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---- 存档 ----
func save_game(slot: int = 0) -> bool:
	var data = GameManager.build_save_data()
	var path = _get_slot_path(slot)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法写入存档 '%s'" % path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	current_slot = slot
	EventBus.notification_shown.emit("游戏已保存", "success")
	return true

func auto_save() -> void:
	var data = GameManager.build_save_data()
	var file = FileAccess.open(AUTO_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

# ---- 读档 ----
func load_game(slot: int = 0) -> bool:
	var path = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var json = JSON.parse_string(file.get_as_text())
	file.close()

	if json == null:
		push_error("SaveManager: 存档解析失败")
		return false

	GameManager.load_save_data(json)
	current_slot = slot
	return true

# ---- 存档信息 ----
func get_save_info(slot: int = 0) -> Dictionary:
	var path = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false}

	var json = JSON.parse_string(file.get_as_text())
	file.close()

	if json == null:
		return {"exists": false}

	var timestamp = json.get("timestamp", 0)
	var dt = Time.get_datetime_dict_from_unix_time(timestamp)
	return {
		"exists": true,
		"timestamp": timestamp,
		"date_str": "%d/%d/%d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute],
		"level": json.get("player_data", {}).get("stats", {}).get("level", 1),
		"scene": json.get("current_scene", ""),
		"game_time": json.get("game_time", 0.0)
	}

# ---- 删除存档 ----
func delete_save(slot: int = 0) -> bool:
	var path = _get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return true
	return false

func _get_slot_path(slot: int) -> String:
	if slot == 0:
		return SAVE_PATH
	return "user://save_slot_%d.json" % slot