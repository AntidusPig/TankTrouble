class_name ControlsSettings extends VBoxContainer

signal group_changed(group: int)

var group := 0
var _tabs: Array[Button] = []
var _scroll := ScrollContainer.new()
var _rows := GridContainer.new()
var _buttons := {}
var _status := Label.new()
var _capture_action: StringName
var _capture_kind := 0
var _capture_button: Button


func _ready() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 7)
	add_child(tabs)
	for index in range(4):
		var caption := tr("PLAYER") % (index + 1) if index < 3 else tr("MENUS")
		var tab := MenuPanel.create_button(caption, _show_group.bind(index), true)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tabs.add_child(tab)
		_tabs.append(tab)

	_rows.columns = 3
	_rows.add_theme_constant_override("h_separation", 9)
	_rows.add_theme_constant_override("v_separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_scroll.add_child(_rows)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 18)
	add_child(_status)
	_show_group(group)


func focus_first() -> void:
	_tabs[group].grab_focus()


func preferred_width(view_width: float) -> float:
	return clampf(view_width - 108.0, 380.0, 680.0)


func fit_height(available: float) -> void:
	var row_count := ControlBindings.actions_for(group).size()
	_scroll.custom_minimum_size.y = minf(29 + 41 * row_count, maxf(120.0, available - 320.0))


func _show_group(index: int) -> void:
	_cancel_capture()
	group = index
	for i in range(_tabs.size()):
		_tabs[i].set_pressed_no_signal(i == index)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_buttons.clear()
	for caption in [tr("ACTION"), tr("KEYBOARD"), tr("GAMEPAD")]:
		var label := _label(caption, 17)
		label.add_theme_font_override("font", RetroUi.display_font())
		_rows.add_child(label)
	var actions := ControlBindings.actions_for(index)
	var labels := ControlBindings.MENU_LABELS if index == 3 else ControlBindings.PLAYER_LABELS
	for i in range(actions.size()):
		var action := actions[i]
		var label := _label(tr(labels[i]), 19)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_child(label)
		var pair: Array[Button] = []
		for kind in range(2):
			var button := MenuPanel.create_button(ControlBindings.binding_name(action, kind),
				_begin_capture.bind(action, kind), true)
			button.add_theme_font_override("font", RetroUi.body_font())
			button.add_theme_font_size_override("font_size", 16)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.clip_text = true
			_rows.add_child(button)
			pair.append(button)
		_buttons[action] = pair
	_status.text = tr("CAPTURE_HINT")
	_scroll.scroll_vertical = 0
	fit_height(get_viewport_rect().size.y)
	group_changed.emit(group)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _begin_capture(action: StringName, kind: int) -> void:
	_cancel_capture()
	_capture_action = action
	_capture_kind = kind
	_capture_button = _buttons[action][kind]
	_capture_button.text = tr("LISTENING")
	_status.text = tr("CAPTURE_KEY") if kind == 0 else tr("CAPTURE_PAD")


func _cancel_capture() -> void:
	if is_instance_valid(_capture_button):
		_capture_button.text = ControlBindings.binding_name(_capture_action, _capture_kind)
	_capture_button = null


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_capture_button):
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	get_viewport().set_input_as_handled()
	if _capture_action != &"Escape" and event.is_action_pressed(&"Escape", false, true):
		_cancel_capture()
		_status.text = tr("UNCHANGED")
		return
	var binding := ControlBindings.capture(event, _capture_kind)
	if binding == null:
		return
	var message := ControlBindings.set_binding(_capture_action, _capture_kind, binding)
	if not message.is_empty():
		_status.text = message + " " + tr("TRY_INPUT")
		return
	_cancel_capture()
	_status.text = tr("BINDING_SAVED")
