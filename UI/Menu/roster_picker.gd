class_name RosterPicker extends VBoxContainer

signal roster_changed

const GAP := 7
const SHORT_LABELS := ["SHORT_PRACTICE", "SHORT_STATE", "SHORT_TREE", "GOAP", "SHORT_UTILITY", "SHORT_NEURAL", "SUDOKU_AI"]

var roles: PackedInt32Array
var game_mode := GameSession.ARENA_MODE
var map_choice := 9
var locked_size := false
var _size_picker := OptionButton.new()
var _row := HBoxContainer.new()
var _selectors: Array[Button] = []
var _badges: Array[PlayerBadge] = []
var _names: Array[Label] = []
var _add: Button


func _ready() -> void:
	var sizes := HBoxContainer.new()
	sizes.alignment = BoxContainer.ALIGNMENT_CENTER
	sizes.add_theme_constant_override("separation", 10)
	add_child(sizes)
	var label := Label.new()
	label.text = tr("PUZZLE_SIZE") if game_mode == GameSession.SUDOKU_MODE else tr("MAP_SIZE")
	sizes.add_child(label)
	_size_picker.add_item(tr("RANDOM"), 0)
	for size_value in GameSession.sizes_for(game_mode):
		_size_picker.add_item("%d × %d" % [size_value, size_value], size_value)
	for index in range(_size_picker.item_count):
		if _size_picker.get_item_id(index) == map_choice:
			_size_picker.select(index)
			break
	_size_picker.item_selected.connect(_select_size)
	_size_picker.disabled = locked_size
	sizes.add_child(_size_picker)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", GAP)
	add_child(_row)
	_refresh_row()


func _refresh_row() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_selectors.clear()
	_badges.clear()
	_names.clear()
	_add = null

	for i in range(roles.size()):
		_add_card(i)
	if _can_add():
		_add = MenuPanel.create_button("+", _add_slot)
		_add.add_theme_font_size_override("font_size", 43)
		_add.tooltip_text = tr("ADD_PLAYER") % (roles.size() + 1)
		_row.add_child(_add)
	fit_height(get_viewport_rect().size.y)


func _add_card(index: int) -> void:
	var card := PanelContainer.new()
	var frame := RetroUi.ink_box(RetroUi.CREAM, 12, 2, 2)
	frame.content_margin_left = 5
	frame.content_margin_right = 5
	frame.content_margin_top = 4
	frame.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", frame)
	_row.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var top := Control.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.custom_minimum_size.y = 22.0
	content.add_child(top)
	if roles.size() > 2:
		var remove := _create_remove_button(index)
		top.add_child(remove)
		remove.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		remove.offset_left = -23.0
		remove.offset_right = 7.0
		remove.offset_top = -8.0
		remove.offset_bottom = 22.0

	var badge := PlayerBadge.new()
	badge.player_slot = index
	badge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_badges.append(badge)
	content.add_child(badge)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", RetroUi.display_font())
	_names.append(label)
	content.add_child(label)

	var selector := MenuPanel.create_button("", _cycle.bind(index), true)
	_style_small_button(selector, 16)
	selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(selector)
	_selectors.append(selector)


func _create_remove_button(index: int) -> Button:
	var button := MenuPanel.create_button("X", _remove_slot.bind(index), true)
	button.tooltip_text = tr("REMOVE_PLAYER") % (index + 1)
	button.custom_minimum_size = Vector2(30, 30)
	button.add_theme_font_override("font", RetroUi.display_font())
	button.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, RetroUi.CREAM)
	var fills := {"normal": Color("#c84536"), "hover": Color("#e05a46"), "pressed": RetroUi.BRICK}
	for state in fills:
		var circle := RetroUi.ink_box(fills[state], 16, 2, 2 if state != "pressed" else 0)
		circle.border_color = Color("#15100e")
		circle.content_margin_left = 0
		circle.content_margin_right = 0
		circle.content_margin_top = 0
		circle.content_margin_bottom = 0
		button.add_theme_stylebox_override(state, circle)
	var focus := RetroUi.ink_box(RetroUi.CREAM, 17, 2, 0)
	focus.draw_center = false
	focus.border_color = RetroUi.CREAM
	focus.expand_margin_left = 2.0
	focus.expand_margin_right = 2.0
	focus.expand_margin_top = 2.0
	focus.expand_margin_bottom = 2.0
	button.add_theme_stylebox_override("focus", focus)
	return button


func _style_small_button(button: Button, font_size: int) -> void:
	button.add_theme_font_override("font", RetroUi.body_font())
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := RetroUi.theme_resource().get_stylebox(state, "Button").duplicate() as StyleBoxFlat
		style.content_margin_left = 3.0
		style.content_margin_right = 3.0
		style.content_margin_top = 1.0
		style.content_margin_bottom = 1.0
		button.add_theme_stylebox_override(state, style)


func _update_slot(index: int, compact: bool) -> void:
	var role := roles[index]
	var name := PlayerRoster.label_for(role)
	var short_name: String = tr(SHORT_LABELS[role]) if role >= 0 else name
	_selectors[index].text = "%s ›" % (short_name if compact else name)
	_selectors[index].tooltip_text = tr("CYCLE_PLAYER") % [name, index + 1]


func _select_size(index: int) -> void:
	map_choice = _size_picker.get_item_id(index)
	CartoonSound.play_confirm()
	roster_changed.emit()


func _can_add() -> bool:
	return roles.size() < PlayerRoster.MAX_PLAYERS and (
		game_mode != GameSession.SUDOKU_MODE or GameSession.ai_runtime_available() or roles.size() < PlayerRoster.MAX_HUMANS)


func _cycle(index: int) -> void:
	var role := roles[index]
	var humans := roles.count(PlayerRoster.HUMAN) - int(role == PlayerRoster.HUMAN)
	if game_mode == GameSession.SUDOKU_MODE:
		if GameSession.ai_runtime_available():
			roles[index] = PlayerRoster.HUMAN if role == PlayerRoster.SUDOKU_AI and humans < PlayerRoster.MAX_HUMANS else PlayerRoster.SUDOKU_AI
		fit_height(get_viewport_rect().size.y)
		roster_changed.emit()
		return
	for attempt in range(7):
		role = role + 1 if role < 5 else PlayerRoster.HUMAN
		if role == PlayerRoster.HUMAN and humans >= PlayerRoster.MAX_HUMANS:
			continue
		if role > 0 and not GameSession.ai_runtime_available():
			continue
		break
	roles[index] = role
	fit_height(get_viewport_rect().size.y)
	roster_changed.emit()


func _add_slot() -> void:
	if not _can_add():
		return
	if game_mode == GameSession.SUDOKU_MODE:
		roles.append(PlayerRoster.SUDOKU_AI if GameSession.ai_runtime_available() else PlayerRoster.HUMAN)
	else:
		roles.append(3 if GameSession.ai_runtime_available() else PlayerRoster.PRACTICE)
	_refresh_row()
	if _add != null:
		_add.grab_focus()
	else:
		_selectors.back().grab_focus()
	roster_changed.emit()


func _remove_slot(index: int) -> void:
	if roles.size() <= 2:
		return
	roles.remove_at(index)
	_refresh_row()
	_selectors[mini(index, _selectors.size() - 1)].grab_focus()
	roster_changed.emit()


func preferred_width(view_width: float) -> float:
	return clampf(view_width - 110.0, 390.0, 1180.0)


func fit_height(available: float) -> void:
	var width := int(preferred_width(get_viewport_rect().size.x))
	var tile_space := width - GAP * (PlayerRoster.MAX_PLAYERS - 1)
	@warning_ignore("integer_division")
	var base_width := tile_space / PlayerRoster.MAX_PLAYERS
	var extra := tile_space % PlayerRoster.MAX_PLAYERS
	var tile_height := 129.0 if available < 570.0 else 177.0
	var compact := base_width < 117
	for i in range(_row.get_child_count()):
		_row.get_child(i).custom_minimum_size = Vector2(base_width + int(i < extra), tile_height)
	for i in range(_selectors.size()):
		_badges[i].custom_minimum_size.y = 32.0 if compact else 45.0
		_names[i].text = tr("PLAYER_SHORT" if compact else "PLAYER") % (i + 1)
		_names[i].add_theme_font_size_override("font_size", 16 if compact else 21)
		_selectors[i].custom_minimum_size.y = 25.0 if compact else 31.0
		_selectors[i].add_theme_font_size_override("font_size", 13 if compact else 16)
		_update_slot(i, compact)
