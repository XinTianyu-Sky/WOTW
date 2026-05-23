# MapManager.gd
# 地图渲染管理器：程序化生成 TileSet 并绘制地图
class_name MapManager
extends TileMapLayer

# ---- 瓦片枚举 ----
enum TileType {
	GRASS_1, GRASS_2, GRASS_FLOWER, DIRT,
	WATER, MOUNTAIN, TREE, BUILDING
}

const TILE_SIZE: int = 32
const BLOCKED_TILES: Array = [TileType.WATER, TileType.MOUNTAIN, TileType.TREE, TileType.BUILDING]

var _tile_set: TileSet = null
var _rng = RandomNumberGenerator.new()

@export var map_seed: int = 42

func _ready() -> void:
	_rng.seed = map_seed
	_tile_set = _create_tileset()
	tile_set = _tile_set
	_draw_map()
	_setup_camera_bounds()

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
			var points = PackedVector2Array([
				Vector2(0, 0), Vector2(TILE_SIZE, 0),
				Vector2(TILE_SIZE, TILE_SIZE), Vector2(0, TILE_SIZE)
			])
			td.set_collision_polygon_points(0, 0, points)

	return ts

func _generate_tileset_texture() -> ImageTexture:
	var img = Image.create(8 * TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)

	for i in range(8):
		match i:
			TileType.GRASS_1:       _fill_tile(img, i, Color(0.32, 0.48, 0.22))
			TileType.GRASS_2:       _fill_tile(img, i, Color(0.38, 0.55, 0.28))
			TileType.GRASS_FLOWER:  _fill_flower_tile(img, i)
			TileType.DIRT:          _fill_tile(img, i, Color(0.5, 0.38, 0.25))
			TileType.WATER:         _fill_water_tile(img, i)
			TileType.MOUNTAIN:      _fill_mountain_tile(img, i)
			TileType.TREE:          _fill_tree_tile(img, i)
			TileType.BUILDING:      _fill_building_tile(img, i)

	var tex = ImageTexture.create_from_image(img)
	return tex

func _fill_tile(img: Image, tile_idx: int, base_color: Color) -> void:
	var ox = tile_idx * TILE_SIZE
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var n = _noise2d(ox + x, y) * 0.08
			var c = base_color
			c.r = clamp(c.r + n, 0.0, 1.0)
			c.g = clamp(c.g + n, 0.0, 1.0)
			c.b = clamp(c.b + n, 0.0, 1.0)
			img.set_pixel(ox + x, y, c)

func _fill_water_tile(img: Image, tile_idx: int) -> void:
	var ox = tile_idx * TILE_SIZE
	var base = Color(0.12, 0.28, 0.45)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var n = _noise2d(ox + x, y + 3) * 0.1
			# subtle wave pattern
			var wave = sin((ox + x) * 0.4 + y * 0.3) * 0.04
			var c = base
			c.r = clamp(c.r + n + wave, 0.0, 1.0)
			c.g = clamp(c.g + n + wave * 0.7, 0.0, 1.0)
			c.b = clamp(c.b + n + wave * 1.5, 0.0, 1.0)
			img.set_pixel(ox + x, y, c)

func _fill_flower_tile(img: Image, tile_idx: int) -> void:
	var ox = tile_idx * TILE_SIZE
	var base = Color(0.35, 0.52, 0.25)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var n = _noise2d(ox + x, y) * 0.06
			var c = base
			c.r = clamp(c.r + n, 0.0, 1.0)
			c.g = clamp(c.g + n, 0.0, 1.0)
			c.b = clamp(c.b + n, 0.0, 1.0)
			img.set_pixel(ox + x, y, c)
	# scatter small flower dots
	for _i in range(8):
		var fx = _rng.randi_range(3, 28)
		var fy = _rng.randi_range(3, 28)
		var flower_colors = [Color(1, 0.85, 0.3), Color(0.95, 0.5, 0.7), Color(1, 1, 0.8), Color(0.7, 0.6, 1)]
		var fc = flower_colors[_rng.randi() % flower_colors.size()]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if abs(dx) + abs(dy) <= 1:
					var px = ox + fx + dx
					var py = fy + dy
					if px >= ox and px < ox + TILE_SIZE and py >= 0 and py < TILE_SIZE:
						img.set_pixel(px, py, fc)

func _fill_mountain_tile(img: Image, tile_idx: int) -> void:
	var ox = tile_idx * TILE_SIZE
	var base = Color(0.4, 0.35, 0.3)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var n = _noise2d(ox + x + 10, y + 10) * 0.15
			var c = base
			c.r = clamp(c.r + n, 0.0, 1.0)
			c.g = clamp(c.g + n * 0.8, 0.0, 1.0)
			c.b = clamp(c.b + n * 0.5, 0.0, 1.0)
			# darker edges for rocky feel
			if x < 3 or x > 28 or y < 3 or y > 28:
				c.r -= 0.1; c.g -= 0.1; c.b -= 0.1
			img.set_pixel(ox + x, y, c)

func _fill_tree_tile(img: Image, tile_idx: int) -> void:
	var ox = tile_idx * TILE_SIZE
	var base = Color(0.18, 0.3, 0.12)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var n = _noise2d(ox + x + 20, y + 20) * 0.12
			var c = base
			c.r = clamp(c.r + n * 0.5, 0.0, 1.0)
			c.g = clamp(c.g + n, 0.0, 1.0)
			c.b = clamp(c.b + n * 0.3, 0.0, 1.0)
			# circular canopy feel
			var cx = 15.5; var cy = 15.5
			var dist = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
			if dist < 14:
				c.g += 0.06
			if dist > 16:
				c = c.darkened(0.3)
			img.set_pixel(ox + x, y, c)

func _fill_building_tile(img: Image, tile_idx: int) -> void:
	var ox = tile_idx * TILE_SIZE
	var roof = Color(0.35, 0.18, 0.1)
	var wall = Color(0.55, 0.4, 0.25)
	var window_c = Color(0.15, 0.1, 0.05)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var c: Color
			if y < 10:  # roof
				c = roof
				var n = _noise2d(ox + x + 30, y + 30) * 0.06
				c.r = clamp(c.r + n, 0.0, 1.0)
			else:  # wall
				c = wall
				var n = _noise2d(ox + x + 30, y + 30) * 0.05
				c.r = clamp(c.r + n, 0.0, 1.0)
				c.g = clamp(c.g + n, 0.0, 1.0)
			img.set_pixel(ox + x, y, c)
	# window
	for wy in range(14, 22):
		for wx in range(10, 20):
			img.set_pixel(ox + wx, wy, window_c)

func _noise2d(x: int, y: int) -> float:
	var v = (x * 1619 + y * 31337) & 0x7fffffff
	v = (v >> 13) ^ v
	v = (v * (v * v * 60493 + 19990303) + 1376312589) & 0x7fffffff
	return (float(v % 1000) / 500.0) - 1.0

func _draw_map() -> void:
	clear()
	var data = _generate_map_data()
	for y in range(data.size()):
		var row = data[y]
		for x in range(row.size()):
			var tile_idx = row[x]
			set_cell(Vector2i(x, y), 0, Vector2i(tile_idx, 0))

func _generate_map_data() -> Array:
	var w = 40
	var h = 30
	var map = []

	for y in range(h):
		var row = []
		for x in range(w):
			var tile = _pick_grass()  # 默认随机草地

			# 边界山脉
			if y == 0 or y == h - 1 or x == 0 or x == w - 1:
				tile = TileType.MOUNTAIN
			# 左上树林
			elif y >= 4 and y <= 7 and x >= 4 and x <= 7:
				tile = TileType.TREE
			# 中央池塘
			elif y >= 8 and y <= 11 and x >= 18 and x <= 24:
				tile = TileType.WATER
			# 右下小树林
			elif y >= 12 and y <= 14 and x >= 28 and x <= 30:
				tile = TileType.TREE
			elif y >= 13 and y <= 14 and x >= 25 and x <= 27:
				tile = TileType.TREE
			# 房屋
			elif y >= 18 and y <= 21 and x >= 18 and x <= 21:
				tile = TileType.BUILDING
			# 小路
			elif y >= 2 and x >= 10 and x <= 12 and y <= 8:
				tile = TileType.DIRT
			elif y >= 8 and x >= 12 and x <= 14 and y <= 12:
				tile = TileType.DIRT
			elif y >= 12 and x >= 14 and x <= 16 and y <= 16:
				tile = TileType.DIRT
			# 零星树木
			elif (x == 10 and y == 5) or (x == 22 and y == 4) or (x == 30 and y == 8) \
					or (x == 6 and y == 15) or (x == 34 and y == 12) or (x == 8 and y == 22) \
					or (x == 28 and y == 20) or (x == 15 and y == 25) or (x == 35 and y == 5):
				tile = TileType.TREE

			row.append(tile)
		map.append(row)

	return map

func _pick_grass() -> int:
	var r = _rng.randf()
	if r < 0.75:   return TileType.GRASS_1
	if r < 0.92:   return TileType.GRASS_2
	return TileType.GRASS_FLOWER

func _setup_camera_bounds() -> void:
	var map_w = 40 * TILE_SIZE
	var map_h = 30 * TILE_SIZE
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("set_map_bounds"):
		cam.set_map_bounds(Rect2(0, 0, map_w, map_h))
