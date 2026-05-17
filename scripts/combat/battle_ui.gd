# BattleUI.gd
# 战斗界面控制器
# 管理战斗中的招式选择、目标选择、战斗日志
class_name BattleUI
extends CanvasLayer

@onready var skill_panel: Panel = $SkillPanel
@onready var skill_list: HBoxContainer = $SkillPanel/SkillList
@onready var target_panel: Panel = $TargetPanel
@onready var target_list: HBoxContainer = $TargetPanel/TargetList
@onready var battle_log: RichTextLabel = $BattleLog
@onready var info_label: Label = $InfoLabel
@onready var player_hp_bar: ProgressBar = $UnitBars/PlayerBar
@onready var enemy_hp_bar: ProgressBar = $UnitBars/EnemyBar

var _ctrl: BattleController = null

func _ready() -> void:
    var battle_node = get_parent().get_parent()  # BattleUI → BattleUI(CanvasLayer) → Battle(Node2D)
    if battle_node is BattleController:
        _ctrl = battle_node as BattleController
    _clear_ui()

func add_log(text: String) -> void:
    battle_log.append_text(text + "\n")

func show_player_turn(unit: BattleUnit) -> void:
    info_label.text = "你的回合"
    info_label.show()
    _show_skills(unit)

func _show_skills(unit: BattleUnit) -> void:
    _clear_skills()
    var available = unit.get_available_skills()
    skill_panel.show()
    for tech in available:
        var btn = Button.new()
        btn.text = "%s (气:%d)" % [tech.get("name", "?"), tech.get("qiCost", 0)]
        btn.custom_minimum_size = Vector2(130, 50)
        btn.pressed.connect(func():
            skill_panel.hide()
            _show_targets()
            _ctrl.on_player_skill_selected(tech["id"])
        )
        skill_list.add_child(btn)

    # 总是可以基础攻击
    var basic_btn = Button.new()
    basic_btn.text = "基础攻击"
    basic_btn.custom_minimum_size = Vector2(130, 50)
    basic_btn.pressed.connect(func():
        skill_panel.hide()
        _show_targets()
        _ctrl.on_player_skill_selected("__basic__")
    )
    skill_list.add_child(basic_btn)

func _show_targets() -> void:
    _clear_targets()
    target_panel.show()
    var enemies = _ctrl.enemy_units
    for i in range(enemies.size()):
        var e = enemies[i]
        if not e.is_alive():
            continue
        var btn = Button.new()
        btn.text = "%s\nHP:%d/%d" % [e.display_name, e.stats.current_hp, e.stats.max_hp]
        btn.custom_minimum_size = Vector2(140, 60)
        var idx = i
        btn.pressed.connect(func():
            target_panel.hide()
            info_label.hide()
            _ctrl.on_player_target_selected(idx)
        )
        target_list.add_child(btn)

func _clear_ui() -> void:
    info_label.hide()
    skill_panel.hide()
    target_panel.hide()
    _clear_skills()
    _clear_targets()
    battle_log.clear()

func _clear_skills() -> void:
    for child in skill_list.get_children():
        child.queue_free()

func _clear_targets() -> void:
    for child in target_list.get_children():
        child.queue_free()

func update_hp_bars() -> void:
    var player = _ctrl.player_units[0] if _ctrl.player_units.size() > 0 else null
    var enemy = _ctrl.enemy_units[0] if _ctrl.enemy_units.size() > 0 else null
    if player:
        player_hp_bar.max_value = player.stats.max_hp
        player_hp_bar.value = player.stats.current_hp
        player_hp_bar.get_node("Label").text = "%s: %d/%d" % [player.display_name, player.stats.current_hp, player.stats.max_hp]
    if enemy:
        enemy_hp_bar.max_value = enemy.stats.max_hp
        enemy_hp_bar.value = enemy.stats.current_hp
        enemy_hp_bar.get_node("Label").text = "%s: %d/%d" % [enemy.display_name, enemy.stats.current_hp, enemy.stats.max_hp]
