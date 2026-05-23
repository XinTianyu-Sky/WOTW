# MapManager.gd
# 使用 Puny World 像素风瓦片集的地图渲染
class_name MapManager
extends TileMapLayer

# Puny World tiles are 16x16, map is 80×60 = 1280×960
const TILE_SZ: int = 16
const MAP_W: int = 80
const MAP_H: int = 60

# ---- 瓦片图集坐标（Puny World Overworld） ----
# 草地块（左上角 0-2 列）
const T_GRASS = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
]
# 带装饰的草地
const T_GRASS_DECOR = [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
	Vector2i(3, 4), Vector2i(4, 4), Vector2i(0, 5),
	Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5),
]
# 水域帧（行 10-21 包含多帧动画）
const T_WATER_A = [Vector2i(10, 10), Vector2i(11, 10), Vector2i(17, 10)]
const T_WATER_B = [Vector2i(10, 11), Vector2i(11, 11), Vector2i(17, 11)]
# 山崖
const T_CLIFF_SOLID = Vector2i(8, 1)
const T_CLIFF_EDGE = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(4, 1), Vector2i(5, 1)]
# 土路
const T_DIRT = [
	Vector2i(6, 27), Vector2i(7, 27), Vector2i(5, 28),
	Vector2i(6, 28), Vector2i(7, 28),
]
# 树木
const T_TREE = [
	Vector2i(6, 4), Vector2i(10, 4), Vector2i(12, 4),
	Vector2i(6, 5), Vector2i(10, 5), Vector2i(12, 5),
	Vector2i(15, 5), Vector2i(16, 5), Vector2i(18, 5),
]
# 建筑（墙 + 屋顶）
const T_BLDG_WALL = [Vector2i(10, 28), Vector2i(11, 28), Vector2i(14, 28), Vector2i(15, 28)]
const T_BLDG_ROOF = [Vector2i(5, 28), Vector2i(6, 28), Vector2i(7, 28), Vector2i(8, 28)]

var _blocked_set: Dictionary = {}
var _rng = RandomNumberGenerator.new()

@export var map_seed: int = 42
@export var has_village: bool = false
@export var village_center: Vector2i = Vector2i(40, 30)
@export var water_level: float = -0.28
@export var mountain_level: float = 0.52

func _ready() -> void:
	_rng.seed = map_seed
	_build_blocked_set()
	var ts = _create_tileset()
	tile_set = ts
	_draw_map()
	_setup_camera_bounds()

func _build_blocked_set() -> void:
	var blocked_coords = [
		T_CLIFF_SOLID,
		T_WATER_A[0], T_WATER_A[1], T_WATER_A[2],
		T_WATER_B[0], T_WATER_B[1], T_WATER_B[2],
	]
	blocked_coords.append_array(T_CLIFF_EDGE)
	blocked_coords.append_array(T_BLDG_WALL)
	blocked_coords.append_array(T_BLDG_ROOF)
	blocked_coords.append_array(T_TREE)
	for c in blocked_coords:
		_blocked_set[c] = true

# ---- TileSet 构建 ----
func _create_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(TILE_SZ, TILE_SZ)

	var tex = load("res://assets/tilesets/punyworld_overworld.png") as Texture2D
	if not tex:
		push_error("MapManager: 无法加载 Puny World 瓦片集")
		return ts

	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)

	var source = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SZ, TILE_SZ)
	var source_id = ts.add_source(source)

	# 为每个用到的瓦片创建 tile，碰撞瓦片加碰撞
	var all_coords: Array[Vector2i] = []
	all_coords.append_array(T_GRASS)
	all_coords.append_array(T_GRASS_DECOR)
	all_coords.append_array(T_WATER_A)
	all_coords.append_array(T_WATER_B)
	all_coords.append(T_CLIFF_SOLID)
	all_coords.append_array(T_CLIFF_EDGE)
	all_coords.append_array(T_DIRT)
	all_coords.append_array(T_TREE)
	all_coords.append_array(T_BLDG_WALL)
	all_coords.append_array(T_BLDG_ROOF)

	for coord in all_coords:
		source.create_tile(coord, Vector2i(1, 1))
		if _blocked_set.has(coord):
			var td = source.get_tile_data(coord, 0)
			if td:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(0, 0), Vector2(TILE_SZ, 0),
					Vector2(TILE_SZ, TILE_SZ), Vector2(0, TILE_SZ),
				]))

	return ts

# ---- 噪声 ----
func _hash_noise(x: int, y: int) -> float:
	var v = (x * 1619 + y * 31337) & 0x7fffffff
	v = (v >> 13) ^ v
	v = (v * (v * v * 60493 + 19990303) + 1376312589) & 0x7fffffff
	return (float(v % 1000) / 500.0) - 1.0

func _fbm(x: int, y: int, octaves: int = 3) -> float:
	var v = 0.0; var amp = 0.6; var total = 0.0
	var sx = x; var sy = y
	for _i in range(octaves):
		v += _hash_noise(sx, sy) * amp
		total += amp
		amp *= 0.45
		sx = sx * 2 + 137
		sy = sy * 2 + 259
	return v / total

# ---- 地图绘制 ----
func _draw_map() -> void:
	clear()
	var height_map = _build_height_map()
	var tree_map = _build_tree_map()
	var path_set = _build_path_set()

	for y in range(MAP_H):
		for x in range(MAP_W):
			var h = height_map[y][x]
			var tile = _pick_tile(x, y, h, tree_map[y][x], path_set)
			set_cell(Vector2i(x, y), 0, tile)

func _build_height_map() -> Array:
	var map = []
	for y in range(MAP_H):
		var row = []
		for x in range(MAP_W):
			row.append(_fbm(x, y, 3))
		map.append(row)
	return map

func _build_tree_map() -> Array:
	var map = []
	for y in range(MAP_H):
		var row = []
		for x in range(MAP_W):
			row.append(_hash_noise(x * 3 + 300, y * 3 + 300))
		map.append(row)
	return map

func _build_path_set() -> Dictionary:
	var paths = {}
	if not has_village:
		return paths
	var vc = village_center
	for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var cur = vc
		for _step in range(60):
			cur += dir
			if cur.x < 3 or cur.x >= MAP_W - 3 or cur.y < 3 or cur.y >= MAP_H - 3:
				break
			var wobble = Vector2i(0, 0)
			if dir.x == 0:
				wobble.x = int(_hash_noise(cur.x, cur.y + map_seed) * 3.5)
			else:
				wobble.y = int(_hash_noise(cur.x + map_seed, cur.y) * 3.5)
			var p = cur + wobble
			if p.x >= 0 and p.x < MAP_W and p.y >= 0 and p.y < MAP_H:
				paths[Vector2i(p.x, p.y)] = true
	return paths

func _pick_tile(x: int, y: int, height: float, tree_noise: float, paths: Dictionary) -> Vector2i:
	var pos = Vector2i(x, y)

	# 边界强制山崖
	if x <= 1 or x >= MAP_W - 2 or y <= 1 or y >= MAP_H - 2:
		return _rand_pick(T_CLIFF_EDGE if _rng.randf() < 0.7 else [T_CLIFF_SOLID])

	# 村庄
	if has_village:
		var vc = village_center
		var dx = x - vc.x; var dy = y - vc.y
		if abs(dx) <= 8 and abs(dy) <= 6:
			# 建筑群
			if abs(dx) >= 5 and abs(dy) >= 3 and (dx + 30) % 7 >= 3:
				if (x + y) % 3 == 0:
					return _rand_pick(T_BLDG_ROOF)
				return _rand_pick(T_BLDG_WALL)
			return _rand_pick(T_DIRT if paths.has(pos) or _rng.randf() < 0.6 else T_GRASS)
		if abs(dx) <= 12 and abs(dy) <= 10:
			if paths.has(pos):
				return _rand_pick(T_DIRT)

	# 道路
	if paths.has(pos):
		return _rand_pick(T_DIRT)

	# 高度 → 地形
	if height < water_level:
		if _rng.randf() < 0.5:
			return _rand_pick(T_WATER_A)
		return _rand_pick(T_WATER_B)
	elif height < water_level + 0.1:
		return _rand_pick(T_DIRT)
	elif height < mountain_level:
		if tree_noise > 0.62 and height < mountain_level - 0.1:
			return _rand_pick(T_TREE)
		if height > mountain_level - 0.08:
			if _rng.randf() < 0.4:
				return _rand_pick(T_CLIFF_EDGE)
			return _rand_pick(T_GRASS_DECOR)
		if _rng.randf() < 0.7:
			return _rand_pick(T_GRASS)
		return _rand_pick(T_GRASS_DECOR)
	else:
		if _rng.randf() < 0.6:
			return T_CLIFF_SOLID
		return _rand_pick(T_CLIFF_EDGE)

func _rand_pick(arr: Array) -> Variant:
	return arr[_rng.randi() % arr.size()]

func _setup_camera_bounds() -> void:
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("set_map_bounds"):
		cam.set_map_bounds(Rect2(0, 0, MAP_W * TILE_SZ, MAP_H * TILE_SZ))
