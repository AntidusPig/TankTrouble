class_name LevelManagerSudoku extends LevelManager

const SUDOKU_SHELL = preload("uid://dwtli077i4mwi")

# Override the shell selection
func get_shell_resource() -> Resource:
	return SUDOKU_SHELL
