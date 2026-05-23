# MapManager.gd
# Puny World 像素风瓦片集（32×32 放大版）
class_name MapManager
extends TileMapLayer

const TILE_SZ: int = 32
const MAP_W: int = 40
const MAP_H: int = 30

# ---- 瓦片图集坐标 ----
const T_GRASS = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
]
const T_GRASS_DECOR = [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
	Vector2i(3, 4), Vector2i(4, 4), Vector2i(0, 5),
	Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5),
]
const T_WATER_A = [Vector2i(10, 10), Vector2i(11, 10), Vector2i(17, 10)]
const T_WATER_B = [Vector2i(10, 11), Vector2i(11, 11), Vector2i(17, 11)]
const T_CLIFF_SOLID = Vector2i(8, 1)
const T_CLIFF_EDGE = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(4, 1), Vector2i(5, 1)]
const T_DIRT = [
	Vector2i(6, 27), Vector2i(7, 27), Vector2i(5, 28),
	Vector2i(6, 28), Vector2i(7, 28),
]
const T_TREE = [
	Vector2i(6, 4), Vector2i(10, 4), Vector2i(12, 4),
	Vector2i(6, 5), Vector2i(10, 5), Vector2i(12, 5),
	Vector2i(15, 5), Vector2i(16, 5), Vector2i(18, 5),
]
const T_BLDG_WALL = [Vector2i(10, 28), Vector2i(11, 28), Vector2i(14, 28), Vector2i(15, 28)]
const T_BLDG_ROOF = [Vector2i(5, 28), Vector2i(6, 28), Vector2i(7, 28), Vector2i(8, 28)]

var _blocked: Dictionary = {}
var _rng = RandomNumberGenerator.new()

@export var map_seed: int = 42
@export var has_village: bool = false
@export var village_center: Vector2i = Vector2i(13, 11)
@export var water_level: float = -0.35
@export var mountain_level: float = 0.52

func _ready() -> void:
	_rng.seed = map_seed
	_build_blocked()
	var ts = _make_tileset()
	tile_set = ts
	_draw_map()
	_setup_camera_bounds()

func _build_blocked() -> void:
	var coords = [
		T_CLIFF_SOLID,
		T_WATER_A[0], T_WATER_A[1], T_WATER_A[2],
		T_WATER_B[0], T_WATER_B[1], T_WATER_B[2],
	]
	coords.append_array(T_BLDG_WALL)
	coords.append_array(T_BLDG_ROOF)
	for c in coords:
		_blocked[c] = true

func _make_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(TILE_SZ, TILE_SZ)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)

	var tex = load("res://assets/tilesets/punyworld_32.png")
	if not tex:
		push_error("MapManager: 无法加载 punyworld_32.png")
		return ts

	var src = TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_SZ, TILE_SZ)
	ts.add_source(src)

	# 注册所有瓦片，碰撞瓦片加碰撞多边形
	var all: Array[Vector2i] = []
	all.append_array(T_GRASS)
	all.append_array(T_GRASS_DECOR)
	all.append_array(T_WATER_A)
	all.append_array(T_WATER_B)
	all.append(T_CLIFF_SOLID)
	all.append_array(T_CLIFF_EDGE)
	all.append_array(T_DIRT)
	all.append_array(T_TREE)
	all.append_array(T_BLDG_WALL)
	all.append_array(T_BLDG_ROOF)

	for coord in all:
		src.create_tile(coord, Vector2i(1, 1))
		if _blocked.has(coord):
			var td = src.get_tile_data(coord, 0)
			if td:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(0, 0), Vector2(TILE_SZ, 0),
					Vector2(TILE_SZ, TILE_SZ), Vector2(0, TILE_SZ),
				]))
	return ts

# ---- 噪声 ----
func _hash(x: int, y: int) -> float:
	var v = (x * 1619 + y * 31337) & 0x7fffffff
	v = (v >> 13) ^ v
	v = (v * (v * v * 60493 + 19990303) + 1376312589) & 0x7fffffff
	return (float(v % 1000) / 500.0) - 1.0

func _fbm(x: int, y: int, octaves: int = 3) -> float:
	var v = 0.0; var amp = 0.6; var total = 0.0
	var sx = x; var sy = y
	for _i in range(octaves):
		v += _hash(sx, sy) * amp
		total += amp
		amp *= 0.45
		sx = sx * 2 + 137
		sy = sy * 2 + 259
	return v / total

# ---- 绘图 ----
func _draw_map() -> void:
	clear()
	var heights = _make_height_map()
	var trees = _make_tree_map()
	var paths = _make_paths()

	for y in range(MAP_H):
		for x in range(MAP_W):
			set_cell(Vector2i(x, y), 0, _pick(x, y, heights[y][x], trees[y][x], paths))

func _make_height_map() -> Array:
	var m = [];
	for y in range(MAP_H):
		var r = [];
		for x in range(MAP_W):
			r.append(_fbm(x, y, 3))
		m.append(r)
	return m

func _make_tree_map() -> Array:
	var m = [];
	for y in range(MAP_H):
		var r = [];
		for x in range(MAP_W):
			r.append(_hash(x * 3 + 300, y * 3 + 300))
		m.append(r)
	return m

func _make_paths() -> Dictionary:
	var p = {}
	if not has_village:
		return p
	var vc = village_center
	for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var cur = vc
		for _step in range(30):
			cur += dir
			if cur.x < 2 or cur.x >= MAP_W - 2 or cur.y < 2 or cur.y >= MAP_H - 2:
				break
			var w = Vector2i(0, 0)
			if dir.x == 0:
				w.x = int(_hash(cur.x, cur.y + map_seed) * 2.5)
			else:
				w.y = int(_hash(cur.x + map_seed, cur.y) * 2.5)
			var pt = cur + w
			if pt.x >= 0 and pt.x < MAP_W and pt.y >= 0 and pt.y < MAP_H:
				p[Vector2i(pt.x, pt.y)] = true
	return p

func _pick(x: int, y: int, h: float, tn: float, paths: Dictionary) -> Vector2i:
	var pos = Vector2i(x, y)

	if x <= 1 or x >= MAP_W - 2 or y <= 1 or y >= MAP_H - 2:
		return _rand(T_CLIFF_EDGE if _rng.randf() < 0.7 else [T_CLIFF_SOLID])

	if has_village:
		var vc = village_center
		var dx = x - vc.x; var dy = y - vc.y
		if abs(dx) <= 8 and abs(dy) <= 6:
			if abs(dx) >= 5 and abs(dy) >= 3 and (dx + 30) % 7 >= 3:
				return _rand(T_BLDG_ROOF if (x + y) % 3 == 0 else T_BLDG_WALL)
			return _rand(T_DIRT if paths.has(pos) or _rng.randf() < 0.6 else T_GRASS)
		if abs(dx) <= 12 and abs(dy) <= 10:
			if paths.has(pos):
				return _rand(T_DIRT)

	if paths.has(pos):
		return _rand(T_DIRT)

	if h < water_level:
		return _rand(T_WATER_A if _rng.randf() < 0.5 else T_WATER_B)
	elif h < water_level + 0.1:
		return _rand(T_DIRT)
	elif h < mountain_level:
		if tn > 0.78 and h < mountain_level - 0.15:
			return _rand(T_TREE)
		if h > mountain_level - 0.08:
			return _rand(T_CLIFF_EDGE if _rng.randf() < 0.4 else T_GRASS_DECOR)
		return _rand(T_GRASS if _rng.randf() < 0.7 else T_GRASS_DECOR)
	else:
		return T_CLIFF_SOLID if _rng.randf() < 0.6 else _rand(T_CLIFF_EDGE)

func _rand(arr: Array) -> Variant:
	return arr[_rng.randi() % arr.size()]

func _setup_camera_bounds() -> void:
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("set_map_bounds"):
		cam.set_map_bounds(Rect2(0, 0, MAP_W * TILE_SZ, MAP_H * TILE_SZ))
