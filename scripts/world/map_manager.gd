# MapManager.gd
# 地图渲染管理器：程序化创建 TileSet 并绘制地图
class_name MapManager
extends TileMapLayer

# ---- 瓦片枚举 ----
enum TileType { GRASS, DIRT, WATER, MOUNTAIN, TREE, BUILDING }

const TILE_SIZE: int = 32

# 0: grass, 1: dirt, 2: water, 3: mountain, 4: tree, 5: building
const BLOCKED_TILES: Array = [2, 3, 4, 5]

var _tile_set: TileSet = null

func _ready() -> void:
	_tile_set = _create_tileset()
	tile_set = _tile_set
	_draw_map()
	_setup_camera_bounds()

func _create_tileset() -> TileSet:
	var ts = TileSet.new()
	var tex = preload("res://assets/tilesets/tileset_placeholder.png")
	if not tex:
		return ts

	# 添加物理层
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)

	# 创建 Atlas 源
	var source = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_source(source, 0)

	# 为每个瓦片创建 TileData
	for i in range(6):
		var coords = Vector2i(i, 0)
		source.create_tile(coords, Vector2i(1, 1))
		var td = source.get_tile_data(coords, 0)
		if not td:
			continue


		# 不可通行瓦片添加碰撞多边形
		if i in BLOCKED_TILES:
			td.add_collision_polygon(0)
			var points = PackedVector2Array([
				Vector2(0, 0),
				Vector2(TILE_SIZE, 0),
				Vector2(TILE_SIZE, TILE_SIZE),
				Vector2(0, TILE_SIZE)
			])
			td.set_collision_polygon_points(0, 0, points)

	return ts

func _draw_map() -> void:
	clear()
	var data = _generate_map_data()
	for y in range(data.size()):
		var row = data[y]
		for x in range(row.size()):
			var tile_idx = row[x]
			set_cell(Vector2i(x, y), 0, Vector2i(tile_idx, 0))

func _generate_map_data() -> Array:
	# 40x30 洛阳郊外地图
	# 0:grass 1:dirt 2:water 3:mountain 4:tree 5:building
	var w = 40
	var h = 30
	var map = []

	for y in range(h):
		var row = []
		for x in range(w):
			var tile = 0  # 默认草地

			# 边界山脉
			if y == 0 or y == h - 1 or x == 0 or x == w - 1:
				tile = TileType.MOUNTAIN
			# 左上区域树林
			elif y >= 4 and y <= 7 and x >= 4 and x <= 7:
				tile = TileType.TREE
			# 中央水域 (池塘)
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
			# 小路 (从左上到右下)
			elif y >= 2 and x >= 10 and x <= 12 and y <= 8:
				tile = TileType.DIRT
			elif y >= 8 and x >= 12 and x <= 14 and y <= 12:
				tile = TileType.DIRT
			elif y >= 12 and x >= 14 and x <= 16 and y <= 16:
				tile = TileType.DIRT
			# 零星树木 (装饰)
			elif (x == 10 and y == 5) or (x == 22 and y == 4) or (x == 30 and y == 8) \
					or (x == 6 and y == 15) or (x == 34 and y == 12) or (x == 8 and y == 22) \
					or (x == 28 and y == 20) or (x == 15 and y == 25) or (x == 35 and y == 5):
				tile = TileType.TREE

			row.append(tile)
		map.append(row)

	return map

func _setup_camera_bounds() -> void:
	var map_w = 40 * TILE_SIZE
	var map_h = 30 * TILE_SIZE
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("set_map_bounds"):
		cam.set_map_bounds(Rect2(0, 0, map_w, map_h))
