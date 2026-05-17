# EquipmentManager.gd
# 装备管理器
# 管理玩家装备栏、装备切换、属性计算
class_name EquipmentManager
extends RefCounted

# ---- 装备槽位 ----
enum Slot { WEAPON, OFFHAND, HEAD, BODY, FEET, ACCESSORY1, ACCESSORY2 }

const SLOT_NAMES: Dictionary = {
    Slot.WEAPON: "weapon",
    Slot.OFFHAND: "offhand",
    Slot.HEAD: "head",
    Slot.BODY: "body",
    Slot.FEET: "feet",
    Slot.ACCESSORY1: "accessory1",
    Slot.ACCESSORY2: "accessory2",
}

# ---- 已装备物品 ----
var _equipped: Dictionary = {}

# ---- 装备操作 ----
func equip(item_id: String) -> bool:
    var item_data = DataManager.get_item(item_id)
    if item_data.is_empty() or item_data.get("type") != "equipment":
        return false

    var slot_str = item_data.get("slot", "")
    var slot = _slot_from_string(slot_str)
    if slot == -1:
        return false

    var old_item = _equipped.get(slot, "")
    _equipped[slot] = item_id
    EventBus.equipment_changed.emit(SLOT_NAMES[slot], item_id)
    return true

func unequip(slot: Slot) -> String:
    var old = _equipped.get(slot, "")
    _equipped.erase(slot)
    if not old.is_empty():
        EventBus.equipment_changed.emit(SLOT_NAMES[slot], "")
    return old

func get_equipped(slot: Slot) -> String:
    return _equipped.get(slot, "")

func get_equipped_data(slot: Slot) -> Dictionary:
    var item_id = get_equipped(slot)
    if item_id.is_empty():
        return {}
    return DataManager.get_item(item_id)

# ---- 汇总装备加成 ----
func get_total_bonuses() -> Dictionary:
    var bonuses: Dictionary = {}
    for slot in _equipped:
        var item_data = DataManager.get_item(_equipped[slot])
        if item_data.is_empty():
            continue
        for stat in item_data.get("baseStats", {}):
            bonuses[stat] = bonuses.get(stat, 0) + item_data["baseStats"][stat]
        for stat in item_data.get("bonusStats", {}):
            bonuses[stat] = bonuses.get(stat, 0.0) + item_data["bonusStats"][stat]
    return bonuses

# ---- 检查套装效果 ----
func get_active_set_bonuses() -> Dictionary:
    var set_counts: Dictionary = {}
    for slot in _equipped:
        var item_data = DataManager.get_item(_equipped[slot])
        var set_id = item_data.get("setId", "")
        if set_id.is_empty():
            continue
        set_counts[set_id] = set_counts.get(set_id, 0) + 1

    var bonuses: Dictionary = {}
    # TODO: 从数据中读取套装效果，计算激活的件数效果
    return bonuses

# ---- 序列化 ----
func to_dict() -> Dictionary:
    var result: Dictionary = {}
    for slot in _equipped:
        result[SLOT_NAMES[slot]] = _equipped[slot]
    return result

func from_dict(data: Dictionary) -> void:
    _equipped.clear()
    for slot_name in data:
        var slot = _slot_from_string(slot_name)
        if slot != -1:
            _equipped[slot] = data[slot_name]

func _slot_from_string(s: String) -> int:
    for slot in SLOT_NAMES:
        if SLOT_NAMES[slot] == s:
            return slot
    return -1