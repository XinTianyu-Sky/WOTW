# MapManager.gd
# 纯文字版地图 — 汉字渲染为瓦片，零美术依赖
class_name MapManager
extends TileMapLayer

const TILE_SZ: int = 32
const MAP_W: int = 40
const MAP_H: int = 30
const FONT_SIZE: int = 24

# 瓦片定义：[名称, 汉字, 前景色, 背景色, 是否阻挡]
const CHAR_DEFS = [
	["g0", "艹", Color(0.25, 0.6, 0.2),  Color(0.06, 0.12, 0.04), false],
	["g1", "丶", Color(0.3, 0.68, 0.25), Color(0.08, 0.14, 0.05), false],
	["g2", "十", Color(0.22, 0.55, 0.18), Color(0.06, 0.12, 0.04), false],
	["w0", "水", Color(0.3, 0.7, 0.95),  Color(0.02, 0.06, 0.15), true],
	["w1", "江", Color(0.35, 0.75, 1.0), Color(0.03, 0.08, 0.18), true],
	["s0", "山", Color(0.72, 0.72, 0.75), Color(0.14, 0.14, 0.16), true],
	["s1", "岩", Color(0.65, 0.65, 0.68), Color(0.16, 0.16, 0.18), true],
	["d0", "土", Color(0.72, 0.55, 0.35), Color(0.15, 0.1, 0.05),  false],
	["d1", "道", Color(0.78, 0.6, 0.38),  Color(0.15, 0.1, 0.05),  false],
	["t0", "木", Color(0.18, 0.55, 0.15), Color(0.05, 0.12, 0.04), false],
	["t1", "林", Color(0.15, 0.48, 0.12), Color(0.06, 0.13, 0.05), false],
	["b0", "舍", Color(0.92, 0.7, 0.3),  Color(0.18, 0.08, 0.03), true],
	["b1", "坊", Color(0.88, 0.62, 0.25), Color(0.18, 0.08, 0.03), true],
]

# 瓦片索引（图集中从左到右排列）
const I_GRASS   = [0, 1, 2]
const I_WATER   = [3, 4]
const I_MOUNT   = [5, 6]
const I_DIRT    = [7, 8]
const I_TREE    = [9, 10]
const I_BLDG    = [11, 12]
const I_BLOCKED = [3, 4, 5, 6, 11, 12]

var _rng = RandomNumberGenerator.new()
var _atlas_img: Image = null

@export var map_seed: int = 42
@export var has_village: bool = false
@export var village_center: Vector2i = Vector2i(13, 11)
@export var water_level: float = -0.35
@export var mountain_level: float = 0.52

func _ready() -> void:
	_rng.seed = map_seed
	_bake_atlas()
	var ts = _make_tileset()
	tile_set = ts
	_draw_map()
	_setup_camera_bounds()

# ---- 同步绘制字符瓦片图集（不走 SubViewport/await） ----
func _bake_atlas() -> void:
	var n = CHAR_DEFS.size()
	_atlas_img = Image.create(n * TILE_SZ, TILE_SZ, false, Image.FORMAT_RGBA8)

	for i in range(n):
		var d = CHAR_DEFS[i]
		var ch = d[1]
		var fg = d[2]
		var bg = d[3]
		var ox = i * TILE_SZ

		# 背景填充
		for y in range(TILE_SZ):
			for x in range(TILE_SZ):
				_atlas_img.set_pixel(ox + x, y, bg)

		# 在瓦片中央画字符（简易像素字形）
		_draw_char(ox, ch, fg)

func _draw_char(ox: int, ch: String, fg: Color) -> void:
	# 居中绘制的像素字形定义（14×16 区域，居中于 32×32）
	var cx = 9  # 左边距（(32-14)/2）
	var cy = 8  # 上边距（(32-16)/2）
	match ch:
		"艹":
			# 草字头：两横两竖
			for x in range(2, 13):  # 上横
				_atlas_img.set_pixel(ox + cx + x, cy + 2, fg)
			for x in range(0, 14):  # 下横
				_atlas_img.set_pixel(ox + cx + x, cy + 6, fg)
			for y in range(0, 8):
				_atlas_img.set_pixel(ox + cx + 4, cy + y, fg)   # 左竖
				_atlas_img.set_pixel(ox + cx + 10, cy + y, fg)  # 右竖
		"丶":
			for y in range(2, 10):
				for x in range(4, 11):
					if abs(x - 7) + abs(y - 6) <= 4:
						_atlas_img.set_pixel(ox + cx + x, cy + y, fg)
		"十":
			for x in range(1, 13):
				_atlas_img.set_pixel(ox + cx + x, cy + 7, fg)
			for y in range(0, 15):
				_atlas_img.set_pixel(ox + cx + 7, cy + y, fg)
		"水":
			var pts = [[7,0],[7,15],[7,5],[2,12],[7,5],[12,12],
				[7,8],[3,15],[7,8],[11,15]]
			for j in range(0, pts.size(), 2):
				_line(ox + cx, cy, pts[j][0], pts[j][1], pts[j+1][0], pts[j+1][1], fg)
		"江":
			for y in range(0, 14):
				for dx in range(-2, 3):
					var py = cy + y
					if py >= 0 and py < TILE_SZ:
						_atlas_img.set_pixel(ox + cx + 3 + dx, py, fg)
			for y in range(2, 13):
				for x in range(0, 5):
					var px = ox + cx + 9 + x
					if px >= ox and px < ox + TILE_SZ:
						_atlas_img.set_pixel(px, cy + y, fg)
		"山":
			for y in range(0, 13):
				var w = int((13 - y) * 0.6)
				for x in range(-w, w + 1):
					_atlas_img.set_pixel(ox + cx + 7 + x, cy + y, fg)
			for x in range(2, 13):
				_atlas_img.set_pixel(ox + cx + x, cy + 13, fg)
		"岩":
			for y in range(0, 10):
				var w = int((10 - y) * 0.6)
				for x in range(-w, w + 1):
					_atlas_img.set_pixel(ox + cx + 7 + x, cy + y, fg)
			for x in range(1, 14):
				_atlas_img.set_pixel(ox + cx + x, cy + 9, fg)
			for y in range(9, 15):
				_atlas_img.set_pixel(ox + cx + 2, cy + y, fg)
				_atlas_img.set_pixel(ox + cx + 7, cy + y, fg)
				_atlas_img.set_pixel(ox + cx + 12, cy + y, fg)
		"土":
			for x in range(1, 14):
				_atlas_img.set_pixel(ox + cx + x, cy + 3, fg)
				_atlas_img.set_pixel(ox + cx + x, cy + 12, fg)
			for y in range(0, 15):
				_atlas_img.set_pixel(ox + cx + 7, cy + y, fg)
		"道":
			for y in range(3, 12):
				for dx in range(-2, 3):
					_atlas_img.set_pixel(ox + cx + 10 + dx, cy + y, fg)
			for x in range(0, 8):
				_atlas_img.set_pixel(ox + cx + x, cy + 7, fg)
		"木":
			for y in range(0, 15):
				_atlas_img.set_pixel(ox + cx + 7, cy + y, fg)
			for x in range(0, 15):
				_atlas_img.set_pixel(ox + cx + x, cy, fg)
			_atlas_img.set_pixel(ox + cx + 2, cy + 5, fg)
			_atlas_img.set_pixel(ox + cx + 12, cy + 5, fg)
			_atlas_img.set_pixel(ox + cx + 1, cy + 9, fg)
			_atlas_img.set_pixel(ox + cx + 13, cy + 9, fg)
		"林":
			for x in range(0, 7):
				_atlas_img.set_pixel(ox + cx + x + 1, cy + 14, fg)
				_atlas_img.set_pixel(ox + cx + x + 7, cy + 14, fg)
			for t in [[3,0],[10,0]]:
				for y in range(0, 13):
					_atlas_img.set_pixel(ox + cx + t[0], cy + y, fg)
				_atlas_img.set_pixel(ox + cx + t[0] - 3, cy + 4, fg)
				_atlas_img.set_pixel(ox + cx + t[0] + 3, cy + 4, fg)
		"舍":
			for y in range(2, 8):
				for x in range(1, 9):
					_atlas_img.set_pixel(ox + cx + x, cy + y, fg)
			var apex = [[2,0],[12,0],[7,8]]
			for y in range(0, 8):
				var left = 7 - int(float(7-y) * 0.71)
				var right = 7 + int(float(7-y) * 0.71)
				for x in range(left, right + 1):
					var py = cy + y
					if py >= 0:
						_atlas_img.set_pixel(ox + cx + x, py, fg)
		"坊":
			for y in range(4, 14):
				for dx in range(-1, 2):
					_atlas_img.set_pixel(ox + cx + 4 + dx, cy + y, fg)
			for x in range(2, 13):
				_atlas_img.set_pixel(ox + cx + x, cy + 4, fg)
			for y in range(4, 14):
				for x in range(2, 9):
					_atlas_img.set_pixel(ox + cx + 6 + x, cy + y, fg)

func _line(ox: int, cy: int, x1: int, y1: int, x2: int, y2: int, color: Color) -> void:
	var dx = abs(x2 - x1); var dy = -abs(y2 - y1)
	var sx = 1 if x1 < x2 else -1; var sy = 1 if y1 < y2 else -1
	var err = dx + dy
	var cx = x1; var cy2 = y1
	while true:
		_atlas_img.set_pixel(ox + cx, cy + cy2, color)
		if cx == x2 and cy2 == y2:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy; cx += sx
		if e2 <= dx:
			err += dx; cy2 += sy

func _is_blocked(idx: int) -> bool:
	return I_BLOCKED.has(idx)

# ---- TileSet 构建 ----
func _make_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(TILE_SZ, TILE_SZ)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)

	var tex = ImageTexture.create_from_image(_atlas_img)
	var src = TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_SZ, TILE_SZ)
	ts.add_source(src)

	for i in range(CHAR_DEFS.size()):
		var coord = Vector2i(i, 0)
		src.create_tile(coord, Vector2i(1, 1))
		if _is_blocked(i):
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
	var heights = _build_heights()
	var tree_map = _build_tree_map()
	var paths = _build_paths()

	for y in range(MAP_H):
		for x in range(MAP_W):
			set_cell(Vector2i(x, y), 0, Vector2i(_pick(x, y, heights[y][x], tree_map[y][x], paths), 0))

func _build_heights() -> Array:
	var m = [];
	for y in range(MAP_H):
		var r = [];
		for x in range(MAP_W):
			r.append(_fbm(x, y, 3))
		m.append(r)
	return m

func _build_tree_map() -> Array:
	var m = [];
	for y in range(MAP_H):
		var r = [];
		for x in range(MAP_W):
			r.append(_hash(x * 3 + 300, y * 3 + 300))
		m.append(r)
	return m

func _build_paths() -> Dictionary:
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

func _pick(x: int, y: int, h: float, tn: float, paths: Dictionary) -> int:
	var pos = Vector2i(x, y)

	if x <= 1 or x >= MAP_W - 2 or y <= 1 or y >= MAP_H - 2:
		return _rand(I_MOUNT)

	if has_village:
		var vc = village_center
		var dx = x - vc.x; var dy = y - vc.y
		if abs(dx) <= 8 and abs(dy) <= 6:
			if abs(dx) >= 5 and abs(dy) >= 3 and (dx + 30) % 7 >= 3:
				return _rand(I_BLDG)
			if paths.has(pos) or _rng.randf() < 0.6:
				return _rand(I_DIRT)
			return _rand(I_GRASS)
		if abs(dx) <= 12 and abs(dy) <= 10:
			if paths.has(pos):
				return _rand(I_DIRT)

	if paths.has(pos):
		return _rand(I_DIRT)

	if h < water_level:
		return _rand(I_WATER)
	elif h < water_level + 0.1:
		return _rand(I_DIRT)
	elif h < mountain_level:
		if tn > 0.78 and h < mountain_level - 0.15:
			return _rand(I_TREE)
		if h > mountain_level - 0.08:
			return _rand(I_MOUNT if _rng.randf() < 0.4 else I_GRASS)
		return _rand(I_GRASS if _rng.randf() < 0.7 else I_DIRT)
	else:
		return _rand(I_MOUNT)

func _rand(arr: Array) -> int:
	return arr[_rng.randi() % arr.size()]

func _setup_camera_bounds() -> void:
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("set_map_bounds"):
		cam.set_map_bounds(Rect2(0, 0, MAP_W * TILE_SZ, MAP_H * TILE_SZ))
