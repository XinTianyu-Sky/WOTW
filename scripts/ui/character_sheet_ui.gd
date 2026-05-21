# CharacterSheetUI.gd
# 角色面板界面
# 显示属性、装备、经脉、武学
extends CanvasLayer

@onready var panel: Panel = $CharacterPanel
@onready var close_btn: Button = $CharacterPanel/CloseBtn

@onready var str_label: Label = $CharacterPanel/AttrGrid/StrValue
@onready var agi_label: Label = $CharacterPanel/AttrGrid/AgiValue
@onready var con_label: Label = $CharacterPanel/AttrGrid/ConValue
@onready var int_label: Label = $CharacterPanel/AttrGrid/IntValue
@onready var wil_label: Label = $CharacterPanel/AttrGrid/WilValue
@onready var lck_label: Label = $CharacterPanel/AttrGrid/LckValue
@onready var free_points_label: Label = $CharacterPanel/FreePoints
@onready var level_label: Label = $CharacterPanel/LevelLabel

@onready var str_btn: Button = $CharacterPanel/AttrGrid/StrBtn
@onready var agi_btn: Button = $CharacterPanel/AttrGrid/AgiBtn
@onready var con_btn: Button = $CharacterPanel/AttrGrid/ConBtn
@onready var int_btn: Button = $CharacterPanel/AttrGrid/IntBtn
@onready var wil_btn: Button = $CharacterPanel/AttrGrid/WilBtn
@onready var lck_btn: Button = $CharacterPanel/AttrGrid/LckBtn

@onready var combat_stats: RichTextLabel = $CharacterPanel/CombatStats
@onready var equip_label: Label = $CharacterPanel/EquipLabel

var player_stats: PlayerStats = null

func _ready() -> void:
	hide()
	close_btn.pressed.connect(_close)
	EventBus.menu_opened.connect(_on_menu_opened)
	EventBus.attribute_changed.connect(func(_a, _v): _refresh())
	EventBus.equipment_changed.connect(func(_s, _i): _refresh())

	str_btn.pressed.connect(func(): _allocate("str"))
	agi_btn.pressed.connect(func(): _allocate("agi"))
	con_btn.pressed.connect(func(): _allocate("con"))
	int_btn.pressed.connect(func(): _allocate("int"))
	wil_btn.pressed.connect(func(): _allocate("wil"))
	lck_btn.pressed.connect(func(): _allocate("lck"))

func _close() -> void:
	hide()
	EventBus.menu_closed.emit("character")

func _on_menu_opened(menu_name: String) -> void:
	if menu_name == "character":
		show()
		_refresh()
	else:
		hide()

func set_stats(stats: PlayerStats) -> void:
	player_stats = stats
	_refresh()

func _refresh() -> void:
	if player_stats == null:
		return

	level_label.text = "等级: %d  (EXP %d / %d)" % [player_stats.level, player_stats.experience, player_stats.get_exp_for_next_level()]
	str_label.text = str(player_stats.str)
	agi_label.text = str(player_stats.agi)
	con_label.text = str(player_stats.con)
	int_label.text = str(player_stats.int_)
	wil_label.text = str(player_stats.wil)
	lck_label.text = str(player_stats.lck)
	free_points_label.text = "剩余属性点: %d" % player_stats.free_points

	var can_allocate = player_stats.free_points > 0
	str_btn.disabled = not can_allocate
	agi_btn.disabled = not can_allocate
	con_btn.disabled = not can_allocate
	int_btn.disabled = not can_allocate
	wil_btn.disabled = not can_allocate
	lck_btn.disabled = not can_allocate

	combat_stats.text = "[table]
    生命值: %d / %d
    内力值: %d / %d
    攻击力: %d
    防御力: %d
    内劲: %d
    内防: %d
    速度: %d
    命中率: %.1f%%
    闪避率: %.1f%%
    暴击率: %.1f%%
    暴击伤害: %.0f%%
	[/table]" % [
		player_stats.current_hp, player_stats.max_hp,
		player_stats.current_qi, player_stats.max_qi,
		player_stats.attack, player_stats.defense,
		player_stats.inner_power, player_stats.inner_defense,
		player_stats.speed,
		player_stats.hit_rate * 100, player_stats.dodge_rate * 100,
		player_stats.crit_rate * 100, player_stats.crit_damage * 100
	]
	# 装备显示
	var eq = GameManager.player_data.get("_equipment", null) as EquipmentManager
	if eq:
		var slot_names = {
			EquipmentManager.Slot.WEAPON: "武器",
			EquipmentManager.Slot.OFFHAND: "副手",
			EquipmentManager.Slot.HEAD: "头部",
			EquipmentManager.Slot.BODY: "身体",
			EquipmentManager.Slot.FEET: "脚步",
			EquipmentManager.Slot.ACCESSORY1: "饰品1",
			EquipmentManager.Slot.ACCESSORY2: "饰品2",
		}
		var text = ""
		for slot in slot_names:
			var item_data = eq.get_equipped_data(slot)
			var name = item_data.get("name", "空") if not item_data.is_empty() else "空"
			text += "%s: %s\n" % [slot_names[slot], name]
		equip_label.text = text

func _allocate(attr_name: String) -> void:
	if player_stats == null:
		return
	if player_stats.allocate_point(attr_name):
		_refresh()
		NotificationManager.notify("%s +1" % _attr_display_name(attr_name))

func _attr_display_name(attr: String) -> String:
	match attr:
		"str": return "膂力"
		"agi": return "身法"
		"con": return "根骨"
		"int": return "悟性"
		"wil": return "定力"
		"lck": return "机缘"
	return attr
