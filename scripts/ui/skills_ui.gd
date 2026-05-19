# SkillsUI.gd
# 武学界面控制器 — 查看、装备/卸下武学
class_name SkillsUI
extends CanvasLayer

@onready var panel: Panel = $SkillsPanel
@onready var close_btn: Button = $SkillsPanel/CloseBtn
@onready var external_list: ItemList = $SkillsPanel/TabContainer/External/ExternalList
@onready var internal_list: ItemList = $SkillsPanel/TabContainer/Internal/InternalList
@onready var lightness_list: ItemList = $SkillsPanel/TabContainer/Lightness/LightnessList
@onready var detail_label: RichTextLabel = $SkillsPanel/SkillDetail
@onready var equip_btn: Button = $SkillsPanel/EquipBtn

var learned_external: Array = []
var learned_internal: Array = []
var learned_lightness: Array = []
var equipped_external: String = ""
var equipped_internal: String = ""
var equipped_lightness: String = ""

var _selected_skill_id: String = ""
var _selected_skill_type: String = ""

func _ready() -> void:
    hide()
    close_btn.pressed.connect(_close)
    EventBus.menu_opened.connect(_on_menu_opened)
    EventBus.skill_learned.connect(func(_sid): _refresh())
    equip_btn.pressed.connect(_on_equip)
    external_list.item_selected.connect(func(idx): _show_detail(learned_external[idx], "external"))
    internal_list.item_selected.connect(func(idx): _show_detail(learned_internal[idx], "internal"))
    lightness_list.item_selected.connect(func(idx): _show_detail(learned_lightness[idx], "lightness"))

func _close() -> void:
    hide()
    EventBus.menu_closed.emit("skills")

func _on_menu_opened(menu_name: String) -> void:
    if menu_name == "skills":
        show()
        _refresh()
    else:
        hide()

func _refresh() -> void:
    _read_player_data()
    equip_btn.hide()

    external_list.clear()
    for skill_id in learned_external:
        var data = DataManager.get_external_skill(skill_id)
        var text = data.get("name", skill_id)
        if skill_id == equipped_external:
            text = "[E] " + text
        external_list.add_item(text)

    internal_list.clear()
    for skill_id in learned_internal:
        var data = DataManager.get_internal_skill(skill_id)
        var text = data.get("name", skill_id)
        if skill_id == equipped_internal:
            text = "[E] " + text
        internal_list.add_item(text)

    lightness_list.clear()
    for skill_id in learned_lightness:
        var data = DataManager.get_lightness_skill(skill_id)
        var text = data.get("name", skill_id)
        if skill_id == equipped_lightness:
            text = "[E] " + text
        lightness_list.add_item(text)

func _read_player_data() -> void:
    learned_external = GameManager.player_data.get("learned_external", [])
    learned_internal = GameManager.player_data.get("learned_internal", [])
    learned_lightness = GameManager.player_data.get("learned_lightness", [])
    equipped_external = GameManager.player_data.get("equipped_external", "")
    equipped_internal = GameManager.player_data.get("equipped_internal", "")
    equipped_lightness = GameManager.player_data.get("equipped_lightness", "")

func _show_detail(skill_id: String, skill_type: String) -> void:
    _selected_skill_id = skill_id
    _selected_skill_type = skill_type

    match skill_type:
        "external":
            var data = DataManager.get_external_skill(skill_id)
            if data.is_empty(): return
            var text = "[b]%s[/b]  [color=gray]%s[/color]\n\n" % [data.get("name", ""), data.get("source", "")]
            text += data.get("description", "") + "\n\n"
            text += "[b]招式列表:[/b]\n"
            for tech in data.get("techniques", []):
                text += "  [color=orange]%s[/color] - 内力:%d 冷却:%d\n" % [tech.get("name", "???"), tech.get("qiCost", 0), tech.get("cooldown", 0)]
            detail_label.text = text

        "internal":
            var data = DataManager.get_internal_skill(skill_id)
            if data.is_empty(): return
            var text = "[b]%s[/b]\n\n%s\n\n" % [data.get("name", ""), data.get("description", "")]
            text += "[b]被动加成:[/b]\n"
            for bonus in data.get("passiveBonuses", []):
                text += "  %s: +%.0f%%\n" % [bonus.get("stat", ""), bonus.get("value", 0.0) * 100]
            detail_label.text = text

        "lightness":
            var data = DataManager.get_lightness_skill(skill_id)
            if data.is_empty(): return
            var text = "[b]%s[/b]\n\n%s\n\n" % [data.get("name", ""), data.get("description", "")]
            text += "[b]速度加成:[/b] %.0f%%" % (data.get("speedMultiplier", 1.0) * 100 - 100)
            detail_label.text = text

    # 显示装备/卸下按钮
    var current_equipped = _get_equipped_for_type(skill_type)
    if current_equipped == skill_id:
        equip_btn.text = "卸下"
    else:
        equip_btn.text = "装备"
    equip_btn.show()

func _get_equipped_for_type(skill_type: String) -> String:
    match skill_type:
        "external": return equipped_external
        "internal": return equipped_internal
        "lightness": return equipped_lightness
    return ""

func _on_equip() -> void:
    if _selected_skill_id.is_empty():
        return

    match _selected_skill_type:
        "external":
            if equipped_external == _selected_skill_id:
                GameManager.player_data["equipped_external"] = ""
            else:
                GameManager.player_data["equipped_external"] = _selected_skill_id
        "internal":
            if equipped_internal == _selected_skill_id:
                GameManager.player_data["equipped_internal"] = ""
            else:
                GameManager.player_data["equipped_internal"] = _selected_skill_id
        "lightness":
            if equipped_lightness == _selected_skill_id:
                GameManager.player_data["equipped_lightness"] = ""
            else:
                GameManager.player_data["equipped_lightness"] = _selected_skill_id

    var data = DataManager.get_external_skill(_selected_skill_id)
    if data.is_empty():
        data = DataManager.get_internal_skill(_selected_skill_id)
    if data.is_empty():
        data = DataManager.get_lightness_skill(_selected_skill_id)
    var sname = data.get("name", _selected_skill_id)
    if equip_btn.text == "装备":
        NotificationManager.notify("已装备 %s" % sname)
    else:
        NotificationManager.notify("已卸下 %s" % sname)

    _refresh()
    _show_detail(_selected_skill_id, _selected_skill_type)
