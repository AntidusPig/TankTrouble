extends Control

signal painted(cell: Vector2i)

const BOARD := preload("res://maze/painted_map.gd")
const DIRECTIONS := {"ui_left": Vector2i.LEFT, "ui_right": Vector2i.RIGHT, "ui_up": Vector2i.UP, "ui_down": Vector2i.DOWN}
var dimension := 9
var tiles := PackedInt32Array()
var cursor := Vector2i.ZERO
var _last_cell := Vector2i(-1, -1)


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _board_rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)


func _draw() -> void:
	var board := _board_rect()
	var side := board.size.x / dimension
	for y in range(dimension):
		for x in range(dimension):
			var rect := Rect2(board.position + Vector2(x, y) * side, Vector2.ONE * side)
			var index := y * dimension + x
			if index >= tiles.size():
				return
			draw_rect(rect.grow(-1.0), BOARD.COLORS[tiles[index]])
			if has_focus() and cursor == Vector2i(x, y):
				draw_rect(rect.grow(-2.0), Color.WHITE, false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			_paint_at(event.position)
		else:
			_last_cell = Vector2i(-1, -1)
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_paint_at(event.position)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		painted.emit(cursor)
		accept_event()
	else:
		for action: String in DIRECTIONS:
			if event.is_action_pressed(action, true, true):
				cursor = (cursor + DIRECTIONS[action]).clamp(Vector2i.ZERO, Vector2i.ONE * (dimension - 1))
				queue_redraw()
				accept_event()
				return


func _paint_at(point: Vector2) -> void:
	var board := _board_rect()
	if not board.has_point(point):
		return
	var cell := Vector2i(((point - board.position) * dimension / board.size.x).floor())
	if _last_cell.x >= 0:
		var steps := maxi(abs(cell.x - _last_cell.x), abs(cell.y - _last_cell.y))
		for i in range(1, steps):
			painted.emit(Vector2i(Vector2(_last_cell).lerp(Vector2(cell), float(i) / steps).round()))
	cursor = cell
	_last_cell = cell
	painted.emit(cell)
