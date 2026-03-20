class_name MazeBuilderSudoku extends MazeBuilder

var solution: PackedInt32Array = []
var current_grid: PackedInt32Array = []

# the sub-grid dimensions
var block_w: int
var block_h: int

var sudoku_numbers : Array[SudokuNumber] = []
signal victory_achieved()

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
	#for n in sudoku_numbers:
		#n.get_parent().queue_free()
	#sudoku_numbers.clear()
	sudoku_numbers.resize(maze_size.x*maze_size.y)

	for i in range(maze_size.x):
		for j in range(maze_size.y):
			var idx = i * maze_size.y + j
			var ns_inst : SudokuNumber = SudokuNumber.create(maze_size.x, current_grid[idx] != 0, idx)
			ns_inst.scale = scale
			ns_inst.position = Vector2(i * grid_size + grid_size/2, j * grid_size + grid_size/2)
			ns_inst.value_changed.connect(_on_cell_value_changed)
			ns_inst.set_number(current_grid[idx])
			sudoku_numbers[idx] = ns_inst
			offset.add_child(ns_inst)
		
####### CHECK #########
func _on_cell_value_changed(index: int, new_value: int):
	current_grid[index] = new_value
	if _check_if_solved():
		_handle_victory()
		
func _check_if_solved() -> bool:
	var size = maze_size.x
	# Generates 1111111110 for 9, 11110 for 4, etc.
	# the last digit is for empty (0) cell
	var target_mask = (1 << (size + 1)) - 2
	for i in range(size):
		var row_m = 0; var col_m = 0; var blk_m = 0
		for j in range(size):
			# Row index: (i, j)
			row_m |= 1 << current_grid[i * size + j]
			# Column index: (j, i)
			col_m |= 1 << current_grid[j * size + i]
			# Block index math:
			var br = (i / block_h) * block_h + (j / block_w)
			var bc = (i % block_h) * block_w + (j % block_w)
			blk_m |= 1 << current_grid[br * size + bc]
		if row_m != target_mask or col_m != target_mask or blk_m != target_mask:
			return false
	return true
	
func _handle_victory() -> void:
	print("Sudoku Solved! Triggering Victory.")
	for node in sudoku_numbers:
		if is_instance_valid(node):
			# Disable the collision/interaction area so bullets pass through now
			var area = node.get_node_or_null("Area2D")
			if area: area.monitorable = false
			
			# Visual celebration: Tween the numbers to a "Victory" color
			for sn in sudoku_numbers:
				sn.set_fixed(true)
	victory_achieved.emit()
	
