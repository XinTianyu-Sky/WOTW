# NotificationManager.gd
# 通知管理器 (Autoload)
# 全局通知显示
extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func notify(message: String, level: String = "info") -> void:
	EventBus.notification_shown.emit(message, level)