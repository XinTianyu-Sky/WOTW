# SkillsUI.gd
# 武学界面控制器
extends CanvasLayer

@onready var panel: Panel = $SkillsPanel
@onready var close_btn: Button = $SkillsPanel/CloseBtn
@onready var external_list: ItemList = $SkillsPanel/TabContainer/External/ExternalList
@onready var internal_list: ItemList = $SkillsPanel/TabContainer/Internal/InternalList
@onready var lightness_list: ItemList = $SkillsPanel/TabContainer/Lightness/LightnessList
@onready var detail_label: RichTextLabel = $SkillsPanel/SkillDetail

var learned_external: Array = []
var learned_internal: Array = []
var learned_lightness: Array = []
var equipped_external: String = ""
var equipped_internal: String = ""
var equipped_lightness: String = ""

func _ready() -> void:
	hide()
	close_btn.pressed.connect(hide)
	EventBus.menu_opened.connect(_on_menu_opened)

func _on_menu_opened(menu_name: String) -> void:
	if menu_name == "skills":
		show()
		_refresh()

func _refresh() -> void:
	external_list.clear()
	for skill_id in learned_external:
		var data = DataManager.get_external_skill(skill_id)
		var text = data.get("name", skill_id)
		if skill_id == equipped_external:
			text = "[装备中] " + text
		external_list.add_item(text)

	internal_list.clear()
	for skill_id in learned_internal:
		var data = DataManager.get_internal_skill(skill_id)
		var text = data.get("name", skill_id)
		if skill_id == equipped_internal:
			text = "[装备中] " + text
		internal_list.add_item(text)

	lightness_list.clear()
	for skill_id in learned_lightness:
		var data = DataManager.get_lightness_skill(skill_id)
		var text = data.get("name", skill_id)
		if skill_id == equipped_lightness:
			text = "[装备中] " + text
		lightness_list.add_item(text)

func _show_external_detail(skill_id: String) -> void:
	var data = DataManager.get_external_skill(skill_id)
	if data.is_empty():
		return

	var text = "[b]%s[/b]\n\n" % data.get("name", "")
	text += data.get("description", "") + "\n\n"
	text += "[b]招式列表:[/b]\n"

	for tech in data.get("techniques", []):
		text += "  [color=orange]%s[/color] - 内力:%d 冷却:%d\n" % [
			tech.get("name", "???"),
			tech.get("qiCost", 0),
			tech.get("cooldown", 0)
		]

	detail_label.text = text