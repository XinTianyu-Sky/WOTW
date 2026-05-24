# GridMapUI.gd
# 网格地图绘制 + 鼠标交互
extends Control

const CELL_W: int = 78
const CELL_H: int = 56
const CELL_GAP: int = 2
const GRID_COLS: int = 12
const GRID_ROWS: int = 10

var current_cell: Vector2i = Vector2i(5, 5)
var visited: Array = []
var adjacent: Array[Vector2i] = []
var cell_names: Dictionary = {}

var _grid_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	EventBus.grid_cell_entered.connect(_on_cell_entered)
	resized.connect(queue_redraw)

func _on_cell_entered(cell: Vector2i, _cell_data: Dictionary) -> void:
	current_cell = cell
	adjacent = DataManager.get_adjacent_locations(GameManager.player_grid_region, cell)
	queue_redraw()

func set_cell_names(names: Dictionary) -> void:
	cell_names = names
	queue_redraw()

func set_visited(cells: Array) -> void:
	visited = cells
	queue_redraw()

func _cell_state(cell: Vector2i) -> int:
	if cell == current_cell:
		return 0  # current
	for a in adjacent:
		if a == cell:
			return 1  # adjacent
	var key = "%d,%d" % [cell.x, cell.y]
	for v in visited:
		if v is String and v == key:
			return 2  # explored
		if v is Vector2i and v == cell:
			return 2
	return 3  # unexplored

func _draw() -> void:
	var total_w = GRID_COLS * (CELL_W + CELL_GAP) - CELL_GAP
	var total_h = GRID_ROWS * (CELL_H + CELL_GAP) - CELL_GAP
	_grid_offset = Vector2((size.x - total_w) / 2.0, (size.y - total_h) / 2.0)

	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var cell = Vector2i(x, y)
			var state = _cell_state(cell)
			var rect = _cell_rect(cell)
			_draw_cell(rect, cell, state)

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		_grid_offset.x + cell.x * (CELL_W + CELL_GAP),
		_grid_offset.y + cell.y * (CELL_H + CELL_GAP),
		CELL_W, CELL_H
	)

func _draw_cell(rect: Rect2, cell: Vector2i, state: int) -> void:
	var bg: Color
	var border: Color
	var border_w: float

	match state:
		0:  # current
			bg = Color(0.12, 0.12, 0.18, 0.9)
			border = Color(0.9, 0.75, 0.2)
			border_w = 2.0
		1:  # adjacent
			bg = Color(0.08, 0.10, 0.16, 0.6)
			border = Color(0.0, 0.85, 0.85)
			border_w = 2.0
		2:  # explored
			bg = Color(0.06, 0.06, 0.10, 0.55)
			border = Color(0.3, 0.3, 0.35)
			border_w = 1.0
		_:  # unexplored
			bg = Color(0.04, 0.04, 0.07, 0.4)
			border = Color(0.25, 0.25, 0.28)
			border_w = 1.0

	draw_rect(rect, bg, true)
	draw_rect(rect, border, false, border_w)

	var key = "%d,%d" % [cell.x, cell.y]
	var name = cell_names.get(key, "")
	if not name.is_empty():
		var font = ThemeDB.fallback_font
		var font_size = 12
		var color = Color(0.8, 0.8, 0.75) if state <= 1 else Color(0.5, 0.5, 0.5)
		var pos = rect.position + rect.size * 0.5 - Vector2(font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x / 2.0, font_size / 2.0)
		draw_string(font, pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = event.position
		for y in range(GRID_ROWS):
			for x in range(GRID_COLS):
				var cell = Vector2i(x, y)
				if _cell_rect(cell).has_point(local_pos):
					EventBus.grid_cell_clicked.emit(cell)
					return
