# InventoryUI.gd
# 背包界面控制器
extends CanvasLayer

@onready var panel: Panel = $InventoryPanel
@onready var grid_container: GridContainer = $InventoryPanel/ScrollContainer/GridContainer
@onready var item_detail: Control = $InventoryPanel/ItemDetail
@onready var close_btn: Button = $InventoryPanel/CloseBtn
@onready var equip_btn: Button = $InventoryPanel/ItemDetail/EquipBtn

var inventory_items: Array = []
var selected_item_id: String = ""
var _current_item_data: Dictionary = {}

func _ready() -> void:
    hide()
    close_btn.pressed.connect(hide)
    equip_btn.pressed.connect(_on_equip_pressed)
    EventBus.menu_opened.connect(_on_menu_opened)

func _on_equip_pressed() -> void:
    var eq = GameManager.player_data.get("_equipment", null) as EquipmentManager
    if not eq or _current_item_data.is_empty():
        return
    var slot_str = _current_item_data.get("slot", "")
    var slot_enum = eq._slot_from_string(slot_str)
    if slot_enum == -1:
        return
    var cur = eq.get_equipped(slot_enum)
    if cur == _current_item_data["id"]:
        eq.unequip(slot_enum)
    else:
        eq.equip(_current_item_data["id"])
    item_detail.hide()

func _on_menu_opened(menu_name: String) -> void:
    if menu_name == "inventory":
        show()
        _refresh_display()
    else:
        hide()

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
    _current_item_data = item_data
    item_detail.show()
    item_detail.get_node("ItemName").text = item_data.get("name", "")
    item_detail.get_node("ItemDescription").text = item_data.get("description", "")

    var stats_text = ""
    for stat in item_data.get("baseStats", {}):
        stats_text += "%s: +%d\n" % [stat, item_data["baseStats"][stat]]
    item_detail.get_node("ItemStats").text = stats_text

    # 装备/卸下按钮
    if item_data.has("slot"):
        var eq = GameManager.player_data.get("_equipment", null) as EquipmentManager
        if eq:
            var slot_enum = eq._slot_from_string(item_data["slot"])
            if eq.get_equipped(slot_enum) == item_data["id"]:
                equip_btn.text = "卸下"
            else:
                equip_btn.text = "装备"
            equip_btn.show()
            return
    equip_btn.hide()

func _get_rarity_color(rarity: String) -> Color:
    match rarity:
        "common":    return Color.WHITE
        "uncommon":  return Color.GREEN
        "rare":      return Color.BLUE
        "epic":      return Color.PURPLE
        "legendary": return Color.ORANGE
        "mythic":    return Color.GOLD
        _:           return Color.WHITE