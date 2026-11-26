class_name PauseMenu extends CanvasLayer

@export var checkpoint_enabled := false

var _panel := MenuPanel.new()
var _resume_button: Button
var _previous_auto_quit: bool


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_panel.backdrop_color = RetroUi.DIM
	add_child(_panel)
	_panel.title.text = "Paused"
	_resume_button = _panel._button("Resume", _set_paused.bind(false))
	if checkpoint_enabled:
		_panel._button("Save Checkpoint", _save_checkpoint)
	_panel._button("Main Menu", _return_to_menu)
	_panel.hide()


func _exit_tree() -> void:
	get_tree().auto_accept_quit = _previous_auto_quit
	if _panel.visible:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Escape"):
		get_viewport().set_input_as_handled()
		CartoonSound.play_pause()
		_set_paused(not _panel.visible)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_set_paused(true)


func open() -> void:
	_set_paused(true)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_panel.visible = paused
	if paused:
		_panel.detail.text = ""
		_resume_button.grab_focus()


func _save_checkpoint() -> void:
	if GameSession.completed:
		_panel.detail.text = "Series complete"
		return
	var result := GameSession.save_checkpoint()
	_panel.detail.text = "Checkpoint saved" if result == OK else "Save failed: " + error_string(result)


func _return_to_menu() -> void:
	_set_paused(false)
	get_tree().change_scene_to_file(GameSession.MENU)
