extends MenuPanel


func _ready() -> void:
	show_title_art = true
	super()
	_show_home()


func _show_home() -> void:
	_clear_actions()
	title.text = "Tank Trouble"
	detail.text = ""
	if GameSession.completed:
		detail.text = "Arena series complete  ·  %d–%d  ·  %d draws" % [
			GameSession.player_one_wins,
			GameSession.player_two_wins if GameSession.player_count == 2 else GameSession.losses,
			GameSession.draws
		]
	_button("New Game", _select_players).grab_focus()
	var load_button := _button("Load Checkpoint", _load)
	load_button.disabled = not GameSession.has_checkpoint()
	_button("Quit", get_tree().quit)


func _select_players() -> void:
	_clear_actions()
	title.text = "Players"
	detail.text = "P1  WASD + F     P2  Arrows + Enter"
	var ai_button := _button("1 Player  ·  Play against AI", _select_ai)
	ai_button.disabled = not GameSession.ai_runtime_available()
	if ai_button.disabled:
		detail.text += "\nFor AI opponents, open the project in Godot .NET."
	else:
		ai_button.grab_focus()
	_button("2 Players  ·  Local versus", _start.bind(2))
	_button("1 Player  ·  Target practice", _start.bind(1))
	_button("Back", _show_home)


func _select_ai() -> void:
	_clear_actions()
	title.text = "Opponent AI"
	detail.text = "Choose a controller for the enemy tanks."
	_button("State Machine", _start.bind(1, 1)).grab_focus()
	_button("Behavior Tree", _start.bind(1, 2))
	_button("GOAP", _start.bind(1, 3))
	_button("Utility + Lookahead", _start.bind(1, 4))
	_button("Neural Self-Play", _start.bind(1, 5))
	_button("Back", _select_players)


func _start(players: int, controller: int = 0) -> void:
	if GameSession.start(players, controller) != OK:
		detail.text = "Could not open the arena."


func _load() -> void:
	var result := GameSession.load_checkpoint()
	if result == ERR_UNAVAILABLE:
		detail.text = "Open the project in Godot .NET to load this AI checkpoint."
	elif result != OK:
		detail.text = "Could not load the checkpoint."
