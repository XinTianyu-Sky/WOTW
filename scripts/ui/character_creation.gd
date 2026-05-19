# CharacterCreation.gd
# 角色创建界面控制器
extends Control

# ---- 出身数据 ----
const ORIGIN_IDS = [
	"general_descendant",
	"scholar_family",
	"jianghu_orphan",
	"merchant_family",
	"herbalist_family",
	"beggar_origin",
]

var origin_data: Array = []
var selected_origin_idx: int = 0
var free_points: int = 10
var base_attrs: Dictionary = {"str": 5, "agi": 5, "con": 5, "int": 5, "wil": 5, "lck": 5}
var bonus_attrs: Dictionary = {}
var allocated_attrs: Dictionary = {"str": 0, "agi": 0, "con": 0, "int": 0, "wil": 0, "lck": 0}

# ---- UI 引用 ----
@onready var name_input: LineEdit = $NameInput
@onready var gender_select: OptionButton = $GenderSelect
@onready var origin_select: OptionButton = $OriginSelect
@onready var origin_desc: Label = $OriginDescription
@onready var free_points_label: Label = $FreePointsLabel
@onready var confirm_btn: Button = $ConfirmBtn
@onready var attr_panel: VBoxContainer = $AttributePanel

var attr_labels: Dictionary = {}
var attr_buttons: Dictionary = {}

func _ready() -> void:
	_load_origin_data()
	_setup_attribute_ui()
	origin_select.item_selected.connect(_on_origin_changed)
	confirm_btn.pressed.connect(_on_confirm)
	_update_origin_display(0)
	_update_attr_display()

func _load_origin_data() -> void:
	var data = DataManager.get_data("origins")
	origin_data = data.get("origins", [])
	origin_select.clear()
	for origin in origin_data:
		origin_select.add_item(origin["name"])

func _setup_attribute_ui() -> void:
	var attr_names = {
		"str": "膂力", "agi": "身法", "con": "根骨",
		"int": "悟性", "wil": "定力", "lck": "机缘"
	}
	var attr_descs = {
		"str": "影响攻击力与负重",
		"agi": "影响闪避、暴击与行动顺序",
		"con": "影响生命值与防御力",
		"int": "影响修炼速度与内防",
		"wil": "影响内力上限与韧性",
		"lck": "影响掉落率与随机事件"
	}

	for attr_key in ["str", "agi", "con", "int", "wil", "lck"]:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label = Label.new()
		name_label.text = "%s" % attr_names[attr_key]
		name_label.custom_minimum_size = Vector2(60, 0)
		row.add_child(name_label)

		var value_label = Label.new()
		value_label.text = "0"
		value_label.custom_minimum_size = Vector2(40, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		attr_labels[attr_key] = value_label
		row.add_child(value_label)

		var desc_label = Label.new()
		desc_label.text = attr_descs[attr_key]
		desc_label.custom_minimum_size = Vector2(100, 0)
		row.add_child(desc_label)

		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(40, 0)
		minus_btn.pressed.connect(func(): _adjust_attr(attr_key, -1))
		row.add_child(minus_btn)

		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(40, 0)
		plus_btn.pressed.connect(func(): _adjust_attr(attr_key, 1))
		row.add_child(plus_btn)

		attr_buttons[attr_key] = {"minus": minus_btn, "plus": plus_btn}
		attr_panel.add_child(row)

func _on_origin_changed(idx: int) -> void:
	selected_origin_idx = idx
	_update_origin_display(idx)
	_update_attr_display()

func _update_origin_display(idx: int) -> void:
	if idx >= origin_data.size():
		return
	var origin = origin_data[idx]
	origin_desc.text = origin.get("description", "")
	bonus_attrs = origin.get("bonusAttributes", {})

func _adjust_attr(attr_key: String, delta: int) -> void:
	if delta > 0 and free_points <= 0:
		return
	if delta < 0 and allocated_attrs[attr_key] <= 0:
		return

	allocated_attrs[attr_key] += delta
	free_points -= delta
	_update_attr_display()

func _update_attr_display() -> void:
	for attr_key in attr_labels:
		var base = base_attrs[attr_key]
		var bonus = bonus_attrs.get(attr_key, 0)
		var alloc = allocated_attrs[attr_key]
		var total = base + bonus + alloc
		attr_labels[attr_key].text = str(total)

		# 更新按钮状态
		attr_buttons[attr_key]["minus"].disabled = (alloc <= 0)
		attr_buttons[attr_key]["plus"].disabled = (free_points <= 0)

	free_points_label.text = "剩余属性点: %d" % free_points

func _on_confirm() -> void:
	var player_name = name_input.text.strip_edges()
	if player_name.length() < 2 or player_name.length() > 6:
		_show_error("请输入2-6个汉字的姓名")
		return

	if free_points > 0:
		_show_error("还有%d点属性未分配" % free_points)
		return

	var origin = origin_data[selected_origin_idx]
	var gender = 0 if gender_select.selected == 0 else 1

	# 构建玩家初始数据
	var final_attrs = {}
	for attr_key in base_attrs:
		final_attrs[attr_key] = base_attrs[attr_key] + bonus_attrs.get(attr_key, 0) + allocated_attrs[attr_key]

	GameManager.player_data = {
		"name": player_name,
		"gender": gender,
		"origin_id": origin["id"],
		"stats": {
			"str": final_attrs["str"],
			"agi": final_attrs["agi"],
			"con": final_attrs["con"],
			"int": final_attrs["int"],
			"wil": final_attrs["wil"],
			"lck": final_attrs["lck"],
			"level": 1,
			"experience": 0,
			"free_points": 0,
			"current_hp": final_attrs["con"] * 20,
			"current_qi": final_attrs["wil"] * 10,
		},
		"learned_external": [origin.get("startingSkill", "")],
		"learned_internal": [],
		"learned_lightness": [],
		"equipped_external": origin.get("startingSkill", ""),
		"equipped_internal": "",
		"equipped_lightness": "",
		"inventory": origin.get("startingItems", []),
		"copper": origin.get("startingCopper", 500),
	}

	# 初始化世界状态
	GameManager.world_state = {
		"flags": {},
		"completed_quests": [],
		"active_quests": [],
		"reputation": {"jianghu": 0, "xiayi": 0},
		"affinities": {},
	}
	GameManager.game_time = 28800.0  # 游戏时间从辰时(8:00)开始

	GameManager.change_scene("res://scenes/world/world.tscn")

func _show_error(msg: String) -> void:
	var error_label = Label.new()
	error_label.text = msg
	error_label.modulate = Color.RED
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(error_label)
	error_label.position = Vector2(160, 1000)

	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(error_label.queue_free)
