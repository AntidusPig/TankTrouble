extends VBoxContainer

var _choices: Dictionary[int, OptionButton] = {}
var _status := Label.new()
var _scroll := ScrollContainer.new()
var _rows := GridContainer.new()


func _ready() -> void:
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_rows.columns = 2
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("h_separation", 12)
	_rows.add_theme_constant_override("v_separation", 3)
	_scroll.add_child(_rows)
	for role: int in AiSettings.ROLES:
		var label := Label.new()
		label.text = PlayerRoster.label_for(role)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 17)
		_rows.add_child(label)
		var choice := OptionButton.new()
		choice.custom_minimum_size.x = 145
		choice.add_theme_font_size_override("font_size", 16)
		for key in AiSettings.LABELS:
			choice.add_item(tr(key))
		choice.select(AiSettings.preference(role))
		choice.item_selected.connect(_changed.bind(role))
		_choices[role] = choice
		_rows.add_child(choice)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 15)
	_status.text = tr("AI_RANDOM_HINT")
	add_child(_status)


func _changed(value: int, role: int) -> void:
	if AiSettings.set_preference(role, value) == OK:
		_status.text = tr("AI_RANDOM_HINT")
	else:
		_choices[role].select(AiSettings.preference(role))
		_status.text = tr("SAVE_ERR")


func preferred_width(view_width: float) -> float:
	return clampf(view_width - 130.0, 355.0, 540.0)


func fit_height(available: float) -> void:
	_scroll.custom_minimum_size.y = minf(_rows.get_combined_minimum_size().y, maxf(130.0, available - 245.0))


func focus_first() -> void:
	_choices[AiSettings.ROLES[0]].grab_focus()
