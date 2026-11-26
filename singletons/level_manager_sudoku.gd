class_name LevelManagerSudoku extends ArenaRoundManager

const SUDOKU_SHELL := preload("uid://dwtli077i4mwi")
const SOLVER := "res://gameplay/ai/components/SudokuSolverAI.tscn"

var _edits := {}


func get_shell_resource() -> Resource:
	return SUDOKU_SHELL


func _configure_mode() -> void:
	var puzzle := maze_builder as MazeBuilderSudoku
	puzzle.victory_achieved.connect(_puzzle_completed.call_deferred)
	puzzle.cell_edited.connect(_on_cell_edited)


func _configure_tank(tank: TankBase) -> void:
	# Cooperative tanks keep wall collisions without blocking one another.
	tank.set_collision_layer_value(1, false)
	tank.set_collision_mask_value(2, false)


func _choose_spawn(contestant: Contestant, cells: Array[Vector2i]) -> Vector2i:
	var puzzle := maze_builder as MazeBuilderSudoku
	var givens := cells.filter(func(cell: Vector2i):
		return puzzle.sudoku_numbers[cell.y * puzzle.maze_size.x + cell.x].fixed
	)
	return super._choose_spawn(contestant, givens if not givens.is_empty() else cells)


func _attach_ai(tank: TankBase, _role: int) -> void:
	if GameSession.ai_runtime_available():
		var controller := load(SOLVER) as PackedScene
		if controller != null:
			tank.add_child(controller.instantiate())
			if tank.has_meta("_active_tank_brain"):
				return
	_ai_status = tr("AI_DOTNET")


func _on_cell_edited(shooter: TankBase) -> void:
	if is_instance_valid(shooter):
		_edits[shooter.team] = int(_edits.get(shooter.team, 0)) + 1


func _puzzle_completed() -> void:
	if not round_active:
		return
	GameSession.completed = true
	round_result = tr("PUZZLE_SOLVED")
	_freeze_round()
	next_round.start(intermission)


func _advance() -> void:
	_return_to_menu()


func _process(_delta: float) -> void:
	var puzzle := maze_builder as MazeBuilderSudoku
	var size := puzzle.maze_size.x
	var title := tr("PUZZLE_STATUS") % [size, size, puzzle.remaining_cells()]
	if puzzle.solved:
		title = tr("PUZZLE_SOLVED")
	elif not _ai_status.is_empty():
		title += " · " + _ai_status
	hud.show_round(title)
	for contestant in contestants:
		contestant.card.update_sudoku(int(_edits.get(contestant.team, 0)), contestant.role == PlayerRoster.HUMAN)
