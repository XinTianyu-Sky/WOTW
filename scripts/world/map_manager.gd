# MapManager.gd
# 地图渲染管理器：噪声高度场驱动地形，程序化 TileSet
class_name MapManager
extends TileMapLayer

enum TileType {
	GRASS_1, GRASS_2, GRASS_FLOWER, DIRT,
	WATER, MOUNTAIN, TREE, BUILDING
}

const TILE_SIZE: int = 32
const BLOCKED_TILES: Array = [TileType.WATER, TileType.MOUNTAIN, TileType.TREE, TileType.BUILDING]
const MAP_W: int = 40
const MAP_H: int = 30

var _tile_set: TileSet = null
var _rng = RandomNumberGenerator.new()

@export var map_seed: int = 42
@export var has_village: bool = false
@export var village_center: Vector2i = Vector2i(20, 20)

func _ready() -> void:
	_rng.seed = map_seed
	_tile_set = _create_tileset()
	tile_set = _tile_set
	_draw_map()
	_setup_camera_bounds()

# ---- TileSet 构建 ----
func _create_tileset() -> TileSet:
	var ts = TileSet.new()
	var tex = _generate_tileset_texture()
	if not tex:
		return ts

	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)

	var source = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_source(source, 0)

	for i in range(8):
		var coords = Vector2i(i, 0)
		source.create_tile(coords, Vector2i(1, 1))
		var td = source.get_tile_data(coords, 0)
		if not td:
			continue
		if i in BLOCKED_TILES:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(0, 0), Vector2(TILE_SIZE, 0),
				Vector2(TILE_SIZE, TILE_SIZE), Vector2(0, TILE_SIZE)
			]))

	return ts

# ---- 程序化纹理 ----
func _generate_tileset_texture() -> ImageTexture:
	var img = Image.create(8 * TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	_fill_grass(img, TileType.GRASS_1, Color(0.28, 0.42, 0.18))
	_fill_grass(img, TileType.GRASS_2, Color(0.34, 0.50, 0.24))
	_fill_grass_flower(img, TileType.GRASS_FLOWER)
	_fill_dirt(img, TileType.DIRT)
	_fill_water(img, TileType.WATER)
	_fill_mountain(img, TileType.MOUNTAIN)
	_fill_tree(img, TileType.TREE)
	_fill_building(img, TileType.BUILDING)
	return ImageTexture.create_from_image(img)

func _fill_grass(img: Image, idx: int, base: Color) -> void:
	var ox = idx * TILE_SIZE
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var n = _hash_noise(ox + x, y) * 0.07
			# 草叶纹理：细竖线微调
			var blade = 0.0
			if x % 5 < 2:
				blade = 0.03
			var c = base
			c.r = clamp(c.r + n + blade * 0.3, 0, 1)
			c.g = clamp(c.g + n + blade, 0, 1)
			c.b = clamp(c.b + n * 0.5, 0, 1)
			img.set_pixel(ox + x, y, c)

func _fill_grass_flower(img: Image, idx: int) -> void:
	var base = Color(0.30, 0.46, 0.20)
	_fill_grass(img, idx, base)
	var ox = idx * TILE_SIZE
	# 散布小花
	var flower_colors = [Color(1, 0.85, 0.2), Color(0.95, 0.45, 0.65), Color(1, 1, 0.7), Color(0.65, 0.55, 1)]
	for _i in range(10):
		var fx = _rng.randi_range(4, 27)
		var fy = _rng.randi_range(4, 27)
		var fc = flower_colors[_rng.randi() % flower_colors.size()]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if abs(dx) + abs(dy) <= 1:
					var px = ox + fx + dx
					var py = fy + dy
					if px >= ox and px < ox + TILE_SIZE and py >= 0 and py < TILE_SIZE:
						img.set_pixel(px, py, fc)

func _fill_dirt(img: Image, idx: int) -> void:
	var ox = idx * TILE_SIZE
	var base = Color(0.48, 0.35, 0.22)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var n = _hash_noise(ox + x + 50, y + 50) * 0.09
			# 碎石颗粒
			var grain = _hash_noise(ox + x * 3, y * 3 + 20) * 0.04
			var c = base
			c.r = clamp(c.r + n + grain, 0, 1)
			c.g = clamp(c.g + n * 0.8 + grain, 0, 1)
			c.b = clamp(c.b + n * 0.4, 0, 1)
			img.set_pixel(ox + x, y, c)

func _fill_water(img: Image, idx: int) -> void:
	var ox = idx * TILE_SIZE
	var deep = Color(0.08, 0.18, 0.36)
	var shallow = Color(0.18, 0.35, 0.55)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var t = (sin(x * 0.5 + y * 0.35) + 1) * 0.5
			var n = _hash_noise(ox + x + 70, y + 70) * 0.06
			var c = deep.lerp(shallow, t)
			c.r = clamp(c.r + n, 0, 1)
			c.g = clamp(c.g + n * 0.8, 0, 1)
			c.b = clamp(c.b + n * 0.6, 0, 1)
			# 波光
			if (x + y * 3 + int(sin(x * 0.8 + y * 0.7) * 3)) % 13 == 0:
				c = c.lightened(0.12)
			img.set_pixel(ox + x, y, c)

func _fill_mountain(img: Image, idx: int) -> void:
	var ox = idx * TILE_SIZE
	var rock = Color(0.35, 0.30, 0.28)
	var highlight = Color(0.50, 0.45, 0.40)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var n = _hash_noise(ox + x + 90, y + 90) * 0.12
			# 棱角感：菱形高光
			var ridge = 1.0 - abs(float(x - 16) + float(y - 16)) / 32.0
			ridge = clamp(ridge, 0.0, 1.0)
			var c = rock.lerp(highlight, ridge * 0.5)
			c.r = clamp(c.r + n, 0, 1)
			c.g = clamp(c.g + n * 0.7, 0, 1)
			c.b = clamp(c.b + n * 0.4, 0, 1)
			# 顶部积雪
			if y < 6 and ridge > 0.4:
				c = c.lerp(Color(0.85, 0.85, 0.9), (6 - y) / 6.0 * ridge)
			img.set_pixel(ox + x, y, c)

func _fill_tree(img: Image, idx: int) -> void:
	var ox = idx * TILE_SIZE
	var canopy = Color(0.12, 0.25, 0.08)
	var highlight_c = Color(0.22, 0.38, 0.14)
	var trunk = Color(0.35, 0.2, 0.1)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var cx, cy: float
			if y < 8:
				cx = 15.5; cy = 16.0
			else:
				cx = 15.5; cy = 14.0
			var dist = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
			var c: Color
			if y >= 22 and x >= 13 and x <= 18:
				c = trunk
			elif dist < 13:
				var n = _hash_noise(ox + x + 110, y + 110) * 0.08
				c = canopy.lerp(highlight_c, 1.0 - dist / 14.0)
				c.g = clamp(c.g + n, 0, 1)
			else:
				c = Color(0, 0, 0, 0)
			img.set_pixel(ox + x, y, c)

func _fill_building(img: Image, idx: int) -> void:
	var ox = idx * TILE_SIZE
	var roof_c = Color(0.4, 0.15, 0.08)
	var wall_c = Color(0.6, 0.45, 0.3)
	var window_c = Color(0.1, 0.08, 0.04)
	var door_c = Color(0.25, 0.15, 0.08)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var c: Color
			var n = _hash_noise(ox + x + 130, y + 130) * 0.04
			if y < 9:
				c = roof_c
				# 瓦片纹路
				if y % 4 < 2 and x % 6 < 3:
					c = c.darkened(0.08)
			else:
				c = wall_c
				# 砖缝
				if y % 6 == 0 or x % 8 == 0:
					c = c.darkened(0.06)
			c.r = clamp(c.r + n, 0, 1)
			c.g = clamp(c.g + n, 0, 1)
			img.set_pixel(ox + x, y, c)
	# 窗户
	for wy in [13, 19]:
		for wx in [5, 21]:
			for dy in range(4):
				for dx in range(4):
					img.set_pixel(ox + wx + dx, wy + dy, window_c)
	# 门
	for dy in range(6):
		for dx in range(4):
			img.set_pixel(ox + 14 + dx, 20 + dy, door_c)

# ---- 噪声 ----
func _hash_noise(x: int, y: int) -> float:
	var v = (x * 1619 + y * 31337) & 0x7fffffff
	v = (v >> 13) ^ v
	v = (v * (v * v * 60493 + 19990303) + 1376312589) & 0x7fffffff
	return (float(v % 1000) / 500.0) - 1.0

func _fbm(x: int, y: int, octaves: int = 3) -> float:
	var v = 0.0
	var amp = 0.6
	var total = 0.0
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
	var path_set = _build_path_set()
	for y in range(MAP_H):
		for x in range(MAP_W):
			var tile = _classify_tile(x, y, height_map[y][x], path_set)
			set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))

func _build_height_map() -> Array:
	var map = []
	for y in range(MAP_H):
		var row = []
		for x in range(MAP_W):
			row.append(_fbm(x, y, 3))
		map.append(row)
	return map

func _build_path_set() -> Dictionary:
	var paths = {}
	if not has_village:
		return paths
	var vc = village_center
	# 从村庄向四方的土路
	for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var cur = vc
		for _step in range(35):
			cur += dir
			if cur.x < 2 or cur.x >= MAP_W - 2 or cur.y < 2 or cur.y >= MAP_H - 2:
				break
			# 略微随机摆动
			var wobble = Vector2i(0, 0)
			if dir.x == 0:
				wobble.x = int(_hash_noise(cur.x, cur.y + map_seed) * 2.5)
			else:
				wobble.y = int(_hash_noise(cur.x + map_seed, cur.y) * 2.5)
			var p = cur + wobble
			if p.x >= 0 and p.x < MAP_W and p.y >= 0 and p.y < MAP_H:
				paths[Vector2i(p.x, p.y)] = true
	return paths

func _classify_tile(x: int, y: int, height: float, paths: Dictionary) -> int:
	var pos = Vector2i(x, y)

	# 边界强制山脉
	if x <= 1 or x >= MAP_W - 2 or y <= 1 or y >= MAP_H - 2:
		return TileType.MOUNTAIN

	# 村庄区域
	if has_village:
		var vc = village_center
		# 村庄建筑
		if abs(x - vc.x) <= 4 and abs(y - vc.y) <= 3:
			# 建筑群
			if (x - vc.x + 10) % 5 >= 2 and (y - vc.y + 10) % 4 >= 1:
				return TileType.BUILDING
			return TileType.DIRT
		# 村庄周边清理区
		if abs(x - vc.x) <= 6 and abs(y - vc.y) <= 5:
			if paths.has(pos):
				return TileType.DIRT
			return _pick_grass()

	# 道路
	if paths.has(pos):
		return TileType.DIRT

	# 高度 → 地形
	if height < -0.32:
		return TileType.WATER
	elif height < -0.08:
		return TileType.DIRT
	elif height < 0.15:
		return TileType.GRASS_2
	elif height < 0.42:
		return TileType.GRASS_1
	elif height < 0.58:
		# 高地散树
		var tree_noise = _hash_noise(x * 3 + 300, y * 3 + 300)
		if tree_noise > 0.55:
			return TileType.TREE
		return TileType.GRASS_FLOWER
	else:
		return TileType.MOUNTAIN

func _pick_grass() -> int:
	var r = _rng.randf()
	if r < 0.70: return TileType.GRASS_1
	if r < 0.90: return TileType.GRASS_2
	return TileType.GRASS_FLOWER

func _setup_camera_bounds() -> void:
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("set_map_bounds"):
		cam.set_map_bounds(Rect2(0, 0, MAP_W * TILE_SIZE, MAP_H * TILE_SIZE))
