extends Node

const SAVE_PATH := "user://controls.cfg"
const TEMP_PATH := "user://controls.cfg.tmp"
const PLAYER_ACTIONS := [&"Up", &"Down", &"Left", &"Right", &"Attack"]
const PLAYER_LABELS := ["FORWARD", "REVERSE", "TURN_L", "TURN_R", "FIRE"]
const MENU_ACTIONS := [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"Escape",
	&"ui_focus_next", &"ui_focus_prev"]
const MENU_LABELS := ["MENU_UP", "MENU_DOWN", "MENU_LEFT", "MENU_RIGHT",
	"MENU_SELECT", "MENU_PAUSE", "MENU_NEXT", "MENU_PREVIOUS"]
const GAMEPAD_NAMES := ["A", "B", "X", "Y", "PAD_BACK", "PAD_GUIDE", "PAD_START", "PAD_STICK_L",
	"PAD_STICK_R", "LB", "RB", "PAD_D_UP", "PAD_D_DOWN", "PAD_D_LEFT", "PAD_D_RIGHT"]
const AXIS_NAMES := ["PAD_LX", "PAD_LY", "PAD_RX", "PAD_RY", "LT", "RT"]

var _defaults := [{}, {}]
var _bindings := [{}, {}]
var _labels := {}


func _ready() -> void:
	for player in range(3):
		var action_list := actions_for(player)
		for i in range(action_list.size()):
			var action := action_list[i]
			_labels[action] = [player + 1, PLAYER_LABELS[i]]
			for binding in InputMap.action_get_events(action):
				if binding is InputEventKey:
					_defaults[0][action] = binding
					break
			match i:
				0: _defaults[1][action] = _axis(JOY_AXIS_LEFT_Y, -1.0, player)
				1: _defaults[1][action] = _axis(JOY_AXIS_LEFT_Y, 1.0, player)
				2: _defaults[1][action] = _axis(JOY_AXIS_LEFT_X, -1.0, player)
				3: _defaults[1][action] = _axis(JOY_AXIS_LEFT_X, 1.0, player)
				4: _defaults[1][action] = _pad(JOY_BUTTON_A, player)

	var menu_keys := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_ESCAPE, KEY_TAB, KEY_TAB]
	var menu_pad := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER]
	for i in range(MENU_ACTIONS.size()):
		var action: StringName = MENU_ACTIONS[i]
		_labels[action] = MENU_LABELS[i]
		_defaults[0][action] = _key(menu_keys[i], i == 7)
		_defaults[1][action] = _pad(menu_pad[i], -1)
	_bindings = _defaults.duplicate(true)
	_load_saved()
	_apply()


func actions_for(group: int) -> Array[StringName]:
	var actions: Array[StringName] = []
	if group == 3:
		actions.assign(MENU_ACTIONS)
	else:
		var suffix := str(group + 1) if group > 0 else ""
		for action in PLAYER_ACTIONS:
			actions.append(StringName(String(action) + suffix))
	return actions


func binding_name(action: StringName, device_kind: int) -> String:
	var event: InputEvent = _bindings[device_kind][action]
	if event is InputEventKey:
		return OS.get_keycode_string(event.get_physical_keycode_with_modifiers())
	var control: String
	if event is InputEventJoypadMotion:
		var axis_index: int = event.axis
		var axis_name: String = tr(AXIS_NAMES[axis_index]) if axis_index < AXIS_NAMES.size() else tr("AXIS") % axis_index
		control = axis_name + (" −" if event.axis_value < 0.0 else " +")
	else:
		var button_index: int = event.button_index
		control = tr(GAMEPAD_NAMES[button_index]) if button_index < GAMEPAD_NAMES.size() else tr("BUTTON") % button_index
	return (tr("ANY_PAD") if event.device == -1 else tr("PAD") % (event.device + 1)) + " · " + control


func _action_label(action: StringName) -> String:
	var label: Variant = _labels[action]
	if label is Array:
		return "%s · %s" % [tr("PLAYER") % label[0], tr(label[1])]
	return tr(label)


func capture(event: InputEvent, device_kind: int) -> InputEvent:
	if device_kind == 0 and event is InputEventKey and not event.echo:
		var code: Key = event.physical_keycode
		var modifier: bool = code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
		if code == 0 or event.pressed == modifier:
			return null
		# Wait for release when the key is a modifier so combinations can be entered.
		var key := _key(code, event.shift_pressed or code == KEY_SHIFT)
		key.ctrl_pressed = event.ctrl_pressed or code == KEY_CTRL
		key.alt_pressed = event.alt_pressed or code == KEY_ALT
		key.meta_pressed = event.meta_pressed or code == KEY_META
		return key
	if device_kind == 1 and event is InputEventJoypadButton and event.pressed:
		return _pad(event.button_index, event.device)
	if device_kind == 1 and event is InputEventJoypadMotion and absf(event.axis_value) >= 0.75:
		return _axis(event.axis, signf(event.axis_value), event.device)
	return null


func set_binding(action: StringName, device_kind: int, event: InputEvent) -> String:
	if MENU_ACTIONS.has(action) and device_kind == 1:
		event.device = -1
	for other in _bindings[device_kind]:
		if other == action or MENU_ACTIONS.has(other) != MENU_ACTIONS.has(action):
			continue
		var current: InputEvent = _bindings[device_kind][other]
		if (current.device == event.device or current.device == -1 or event.device == -1) and current.is_match(event, true):
			return tr("ASSIGNED") % _action_label(other)
	var previous: InputEvent = _bindings[device_kind][action]
	_bindings[device_kind][action] = event
	var result := _save()
	if result != OK:
		_bindings[device_kind][action] = previous
		return tr("BIND_ERR") + " " + error_string(result)
	_apply()
	return ""


func restore_defaults() -> Error:
	var previous := _bindings
	_bindings = _defaults.duplicate(true)
	var result := _save()
	if result != OK:
		_bindings = previous
		return result
	_apply()
	return OK


func _apply() -> void:
	for action in _labels:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for kind in range(2):
			InputMap.action_add_event(action, _bindings[kind][action])


func _load_saved() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for kind in range(2):
		for action in _labels:
			var value: Variant = config.get_value("keyboard" if kind == 0 else "gamepad", String(action), null)
			var event := _decode(value, kind)
			if event != null:
				if kind == 1 and MENU_ACTIONS.has(action):
					event.device = -1
				_bindings[kind][action] = event


func _save() -> Error:
	var config := ConfigFile.new()
	for kind in range(2):
		for action in _labels:
			var event: InputEvent = _bindings[kind][action]
			var encoded: PackedInt32Array
			if event is InputEventKey:
				encoded = PackedInt32Array([event.physical_keycode, int(event.shift_pressed),
					int(event.ctrl_pressed), int(event.alt_pressed), int(event.meta_pressed)])
			elif event is InputEventJoypadButton:
				encoded = PackedInt32Array([0, event.device, event.button_index, 0])
			else:
				encoded = PackedInt32Array([1, event.device, event.axis, int(event.axis_value)])
			config.set_value("keyboard" if kind == 0 else "gamepad", String(action), encoded)
	var result := config.save(TEMP_PATH)
	if result != OK:
		return result
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))


func _decode(value: Variant, kind: int) -> InputEvent:
	if typeof(value) != TYPE_PACKED_INT32_ARRAY:
		return null
	if kind == 0 and value.size() == 5 and value[0] > 0:
		var key := _key(value[0], value[1] == 1)
		key.ctrl_pressed = value[2] == 1
		key.alt_pressed = value[3] == 1
		key.meta_pressed = value[4] == 1
		return key
	if kind == 1 and value.size() == 4 and value[1] >= -1 and value[2] >= 0:
		if value[0] == 0 and value[2] < JOY_BUTTON_MAX:
			return _pad(value[2], value[1])
		if value[0] == 1 and value[2] < JOY_AXIS_MAX and abs(value[3]) == 1:
			return _axis(value[2], value[3], value[1])
	return null


func _key(code: Key, shifted := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.shift_pressed = shifted
	return event


func _pad(index: JoyButton, device: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.device = device
	return event


func _axis(index: JoyAxis, direction: float, device: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = direction
	event.device = device
	return event
