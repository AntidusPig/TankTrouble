extends VBoxContainer

var rows: Array[Dictionary] = []
var sudoku := false
var winner_slot := -1
var _scroll := ScrollContainer.new()
var _stats := GridContainer.new()
var _headers := GridContainer.new()


func _ready() -> void:
	_headers.columns = 4
	_headers.add_theme_constant_override("h_separation", 5)
	add_child(_headers)
	var labels := ["RESULT_PLAYER", "RESULT_EDITS", "RESULT_SHOTS", "RESULT_CONTROLS"] if sudoku else 		["RESULT_PLAYER", "RESULT_LIVES", "RESULT_SHOTS", "RESULT_WINS"]
	for key: String in labels:
		_headers.add_child(_cell(tr(key), 17, _headers.get_child_count() == 0, true))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = Control.FOCUS_ALL
	add_child(_scroll)
	_stats.columns = 4
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.add_theme_constant_override("h_separation", 5)
	_stats.add_theme_constant_override("v_separation", 3)
	_scroll.add_child(_stats)
	for row: Dictionary in rows:
		_add_row(row)
	_align_headers(_headers)


func _add_row(row: Dictionary) -> void:
	var identity := HBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_stretch_ratio = 1.45
	var badge := PlayerBadge.new()
	badge.player_slot = row.slot
	badge.custom_minimum_size = Vector2(26, 26)
	identity.add_child(badge)
	var player := _cell(tr("PLAYER") % (row.slot + 1), 17, true)
	if row.slot == winner_slot:
		player.add_theme_color_override("font_color", RetroUi.BRICK)
	identity.add_child(player)
	_stats.add_child(identity)
	_stats.add_child(_cell(str(row.edits) if sudoku else "%d / 3" % row.lives, 17))
	_stats.add_child(_cell(str(row.shots), 17))
	_stats.add_child(_cell(row.controller if sudoku else str(row.wins), 17))


func _cell(value: String, font_size: int, leading := false, heading := false) -> Label:
	var label := Label.new()
	label.text = value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 1.45 if leading else 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if leading else HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 62
	label.add_theme_font_size_override("font_size", font_size)
	if heading:
		label.add_theme_font_override("font", RetroUi.display_font())
		label.add_theme_color_override("font_color", RetroUi.BRICK)
	return label


func _align_headers(headers: GridContainer) -> void:
	# Let the same column rules size both grids, including the width of the player badge.
	var badge_offset := 30.0
	headers.get_child(0).custom_minimum_size.x += badge_offset


func preferred_width(view_width: float) -> float:
	return clampf(view_width - 90.0, 350.0, 720.0)


func fit_rows(available: float) -> void:
	var budget := maxf(35.0, available - _headers.get_combined_minimum_size().y - get_theme_constant("separation"))
	_scroll.custom_minimum_size.y = minf(_stats.get_combined_minimum_size().y, budget)
