class_name ArenaHud extends Control

signal layout_changed(left: float, right: float, top: float)

const TOP_SPACE := 54.0
const RAIL_INSET := 8.0
const BOARD_GAP := 14.0
const CARDS_PER_SIDE := 4

var _left := VBoxContainer.new()
var _right := VBoxContainer.new()
var _header := HBoxContainer.new()
var _heading := Label.new()
var _rail_width := 0.0
var _card_height := 0.0
var _pause: Callable


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Player positions on the HUD are physical sides of the board.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	theme = RetroUi.theme_resource()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for rail: VBoxContainer in [_left, _right]:
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.add_theme_constant_override("separation", 9)
		add_child(rail)
		rail.set_anchor(SIDE_BOTTOM, 1.0)
		rail.offset_top = RAIL_INSET
		rail.offset_bottom = -RAIL_INSET

	add_child(_header)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.layout_direction = Control.LAYOUT_DIRECTION_LOCALE
	_header.add_theme_constant_override("separation", 10)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_override("font", RetroUi.display_font())
	_heading.add_theme_font_size_override("font_size", 24)
	_heading.add_theme_color_override("font_color", RetroUi.PAPER)
	_heading.add_theme_color_override("font_outline_color", RetroUi.INK)
	_heading.add_theme_constant_override("outline_size", 9)
	_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header.add_child(_heading)

	var pause := MenuPanel.create_button(tr("PAUSE"), _pause, true)
	pause.focus_mode = Control.FOCUS_NONE
	_header.add_child(pause)

	resized.connect(_fit_rails)
	_fit_rails()


func add_fighter(player_slot: int, role: int, difficulty := -1) -> FighterCard:
	var card := FighterCard.new()
	card.player_slot = player_slot
	card.role = role
	card.difficulty = difficulty
	var rail := _left if _left.get_child_count() < CARDS_PER_SIDE else _right
	rail.add_child(card)
	_fit_rails()
	return card


func show_round(text: String) -> void:
	_heading.text = text


func place_around_board(board: Rect2) -> void:
	var left_edge := maxf(RAIL_INSET, board.position.x - _rail_width - BOARD_GAP)
	var right_edge := minf(size.x - _rail_width - RAIL_INSET, board.end.x + BOARD_GAP)
	_left.offset_left = left_edge
	_left.offset_right = left_edge + _rail_width
	_right.offset_left = right_edge
	_right.offset_right = right_edge + _rail_width
	_header.position = Vector2(board.position.x, RAIL_INSET)
	_header.size = Vector2(board.size.x, TOP_SPACE - RAIL_INSET * 2.0)


func _fit_rails() -> void:
	_card_height = maxf(0.0, (size.y - RAIL_INSET * 2.0 - 27.0) / CARDS_PER_SIDE)
	for rail: VBoxContainer in [_left, _right]:
		for card: FighterCard in rail.get_children():
			card.custom_minimum_size.y = _card_height
			card.fit_height(_card_height)
	var sides := 2 if _right.get_child_count() > 0 else 1
	_rail_width = clampf(size.x * (0.20 if sides == 2 else 0.24), 155.0, 314.0)
	var reserve := _rail_width + RAIL_INSET + BOARD_GAP
	var left := reserve if _left.get_child_count() > 0 else 0.0
	var right := reserve if sides == 2 else 0.0
	layout_changed.emit(left, right, TOP_SPACE)
