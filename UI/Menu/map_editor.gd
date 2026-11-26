extends VBoxContainer

signal playtest(dimension: int, tiles: PackedInt32Array)
signal draft_changed(dimension: int, tiles: PackedInt32Array)

const BOARD := preload("res://maze/painted_map.gd")
const PAINT_GRID := preload("res://UI/Menu/map_paint_grid.gd")
const LABELS := ["MAP_VOID", "MAP_FLOOR"]

var dimension := 9
var tiles := PackedInt32Array()
var _brush := BOARD.Tile.FLOOR
var _grid := PAINT_GRID.new()
var _status := Label.new()
var _size := SpinBox.new()
var _slot := OptionButton.new()
var _play: Button


func _ready() -> void:
	var workspace := HBoxContainer.new()
	workspace.add_theme_constant_override("separation", 14)
	add_child(workspace)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.painted.connect(_paint)
	workspace.add_child(_grid)
	var toolbar := VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 3)
	toolbar.custom_minimum_size.x = 268.0
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	workspace.add_child(toolbar)
	var brush := OptionButton.new()
	for key in LABELS:
		brush.add_item(tr(key))
	brush.select(_brush)
	brush.item_selected.connect(func(index: int): _brush = index)
	toolbar.add_child(brush)
	_compact_button(brush)
	_size.get_line_edit().add_theme_font_size_override("font_size", 16)
	_size.min_value = BOARD.MIN_SIZE
	_size.max_value = BOARD.MAX_SIZE
	_size.value = dimension
	_size.tooltip_text = tr("MAP_SIZE")
	_size.value_changed.connect(_resize_map)
	var dimensions := HBoxContainer.new()
	toolbar.add_child(dimensions)
	dimensions.add_child(_size)
	var fill := MenuPanel.create_button(tr("MAP_FILL"), _fill, true)
	_compact_button(fill)
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dimensions.add_child(fill)
	for i in range(3):
		_slot.add_item(tr("MAP_SLOT") % (i + 1))
	toolbar.add_child(_slot)
	_compact_button(_slot)
	var storage := HBoxContainer.new()
	toolbar.add_child(storage)
	for button: Button in [MenuPanel.create_button(tr("MAP_SAVE"), _save, true), MenuPanel.create_button(tr("MAP_LOAD"), _load, true)]:
		_compact_button(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		storage.add_child(button)
	_play = MenuPanel.create_button(tr("MAP_PLAYTEST"), func(): playtest.emit(dimension, tiles.duplicate()), true)
	_compact_button(_play)
	toolbar.add_child(_play)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	toolbar.add_child(_status)
	if tiles.is_empty():
		_fill()
	else:
		_refresh()


func preferred_width(view_width: float) -> float:
	return clampf(view_width - 90.0, 470.0, 820.0)


func fit_height(available: float) -> void:
	_grid.custom_minimum_size.y = clampf(available - 300.0, 155.0, 430.0)


func _compact_button(button: Button) -> void:
	button.custom_minimum_size.y = 29.0
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := RetroUi.theme_resource().get_stylebox(state, "Button").duplicate() as StyleBoxFlat
		style.content_margin_top = 1.0
		style.content_margin_bottom = 1.0
		style.content_margin_left = 7.0
		style.content_margin_right = 7.0
		button.add_theme_stylebox_override(state, style)


func focus_grid() -> void:
	_grid.grab_focus()


func _paint(cell: Vector2i) -> void:
	var index := cell.y * dimension + cell.x
	if tiles[index] == _brush:
		_grid.queue_redraw()
		return
	tiles[index] = _brush
	_refresh()


func _fill() -> void:
	tiles.resize(dimension * dimension)
	tiles.fill(_brush)
	_refresh()


func _resize_map(value: float) -> void:
	var next_size := int(value)
	var next := PackedInt32Array()
	next.resize(next_size * next_size)
	for y in range(mini(dimension, next_size)):
		for x in range(mini(dimension, next_size)):
			next[y * next_size + x] = tiles[y * dimension + x]
	dimension = next_size
	tiles = next
	_refresh()


func _refresh() -> void:
	_grid.dimension = dimension
	_grid.tiles = tiles
	_grid.cursor = _grid.cursor.clamp(Vector2i.ZERO, Vector2i.ONE * (dimension - 1))
	_grid.queue_redraw()
	_play.disabled = not BOARD.valid(dimension, tiles, 2)
	_status.text = tr("MAP_INVALID" if _play.disabled else "MAP_READY")
	draft_changed.emit(dimension, tiles.duplicate())


func _save() -> void:
	_status.text = tr("MAP_SAVED" if BOARD.save_slot(_slot.selected, dimension, tiles) == OK else "SAVE_ERR")


func _load() -> void:
	var saved := BOARD.load_slot(_slot.selected)
	if saved.is_empty():
		_status.text = tr("MAP_SLOT_EMPTY")
		return
	dimension = saved.dimension
	tiles = saved.tiles
	_size.set_value_no_signal(dimension)
	_refresh()
