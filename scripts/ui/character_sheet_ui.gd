# CharacterSheetUI.gd
# 角色面板界面
# 显示属性、装备、经脉、武学
extends CanvasLayer

@onready var panel: Panel = $CharacterPanel
@onready var close_btn: Button = $CharacterPanel/CloseBtn

# ---- 属性标签 ----
@onready var str_label: Label = $CharacterPanel/TabContainer/Attributes/StrValue
@onready var agi_label: Label = $CharacterPanel/TabContainer/Attributes/AgiValue
@onready var con_label: Label = $CharacterPanel/TabContainer/Attributes/ConValue
@onready var int_label: Label = $CharacterPanel/TabContainer/Attributes/IntValue
@onready var wil_label: Label = $CharacterPanel/TabContainer/Attributes/WilValue
@onready var lck_label: Label = $CharacterPanel/TabContainer/Attributes/LckValue
@onready var free_points_label: Label = $CharacterPanel/TabContainer/Attributes/FreePoints
@onready var level_label: Label = $CharacterPanel/TabContainer/Attributes/LevelLabel

# ---- 战斗属性 ----
@onready var combat_stats: RichTextLabel = $CharacterPanel/TabContainer/Attributes/CombatStats

var player_stats: PlayerStats = null

func _ready() -> void:
    hide()
    close_btn.pressed.connect(hide)
    EventBus.menu_opened.connect(_on_menu_opened)
    EventBus.attribute_changed.connect(func(_a, _v): _refresh())

func _on_menu_opened(menu_name: String) -> void:
    if menu_name == "character":
        show()
        _refresh()

func set_stats(stats: PlayerStats) -> void:
    player_stats = stats
    _refresh()

func _refresh() -> void:
    if player_stats == null:
        return

    level_label.text = "等级: %d" % player_stats.level
    str_label.text = str(player_stats.str)
    agi_label.text = str(player_stats.agi)
    con_label.text = str(player_stats.con)
    int_label.text = str(player_stats.int_)
    wil_label.text = str(player_stats.wil)
    lck_label.text = str(player_stats.lck)
    free_points_label.text = "剩余属性点: %d" % player_stats.free_points

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