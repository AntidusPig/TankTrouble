class_name MazeBuilderSudoku extends MazeBuilder

var solution: PackedInt32Array = []
var current_grid: PackedInt32Array = []

# the sub-grid dimensions
var block_w: int
var block_h: int

const NUMBER_SCENE = preload("uid://d0etr1ysu0j7o")
var number_labels = {} # Key: Vector2i(x,y), Value: Label node

func _ready():
	super._ready()
	setup_dimensions()
	create_sudoku_puzzle()
	spawn_numbers()

func setup_dimensions():
	# 9x9 -> 3x3 blocks, 6x6 -> 3x2 blocks, 4x4 -> 2x2 blocks
	if maze_size.x == 9: block_w = 3; block_h = 3
	elif maze_size.x == 6: block_w = 3; block_h = 2
	elif maze_size.x == 4: block_w = 2; block_h = 2
	else:
		push_error("Invalid Sudoku Size: ", maze_size.x, ', ', maze_size.y)
		block_w = 1; block_h = 1

func create_sudoku_puzzle():
	var total_cells : int = maze_size.x * maze_size.y
	solution.resize(total_cells)
	solution.fill(0)
	current_grid.resize(total_cells)

	fill_grid()
	current_grid = solution.duplicate()

	var indices = range(total_cells)
	indices.shuffle()
	# Adjust difficulty here
	var target_empty = total_cells / 2
	var removed_count = 0
	for idx in indices:
		if removed_count >= target_empty: break
		 # Try removing a number
		var backup: int = current_grid[idx]
		current_grid[idx] = 0
		# Check if the puzzle still has exactly ONE solution
		if count_solutions(current_grid.duplicate()) != 1:
			current_grid[idx] = backup # Put it back, removing this creates ambiguity
		else:
			removed_count += 1

func count_solutions(grid: PackedInt32Array) -> int:
	'''
	A well-posed sudoku has a unique solution
	Remove Optimization if you really want to count instead of ONLY telling if it's unique
	'''
	return _solve_and_count(0,grid)

func _solve_and_count(solution_count: int, grid: PackedInt32Array) -> int:
	if solution_count > 1: return solution_count # Optimization: stop if we find a second one
	for i in range(grid.size()):
		if grid[i] == 0:
			for val in range(1, maze_size.x + 1):
				if can_place_number(grid, i / maze_size.x, i % maze_size.x, val):
					grid[i] = val
					solution_count = _solve_and_count(solution_count, grid)
					grid[i] = 0 # Backtrack
			return solution_count
	return solution_count + 1

func fill_grid() -> bool:
	for i in range(solution.size()):
		if solution[i] == 0:
			var numbers = range(1, maze_size.x + 1)
			numbers.shuffle()
			for value in numbers:
				var row = i / maze_size.x
				var col = i % maze_size.x
				if can_place_number(solution, row, col, value):
					solution[i] = value
					if not 0 in solution: return true
					if fill_grid(): return true
			solution[i] = 0
			return false
	return true

func can_place_number(grid: PackedInt32Array, row: int, col: int, val: int) -> bool:
	# Check Row and Column, remember the sudoku is NxN, square
	for k in range(maze_size.x):
		if grid[row * maze_size.x + k] == val: return false
		if grid[k * maze_size.x + col] == val: return false
		
	# Check Block
	var start_row: int = (row / block_h) * block_h
	var start_col: int = (col / block_w) * block_w
	for r in range(block_h):
		for c in range(block_w):
			if grid[(start_row + r) * maze_size.x + (start_col + c)] == val:
				return false
	return true


######### DISPLAY #############
func spawn_numbers() -> void:
	for node in number_labels.values():
		node.get_parent().queue_free()
	number_labels.clear()

	for i in range(maze_size.x):
		for j in range(maze_size.y):
			var idx = i * maze_size.y + j
			var cell_inst = NUMBER_SCENE.instantiate()
			cell_inst.scale = scale
			offset.add_child(cell_inst)
			print(cell_inst)
			cell_inst.position = Vector2(i * grid_size + grid_size/2, j * grid_size + grid_size/2)
			var label = cell_inst.get_node("Label")
			number_labels[idx] = label
			_update_label_text(idx)

func _update_label_text(idx: int) -> void:
	var val = current_grid[idx]
	if val == 0:
		number_labels[idx].text = ""
	else:
		number_labels[idx].text = str(val)
		
####### COLLISION #########
func handle_shell_hit(impact_position: Vector2) -> void:
	var local_pos = impact_position - offset.global_position
	
	var gx = floor(local_pos.x / grid_size)
	var gy = floor(local_pos.y / grid_size)
	
	if gx >= 0 and gx < maze_size.x and gy >= 0 and gy < maze_size.y:
		var idx = int(gx * maze_size.y + gy)
		current_grid[idx] = (current_grid[idx] % maze_size.x) + 1
		_update_label_text(idx)
		check_sudoku_status()

func check_sudoku_status() -> void:
	pass
