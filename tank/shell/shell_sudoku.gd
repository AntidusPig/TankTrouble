@tool
class_name ShellSudoku extends Shell

func _collision_mask() -> int:
	return 1


func _handle_collision(result: Dictionary, is_inside:bool) -> bool:
	var collider = result.collider
	var cell : SudokuNumber = null
	if collider is SudokuNumber:
		cell = collider
	elif collider.get_parent() is SudokuNumber:  # this will run
		cell = collider.get_parent()
	if cell:
		if not cell.fixed:
			cell.increment_value(spawner)
			destroy(true) 
			return false
		else:return true  # pass through/ignore fixed cell
	else:
		# wall or tank
		if not is_inside:
			_bounce(result)
		return false
