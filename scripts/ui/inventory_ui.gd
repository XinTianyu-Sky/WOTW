# InventoryUI.gd
# 背包界面控制器
extends CanvasLayer

@onready var panel: Panel = $InventoryPanel
@onready var grid_container: GridContainer = $InventoryPanel/ScrollContainer/GridContainer
@onready var item_detail: Control = $InventoryPanel/ItemDetail
@onready var close_btn: Button = $InventoryPanel/CloseBtn

var inventory_items: Array = []
var selected_item_id: String = ""

func _ready() -> void:
    hide()
    close_btn.pressed.connect(hide)
    EventBus.menu_opened.connect(_on_menu_opened)

func _on_menu_opened(menu_name: String) -> void:
    if menu_name == "inventory":
        show()
        _refresh_display()

func _refresh_display() -> void:
    for child in grid_container.get_children():
        child.queue_free()

    for item in inventory_items:
        var item_data = DataManager.get_item(item["id"])
        if item_data.is_empty():
            continue
        var slot = _create_item_slot(item_data, item.get("count", 1))
        grid_container.add_child(slot)

func _create_item_slot(item_data: Dictionary, count: int) -> Control:
    var btn = Button.new()
    btn.text = "%s x%d" % [item_data.get("name", "???"), count]
    btn.custom_minimum_size = Vector2(80, 80)

    var rarity_color = _get_rarity_color(item_data.get("rarity", "common"))
    btn.modulate = rarity_color

    btn.pressed.connect(func():
        selected_item_id = item_data["id"]
        _show_item_detail(item_data)
    )

    return btn

func _show_item_detail(item_data: Dictionary) -> void:
    item_detail.show()
    item_detail.get_node("ItemName").text = item_data.get("name", "")
    item_detail.get_node("ItemDescription").text = item_data.get("description", "")

    var stats_text = ""
    for stat in item_data.get("baseStats", {}):
        stats_text += "%s: +%d\n" % [stat, item_data["baseStats"][stat]]
    item_detail.get_node("ItemStats").text = stats_text

    # 装备/卸下按钮
    var eq_btn = item_detail.get_node_or_null("EquipBtn")
    if eq_btn:
        var eq = GameManager.player_data.get("_equipment", null) as EquipmentManager
        if eq and item_data.get("type") == "equipment":
            var slot_str = item_data.get("slot", "")
            var slot_enum = eq._slot_from_string(slot_str)
            var cur = eq.get_equipped(slot_enum) if slot_enum != -1 else ""
            if cur == item_data["id"]:
                eq_btn.text = "卸下"
                eq_btn.pressed.connect(func():
                    eq.unequip(slot_enum)
                    item_detail.hide()
                , CONNECT_ONE_SHOT)
            else:
                eq_btn.text = "装备"
                eq_btn.pressed.connect(func():
                    eq.equip(item_data["id"])
                    item_detail.hide()
                , CONNECT_ONE_SHOT)
            eq_btn.show()
        else:
            eq_btn.hide()

func _get_rarity_color(rarity: String) -> Color:
    match rarity:
        "common":    return Color.WHITE
        "uncommon":  return Color.GREEN
        "rare":      return Color.BLUE
        "epic":      return Color.PURPLE
        "legendary": return Color.ORANGE
        "mythic":    return Color.GOLD
        _:           return Color.WHITE