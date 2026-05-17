# EventBus.gd
# 全局事件总线 (Autoload)
# 解耦各系统间的通信，使用信号模式
extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---- 战斗事件 ----
signal battle_started(battle_data: Dictionary)
signal battle_ended(result: Dictionary)
signal turn_changed(current_unit: String, turn_number: int)
signal unit_damaged(unit_id: String, damage: int, source_id: String)
signal unit_defeated(unit_id: String)
signal skill_used(unit_id: String, skill_id: String, targets: Array)
signal status_applied(target_id: String, status_id: String)
signal status_removed(target_id: String, status_id: String)

# ---- 角色事件 ----
signal player_leveled_up(new_level: int)
signal attribute_changed(attr_name: String, new_value: int)
signal skill_learned(skill_id: String)
signal skill_mastered(skill_id: String, new_proficiency: String)
signal equipment_changed(slot: String, item_id: String)
signal meridian_unlocked(meridian_id: String, acupoint_id: String)

# ---- 世界事件 ----
signal weather_changed(old_weather: String, new_weather: String)
signal time_of_day_changed(new_tod: String)
signal scene_entered(scene_id: String)
signal scene_exited(scene_id: String)
signal npc_interacted(npc_id: String)
signal item_collected(item_id: String, amount: int)
signal random_encounter_triggered(encounter_type: String)

# ---- 任务事件 ----
signal quest_accepted(quest_id: String)
signal quest_progressed(quest_id: String, objective_index: int)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal dialogue_triggered(dialogue_id: String)
signal choice_made(dialogue_id: String, choice_id: String)

# ---- 经济事件 ----
signal currency_changed(currency_type: String, amount: int, new_total: int)
signal item_bought(item_id: String, price: int)
signal item_sold(item_id: String, price: int)
signal item_crafted(item_id: String)

# ---- UI 事件 ----
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)
signal notification_shown(message: String, level: String)
