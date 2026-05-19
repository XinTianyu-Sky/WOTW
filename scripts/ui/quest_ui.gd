# QuestUI.gd
# 任务界面
extends CanvasLayer

@onready var panel: Panel = $QuestPanel
@onready var close_btn: Button = $QuestPanel/CloseBtn
@onready var active_list: ItemList = $QuestPanel/TabContainer/Active/ActiveList
@onready var completed_list: ItemList = $QuestPanel/TabContainer/Completed/CompletedList
@onready var quest_detail: RichTextLabel = $QuestPanel/QuestDetail

func _ready() -> void:
    hide()
    close_btn.pressed.connect(_close)
    EventBus.menu_opened.connect(_on_menu_opened)
    EventBus.quest_accepted.connect(_on_quest_accepted)
    EventBus.quest_completed.connect(_on_quest_completed)
    EventBus.quest_progressed.connect(_on_quest_progressed)
    active_list.item_selected.connect(func(idx):
        var qid = GameManager.world_state.get("active_quests", [])[idx]
        _show_detail(qid)
    )

func _close() -> void:
    hide()
    EventBus.menu_closed.emit("quest")

func _on_menu_opened(menu_name: String) -> void:
    if menu_name == "quest":
        show()
        _refresh()
    else:
        hide()

func _refresh() -> void:
    active_list.clear()
    completed_list.clear()

    for qid in GameManager.world_state.get("active_quests", []):
        var data = DataManager.get_quest(qid)
        var progress = GameManager.world_state.get("quest_progress", {}).get(qid, [])
        var total = data.get("objectives", []).size()
        active_list.add_item("%s (%d/%d)" % [data.get("name", qid), progress.size(), total])

    for qid in GameManager.world_state.get("completed_quests", []):
        var data = DataManager.get_quest(qid)
        completed_list.add_item(data.get("name", qid))

func _on_quest_accepted(quest_id: String) -> void:
    var quests = GameManager.world_state.get("active_quests", [])
    if quest_id not in quests:
        quests.append(quest_id)
        GameManager.world_state["active_quests"] = quests
    var data = DataManager.get_quest(quest_id)
    NotificationManager.notify("新任务：%s" % data.get("name", quest_id))

func _on_quest_progressed(quest_id: String, obj_idx: int) -> void:
    var data = DataManager.get_quest(quest_id)
    var obj = data.get("objectives", [{}])[obj_idx]
    NotificationManager.notify("任务进度：%s" % obj.get("description", ""))

func _on_quest_completed(quest_id: String) -> void:
    var active = GameManager.world_state.get("active_quests", [])
    active.erase(quest_id)
    GameManager.world_state["active_quests"] = active
    var completed = GameManager.world_state.get("completed_quests", [])
    if quest_id not in completed:
        completed.append(quest_id)
        GameManager.world_state["completed_quests"] = completed
    var data = DataManager.get_quest(quest_id)
    var rewards = data.get("rewards", {})
    if rewards.has("experience"):
        var stats = GameManager.player_data.get("_stats_ref", null) as PlayerStats
        if stats:
            stats.add_experience(rewards["experience"])
    if rewards.has("copper"):
        var cur = GameManager.player_data.get("copper", 0)
        GameManager.player_data["copper"] = cur + rewards["copper"]
    if rewards.has("items"):
        var inv: Array = GameManager.player_data.get("inventory", [])
        for item_id in rewards["items"]:
            inv.append(item_id)
        GameManager.player_data["inventory"] = inv
    NotificationManager.notify("任务完成：%s" % data.get("name", quest_id), "success")

func _show_detail(quest_id: String) -> void:
    var data = DataManager.get_quest(quest_id)
    if data.is_empty():
        return
    var progress = GameManager.world_state.get("quest_progress", {}).get(quest_id, [])
    var text = "[b]%s[/b]\n\n%s\n\n" % [data.get("name", ""), data.get("description", "")]
    text += "[b]目标:[/b]\n"
    for i in range(data.get("objectives", []).size()):
        var obj = data["objectives"][i]
        var done = "[OK]" if i in progress else "[  ]"
        text += "  %s %s\n" % [done, obj.get("description", "")]
    var rewards = data.get("rewards", {})
    if not rewards.is_empty():
        text += "\n[b]奖励:[/b]\n"
        if rewards.has("experience"): text += "  经验: %d\n" % rewards["experience"]
        if rewards.has("copper"): text += "  铜钱: %d\n" % rewards["copper"]
        if rewards.has("items"):
            for item_id in rewards["items"]:
                var item = DataManager.get_item(item_id)
                text += "  %s\n" % item.get("name", item_id)
    quest_detail.text = text
