extends MenuPanel

var _selection := PackedInt32Array([PlayerRoster.HUMAN, 3])
var _sudoku_selection := PackedInt32Array([PlayerRoster.HUMAN, PlayerRoster.SUDOKU_AI])
const MAP_EDITOR := preload("res://UI/Menu/map_editor.gd")
var _paint_pending := PackedInt32Array()
var _mode := GameSession.ARENA_MODE
var _map_choices := [9, 9]
var _picker: RosterPicker
var _start_button: Button
var _back_action: Callable
var _settings_group := 0
var _languages := HBoxContainer.new()


func _ready() -> void:
	show_title_art = true
	super()
	if not GameSession.ai_runtime_available():
		_selection[1] = PlayerRoster.HUMAN
		_sudoku_selection[1] = PlayerRoster.HUMAN
	_build_languages()
	if GameSession.return_to_map_editor:
		GameSession.return_to_map_editor = false
		GameSession.completed = false
		_show_map_editor()
	else:
		_show_home()


func _build_languages() -> void:
	_languages.alignment = BoxContainer.ALIGNMENT_CENTER
	_languages.add_theme_constant_override("separation", 6)
	_content.add_child(_languages)
	var group := ButtonGroup.new()
	for locale: String in LocaleManager.FLAGS:
		var button := MenuPanel.create_button("", _select_language.bind(locale), true)
		button.icon = LocaleManager.FLAGS[locale]
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 26)
		button.custom_minimum_size = Vector2(43, 30)
		for state in ["normal", "hover", "pressed"]:
			var flag_style := RetroUi.theme_resource().get_stylebox(state, "Button").duplicate() as StyleBoxFlat
			flag_style.content_margin_left = 5.0
			flag_style.content_margin_right = 5.0
			flag_style.content_margin_top = 3.0
			flag_style.content_margin_bottom = 3.0
			button.add_theme_stylebox_override(state, flag_style)
		button.tooltip_text = LocaleManager.LANGUAGE_NAMES[locale]
		button.toggle_mode = true
		button.button_group = group
		button.set_pressed_no_signal(locale == TranslationServer.get_locale())
		_languages.add_child(button)


func _fit_menu() -> void:
	actions.columns = 2 if _languages.visible and get_viewport_rect().size.y < 640.0 else 1
	super()


func _select_language(locale: String) -> void:
	var active_flag := get_viewport().gui_get_focus_owner()
	LocaleManager.select(locale)
	_show_home()
	if active_flag != null and active_flag.get_parent() == _languages:
		active_flag.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _back_action.is_valid() and event.is_action_pressed(&"Escape", false, true):
		get_viewport().set_input_as_handled()
		CartoonSound.play_pause()
		_back_action.call()


func _show_home() -> void:
	_back_action = Callable()
	detail.show()
	_languages.show()
	_clear_actions()
	show_page(null)
	title.text = tr("TITLE")
	detail.text = (tr("PUZZLE_SOLVED") if GameSession.mode == GameSession.SUDOKU_MODE else tr("CAMPAIGN_COMPLETE")) if GameSession.completed else tr("NAV_HINT") % [
		ControlBindings.binding_name(&"ui_focus_next", 0), ControlBindings.binding_name(&"ui_accept", 0)]
	_button(tr("NEW"), _show_roster).grab_focus()
	_button(tr("SUDOKU"), _show_roster.bind(GameSession.SUDOKU_MODE))
	var load_button := _button(tr("LOAD"), _load)
	load_button.disabled = not GameSession.has_checkpoint()
	_button(tr("BOOK"), _show_encyclopedia)
	_button(tr("SETTINGS"), _show_settings)
	_button(tr("MAP_EDITOR"), _show_map_editor)
	_button(tr("QUIT"), get_tree().quit)


func _show_map_editor() -> void:
	_languages.hide()
	_back_action = _show_home
	_clear_actions()
	title.text = tr("MAP_EDITOR")
	detail.hide()
	var editor := MAP_EDITOR.new()
	editor.dimension = GameSession.editor_dimension
	editor.tiles = GameSession.editor_draft.duplicate()
	editor.draft_changed.connect(_remember_map)
	editor.playtest.connect(_edit_playtest)
	show_page(editor)
	_button(tr("BACK"), _show_home)
	editor.focus_grid()


func _remember_map(dimension: int, tiles: PackedInt32Array) -> void:
	GameSession.editor_dimension = dimension
	GameSession.editor_draft = tiles


func _edit_playtest(dimension: int, tiles: PackedInt32Array) -> void:
	_show_roster(GameSession.ARENA_MODE, dimension, tiles)


func _show_roster(mode := GameSession.ARENA_MODE, paint_size := 0, paint := PackedInt32Array()) -> void:
	_paint_pending = paint
	detail.show()
	_mode = mode
	_languages.hide()
	_back_action = _show_home if paint.is_empty() else _show_map_editor
	_clear_actions()
	title.text = tr("SUDOKU_SETUP") if mode == GameSession.SUDOKU_MODE else tr("CHOOSE")
	_picker = RosterPicker.new()
	_picker.game_mode = mode
	_picker.map_choice = _map_choices[mode] if paint.is_empty() else paint_size
	_picker.locked_size = not paint.is_empty()
	_picker.roles = (_sudoku_selection if mode == GameSession.SUDOKU_MODE else _selection).duplicate()
	_picker.roster_changed.connect(_update_roster)
	show_page(_picker)
	_start_button = _button(tr("START_PUZZLE") if mode == GameSession.SUDOKU_MODE else tr("START_MATCH"), _start)
	_button(tr("BACK"), _back_action)
	_update_roster()
	_start_button.grab_focus()


func _update_roster() -> void:
	var selection := _picker.roles.duplicate()
	if _mode == GameSession.SUDOKU_MODE:
		_sudoku_selection = selection
	else:
		_selection = selection
	if _paint_pending.is_empty():
		_map_choices[_mode] = _picker.map_choice
	var players := selection.size()
	var humans := selection.count(PlayerRoster.HUMAN)
	var notes := String(tr("PLAYER_COUNTS")) % [players, humans]
	if humans > 0:
		var summary := PackedStringArray()
		for slot in range(humans):
			var player_actions := ControlBindings.actions_for(slot)
			var keys := PackedStringArray()
			for i in range(4):
				keys.append(ControlBindings.binding_name(player_actions[i], 0))
			summary.append("%s + %s" % ["/".join(keys), ControlBindings.binding_name(player_actions[4], 0)])
		notes += "\n" + "  ·  ".join(summary)
	if not GameSession.ai_runtime_available():
		notes += "\n" + tr("AI_DOTNET")
	detail.text = notes
	var enough_cells := _paint_pending.is_empty() or _paint_pending.size() - _paint_pending.count(0) >= players
	if not enough_cells:
		detail.text += "\n" + tr("MAP_INVALID")
	_start_button.disabled = not PlayerRoster.is_valid(selection) or not enough_cells


func _show_encyclopedia() -> void:
	_languages.hide()
	_back_action = _show_home
	_clear_actions()
	title.text = tr("BOOK")
	detail.text = ""
	show_page(ArenaEncyclopedia.new())
	_button(tr("BACK"), _show_home).grab_focus()


func _show_settings() -> void:
	_languages.hide()
	_back_action = _show_home
	_clear_actions()
	title.text = tr("CONTROLS")
	detail.text = ""
	var settings := ControlsSettings.new()
	settings.group = _settings_group
	settings.group_changed.connect(func(group: int): _settings_group = group)
	show_page(settings)
	_button(tr("RESTORE"), _confirm_defaults)
	_button(tr("BACK"), _show_home)
	settings.focus_first()


func _confirm_defaults() -> void:
	_languages.hide()
	_back_action = _show_settings
	_clear_actions()
	show_page(null)
	title.text = tr("RESTORE_PROMPT")
	detail.text = tr("RESTORE_NOTE")
	_button(tr("RESTORE"), _restore_defaults)
	_button(tr("CANCEL"), _show_settings).grab_focus()


func _restore_defaults() -> void:
	var result := ControlBindings.restore_defaults()
	_show_settings()
	detail.text = tr("RESTORED") if result == OK else tr("RESET_ERR") + " " + error_string(result)


func _start() -> void:
	if GameSession.start_roster(_picker.roles, _mode, _picker.map_choice, _paint_pending) != OK:
		detail.text = tr("START_ERR")


func _load() -> void:
	var result := GameSession.load_checkpoint()
	if result == ERR_UNAVAILABLE:
		detail.text = tr("LOAD_DOTNET")
	elif result != OK:
		detail.text = tr("LOAD_ERR")
