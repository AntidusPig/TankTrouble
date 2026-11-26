class_name MazeBuilderSudoku extends MazeBuilder

var solution: PackedInt32Array = []
var current_grid: PackedInt32Array = []

# the sub-grid dimensions
var block_w: int
var block_h: int

var sudoku_numbers : Array[SudokuNumber] = []
signal victory_achieved()
signal cell_edited(shooter: TankBase)
var solved := false

func _ready():
	super._ready()
	setup_dimensions()
	create_sudoku_puzzle()
	spawn_numbers()
	bg.size = maze_size*grid_size
	bg.position -= maze_size*grid_size/2.

func setup_dimensions():
	# 9x9 -> 3x3 blocks, 6x6 -> 3x2 blocks, 4x4 -> 2x2 blocks
	if maze_size.x == 4: block_w = 2; block_h = 2
	elif maze_size.x == 6: block_w = 3 if _maze_rng.randi() % 2 == 0 else 2; block_h = 5 - block_w
	elif maze_size.x == 9: block_w = 3; block_h = 3
	elif maze_size.x == 8: block_w = 4 if _maze_rng.randi() % 2 == 0 else 2; block_h = 6 - block_w
	elif maze_size.x == 10: block_w = 5 if _maze_rng.randi() % 2 == 0 else 2; block_h = 7 - block_w
	elif maze_size.x == 12: block_w = 4 if _maze_rng.randi() % 2 == 0 else 3; block_h = 7 - block_w
	elif maze_size.x == 16: block_w = 4; block_h = 4
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
	_shuffle_values(indices)
	# Adjust difficulty here
	var target_empty = total_cells / 4
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
	# Shuffle a constructive solution by whole bands, stacks and symbols.
	var rows := _shuffled_units(block_h)
	var columns := _shuffled_units(block_w)
	var symbols := range(1, maze_size.x + 1)
	_shuffle_values(symbols)
	for y in range(maze_size.y):
		for x in range(maze_size.x):
			var row: int = rows[y]
			var column: int = columns[x]
			var pattern := (row * block_w + row / block_h + column) % maze_size.x
			solution[y * maze_size.x + x] = symbols[pattern]
	return true


func _shuffled_units(group_size: int) -> Array[int]:
	var groups := range(maze_size.x / group_size)
	_shuffle_values(groups)
	var order: Array[int] = []
	for group in groups:
		var entries := range(group_size)
		_shuffle_values(entries)
		for entry in entries:
			order.append(group * group_size + entry)
	return order


func _shuffle_values(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var partner := _maze_rng.randi_range(0, i)
		var value: Variant = values[i]
		values[i] = values[partner]
		values[partner] = value




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
			var idx := j * maze_size.x + i
			var ns_inst : SudokuNumber = SudokuNumber.create(maze_size.x, current_grid[idx] != 0, idx)
			offset.add_child(ns_inst)
			ns_inst.position = Vector2(i * grid_size + grid_size/2, j * grid_size + grid_size/2)
			ns_inst.value_changed.connect(_on_cell_value_changed)
			ns_inst.shell_edited.connect(func(shooter: TankBase): cell_edited.emit(shooter))
			ns_inst.set_number(current_grid[idx])
			sudoku_numbers[idx] = ns_inst
		
####### CHECK #########
func _on_cell_value_changed(index: int, new_value: int):
	current_grid[index] = new_value
	if not solved and current_grid == solution:
		_handle_victory()
		
func _handle_victory() -> void:
	solved = true
	for number in sudoku_numbers:
		number.set_fixed(true)
	victory_achieved.emit()


func remaining_cells() -> int:
	var remaining := 0
	for index in range(current_grid.size()):
		remaining += int(current_grid[index] != solution[index])
	return remaining


######## DECORATIONS ##########
@onready var bg: ColorRect = $Background # The one with the ShaderMaterial
func set_bg_color(target_color: Color) -> void:
	# Use a tween to smoothly change the color uniform
	var mat = bg.material as ShaderMaterial
	if mat:
		var t = create_tween()
		t.tween_property(mat, "shader_parameter/base_color", target_color, 0.4).set_trans(Tween.TRANS_SINE)
		
# grid lines
func _draw() -> void:
	var size = maze_size.x
	var full_width = size * grid_size
	var full_height = size * grid_size
	# Offset to match your 'offset' node's centering logic
	var start_pos = -Vector2(full_width, full_height) / 2.0
	
	# 1. Draw Thin Internal Lines
	for i in range(size + 1):
		# Determine line thickness: Thick for borders/blocks, thin for cells
		var is_block_boundary = (i % block_w == 0) if i < size else true
		# For vertical lines, we check block_w; for horizontal, block_h
		var is_block_h_boundary = (i % block_h == 0) if i < size else true
		
		var color = Color(0, 0, 0, 0.15) # Subtle white/grey
		var thickness = 1.0
		
		# Vertical Lines
		var v_x = start_pos.x + (i * grid_size)
		var v_thickness = 5.0*thickness if is_block_boundary else thickness
		var v_color = Color(0, 0.5, 0.5, 0.5) if is_block_boundary else color
		draw_line(Vector2(v_x, start_pos.y), Vector2(v_x, start_pos.y + full_height), v_color, v_thickness)
		
		# Horizontal Lines
		var h_y = start_pos.y + (i * grid_size)
		var h_thickness = 5.0*thickness if is_block_h_boundary else thickness
		var h_color = Color(0, 0.5, 0.5, 0.5) if is_block_h_boundary else color
		draw_line(Vector2(start_pos.x, h_y), Vector2(start_pos.x + full_width, h_y), h_color, h_thickness)
