@tool
class_name ShellSudoku extends Shell

func _handle_collision(result: Dictionary) -> void:
	var collider = result.collider
	var cell : SudokuNumber = null
	if collider is SudokuNumber:
		cell = collider
	elif collider.get_parent() is SudokuNumber:  # this will run
		cell = collider.get_parent()
	if cell:
		if not cell.fixed:
			cell.increment_value()
			destroy(true) 
			return
	else:
		# wall or tank
		_bounce(result)
