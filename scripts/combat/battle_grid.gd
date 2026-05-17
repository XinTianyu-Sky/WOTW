# BattleGrid.gd
# 六边形网格战场
# 管理战斗地图、地形、移动范围计算
class_name BattleGrid
extends RefCounted

# ---- 网格属性 ----
var width: int = 8
var height: int = 8
var cells: Array = []          # 二维数组 [x][y] -> cell_data

# ---- 地形数据 ----
const TERRAIN_TYPES = {
    "plain":   {"move_cost": 1, "dodge_bonus": 0.0, "fire_mod": 0.0, "water_mod": 0.0},
    "highland":{"move_cost": 2, "dodge_bonus": 0.0, "fire_mod": 0.0, "water_mod": 0.0, "damage_bonus": 0.2, "defense_bonus": 0.1},
    "water":   {"move_cost": 2, "dodge_bonus": 0.0, "fire_mod": -0.3, "water_mod": 0.5},
    "grass":   {"move_cost": 1, "dodge_bonus": 0.15, "fire_mod": 0.0, "water_mod": 0.0},
    "fire":    {"move_cost": 1, "dodge_bonus": 0.0, "fire_mod": 0.2, "water_mod": -0.2, "damage_per_turn": 0.05},
    "ice":     {"move_cost": 1, "dodge_bonus": -0.1, "fire_mod": -0.1, "water_mod": 0.2, "slide_chance": 0.3},
    "miasma":  {"move_cost": 1, "dodge_bonus": 0.0, "fire_mod": 0.0, "water_mod": 0.0, "poison_per_turn": 0.03},
    "trap":    {"move_cost": 1, "dodge_bonus": 0.0, "fire_mod": 0.0, "water_mod": 0.0},
}

func init_grid(w: int, h: int, terrain_data: Dictionary = {}) -> void:
    width = w
    height = h
    cells.clear()
    for x in range(width):
        var column = []
        for y in range(height):
            var coord_key = "%d,%d" % [x, y]
            var terrain_id = terrain_data.get(coord_key, "plain")
            column.append({"terrain": terrain_id, "occupied_by": ""})
        cells.append(column)

func get_cell(pos: Vector2i) -> Dictionary:
    if not is_in_bounds(pos):
        return {"terrain": "wall", "occupied_by": ""}
    return cells[pos.x][pos.y]

func is_in_bounds(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func is_passable(pos: Vector2i) -> bool:
    var cell = get_cell(pos)
    if cell["terrain"] == "wall":
        return false
    return cell["occupied_by"].is_empty()

func occupy_cell(pos: Vector2i, unit_id: String) -> void:
    if is_in_bounds(pos):
        cells[pos.x][pos.y]["occupied_by"] = unit_id

func free_cell(pos: Vector2i) -> void:
    if is_in_bounds(pos):
        cells[pos.x][pos.y]["occupied_by"] = ""

# ---- 移动范围计算（六边形 BFS） ----
func get_move_range(start: Vector2i, move_points: int, can_cross_water: bool = false) -> Array:
    var visited: Dictionary = {}
    var result: Array = []
    var queue: Array = [{"pos": start, "remaining": move_points}]
    visited[_pos_key(start)] = move_points

    while queue.size() > 0:
        var current = queue.pop_front()
        var pos = current["pos"]
        var remaining = current["remaining"]

        if remaining < 0:
            continue

        if pos != start:
            result.append(pos)

        for neighbor in _get_hex_neighbors(pos):
            if not is_in_bounds(neighbor):
                continue
            if visited.has(_pos_key(neighbor)):
                continue

            var cell = get_cell(neighbor)
            if cell["terrain"] == "wall":
                continue
            if cell["occupied_by"] != "" and neighbor != start:
                continue

            var cost = TERRAIN_TYPES.get(cell["terrain"], {}).get("move_cost", 1)
            if cell["terrain"] == "water" and not can_cross_water:
                continue

            var new_remaining = remaining - cost
            if new_remaining >= 0:
                visited[_pos_key(neighbor)] = new_remaining
                queue.append({"pos": neighbor, "remaining": new_remaining})

    return result

# ---- 六边形坐标工具 ----
func _get_hex_neighbors(pos: Vector2i) -> Array:
    var is_even = pos.x % 2 == 0
    var offsets = [
        Vector2i(1, 0), Vector2i(-1, 0),
        Vector2i(0, 1), Vector2i(0, -1),
    ]

    if is_even:
        offsets.append(Vector2i(1, -1))
        offsets.append(Vector2i(-1, -1))
    else:
        offsets.append(Vector2i(1, 1))
        offsets.append(Vector2i(-1, 1))

    var result: Array = []
    for offset in offsets:
        result.append(pos + offset)
    return result

func _pos_key(pos: Vector2i) -> String:
    return "%d,%d" % [pos.x, pos.y]

# ---- 六边形坐标转像素 ----
func hex_to_pixel(pos: Vector2i, hex_size: float = 64.0) -> Vector2:
    var is_even = pos.x % 2 == 0
    var x = pos.x * hex_size * 0.75
    var y = pos.y * hex_size
    if not is_even:
        y += hex_size * 0.5
    return Vector2(x, y)

func pixel_to_hex(pixel: Vector2, hex_size: float = 64.0) -> Vector2i:
    var x = int(pixel.x / (hex_size * 0.75))
    var is_even = x % 2 == 0
    var y_offset = 0.0 if is_even else hex_size * 0.5
    var y = int((pixel.y - y_offset) / hex_size)
    return Vector2i(x, y)