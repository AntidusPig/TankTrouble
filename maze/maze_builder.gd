class_name MazeBuilder extends Node2D

@onready var maze_astar: MazeAStar = $MazeAStar
const wall = preload("res://maze/wall/wall.tscn")

@export var maze_size : Vector2i = Vector2i(10,10)
@onready var offset: Node2D = $offset
var grid_size : float
var wall_thickness : float
const neighbour_dir = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
var walls_dict = {}
@export var generation_seed: int = -1
enum Footprint { RECTANGLE, MOON, FOUNDRY, GROVE, KEYHOLE, SWITCHBACK, FORK }
const BOARD := preload("res://maze/painted_map.gd")
var painted_cells := PackedInt32Array()
@export var footprint := Footprint.RECTANGLE
var _maze_rng := RandomNumberGenerator.new()

func _ready() -> void:
	if generation_seed < 0:
		_maze_rng.randomize()
	else:
		_maze_rng.seed = generation_seed
	# cache wall size
	var wall_inst : Wall = wall.instantiate()
	offset.add_child(wall_inst)
	var wall_size : Vector2 = wall_inst.collision_shape_2d.shape.size
	wall_thickness = min(wall_size.x,wall_size.y)
	grid_size = max(wall_size.x,wall_size.y) - wall_thickness
	wall_inst.queue_free()
	
	offset.position -= maze_size*grid_size/2.
	
	maze_astar.setup_astar_points()
	create_maze()
	
func get_cell_position(i:int, j:int) -> Vector2:
	return to_global(Vector2(grid_size * (i + 0.5), grid_size * (j + 0.5)) - grid_size * maze_size / 2.0)

func cell_at(world_point: Vector2) -> Vector2i:
	return Vector2i((to_local(world_point) / grid_size + Vector2(maze_size) * 0.5).floor())


func add_wall(posx:int, posy:int, horizontal:bool) -> void:
	'''
	posx : row
	poxy : column
	horizontal : if the wall is horizontal or vertical
	'''
	var wall_inst : Wall = wall.instantiate()
	# name is important for wall deletion later
	var key = "%d_%d_%s" % [posx, posy, "h" if horizontal else "v"]
	wall_inst.name = key
	walls_dict[key] = wall_inst
	
	offset.add_child(wall_inst)
	wall_inst.position = Vector2(posx * grid_size, posy * grid_size)
	if horizontal:
		wall_inst.rotation = PI/2
		wall_inst.position.x += grid_size/2.
	else:
		wall_inst.position.y += grid_size/2.

func remove_wall(posx:float, posy:float, horizontal:bool) -> void:
	var key = "%d_%d_%s" % [posx, posy, "h" if horizontal else "v"]
	if walls_dict.has(key):
		walls_dict[key].queue_free()
		walls_dict.erase(key)
		if horizontal:
			maze_astar.connect_cells_with_wall(posx, posy, posx, posy-1)
		else:
			maze_astar.connect_cells_with_wall(posx, posy, posx-1, posy)

func add_all_walls() -> void:
	for i in range(maze_size.x+1):
		for j in range(maze_size.y):
			if valid_index(i - 1, j) or valid_index(i, j):
				add_wall(i, j, false)
	for i in range(maze_size.x):
		for j in range(maze_size.y + 1):
			if valid_index(i, j - 1) or valid_index(i, j):
				add_wall(i, j, true)
	
func add_border_walls() -> void:
	for i in [0,maze_size.x]:
		for j in range(maze_size.y):
			add_wall(i,j,false)
	for i in range(maze_size.x):
		for j in [0,maze_size.y]:
			add_wall(i,j,true)

func valid_index(i:int,j:int) -> bool:
	'''
	check if (i,j) is inside the maze
	'''
	if i < 0 or i >= maze_size.x or j < 0 or j >= maze_size.y:
		return false
	if not painted_cells.is_empty():
		return painted_cells[j * maze_size.x + i] != BOARD.Tile.VOID
	var point := (Vector2(i + 0.5, j + 0.5) * 2.0 / Vector2(maze_size) - Vector2.ONE)
	var symmetric := point.abs()
	match footprint:
		Footprint.MOON: return symmetric.length_squared() <= 1.0
		Footprint.FOUNDRY: return symmetric.x + symmetric.y <= 1.25
		Footprint.GROVE: return symmetric.x < 0.58 or symmetric.y < 0.58
		Footprint.KEYHOLE: return point.y <= 0.0 or symmetric.x <= 0.34 or point.y > 0.65
		Footprint.SWITCHBACK:
			var band := 5 * j / maze_size.y
			if band == 1: return point.x < -0.20
			if band == 3: return point.x > 0.20
		Footprint.FORK: return point.y > 0.22 or symmetric.x >= 0.36
	return true

func pop_random(array):
	assert(not array.is_empty(), "Array cannot be empty")
	var random_index = _maze_rng.randi() % array.size()
	return array.pop_at(random_index)

func create_maze_BFS_tree(p:float) -> void:
	'''
	BFS, works sometimes
	'''
	add_border_walls()
	# bool array of whether each cell has been used, 2D flattened
	var cell_unused : PackedByteArray = PackedByteArray()
	cell_unused.resize(maze_size.x*maze_size.y)
	cell_unused.fill(true)
	# number of cell used, stop recursion if reaches N, equals number of false in cell_unused
	var num_cell_used : int = 1
	# create tree from (0,0)
	cell_unused[0] = false
	var leaves : Array[Vector2i] = [Vector2i(0,0)]
	
	while len(leaves)!=0 and (num_cell_used < (maze_size.x*maze_size.y)):
		var leaf = leaves.pop_front()
		var children_candidate = []
		var children = []
		if valid_index(leaf.x-1,leaf.y) and cell_unused[(leaf.x-1)*maze_size.y+leaf.y]:
			children_candidate.push_back(Vector2i(leaf.x-1,leaf.y))
		if valid_index(leaf.x,leaf.y-1) and cell_unused[leaf.x*maze_size.y+leaf.y-1]:
			children_candidate.push_back(Vector2i(leaf.x,leaf.y-1))
		if valid_index(leaf.x+1,leaf.y) and cell_unused[(leaf.x+1)*maze_size.y+leaf.y]:
			children_candidate.push_back(Vector2i(leaf.x+1,leaf.y))
		if valid_index(leaf.x,leaf.y+1) and cell_unused[leaf.x*maze_size.y+leaf.y+1]:
			children_candidate.push_back(Vector2i(leaf.x,leaf.y+1))
		if len(children_candidate)!=0:
			# first one with probability 1
			children.push_back(pop_random(children_candidate))
			for i in range(len(children_candidate)):
				if _maze_rng.randf()<p:
					children.push_back(pop_random(children_candidate))
			num_cell_used += len(children)
		if valid_index(leaf.x-1,leaf.y) and cell_unused[(leaf.x-1)*maze_size.y+leaf.y]:
			if Vector2i(leaf.x-1,leaf.y) not in children:
				add_wall(leaf.x,leaf.y,false)
		if valid_index(leaf.x+1,leaf.y) and cell_unused[(leaf.x+1)*maze_size.y+leaf.y]:
			if Vector2i(leaf.x+1,leaf.y) not in children:
				add_wall(leaf.x+1,leaf.y,false)
		if valid_index(leaf.x,leaf.y-1) and cell_unused[(leaf.x)*maze_size.y+leaf.y-1]:
			if Vector2i(leaf.x,leaf.y-1) not in children:
				add_wall(leaf.x,leaf.y-1,true)
		if valid_index(leaf.x,leaf.y+1) and cell_unused[(leaf.x)*maze_size.y+leaf.y+1]:
			if Vector2i(leaf.x,leaf.y+1) not in children:
				add_wall(leaf.x,leaf.y+1,true)
		for c in children:
				cell_unused[c.x*maze_size.y+c.y] = false
				leaves.push_back(c)
				
func create_maze_Prim() -> void:
	'''
	Prim algorithm, delete walls, always work
	'''
	add_all_walls()
	# in_maze, here "maze" refer to the current partially constructed maze
	var in_maze: PackedByteArray = PackedByteArray()
	in_maze.resize(maze_size.x * maze_size.y)
	in_maze.fill(false)
	# Frontier list (cells adjacent to maze)
	var frontier: Array[Vector2i] = []
	
	# Start with random cell
	var start_x = _maze_rng.randi() % maze_size.x
	var start_y = _maze_rng.randi() % maze_size.y
	var start_cell = Vector2i(start_x, start_y)
	in_maze[start_x * maze_size.y + start_y] = true
	
	# Add its neighbors to frontier
	for dir in neighbour_dir:
		var neighbor = start_cell + dir
		if valid_index(neighbor.x, neighbor.y) and not in_maze[neighbor.x * maze_size.y + neighbor.y]:
			if not frontier.has(neighbor):
				frontier.append(neighbor)
	
	# Main Prim's loop
	while not frontier.is_empty() and in_maze.has(false):
		var current = pop_random(frontier)
		
		var maze_neighbors: Array[Vector2i] = []
		for dir in neighbour_dir:
			var neighbor = current + dir
			if valid_index(neighbor.x, neighbor.y) and in_maze[neighbor.x * maze_size.y + neighbor.y]:
				maze_neighbors.push_back(neighbor)
		
		if not maze_neighbors.is_empty():
			# Connect to a random maze neighbor
			var connect_to = maze_neighbors[_maze_rng.randi() % maze_neighbors.size()]
			
			# Determine direction from connect_to to current and remove that wall
			var diff = current - connect_to
			if diff == neighbour_dir[0]:  # current is right of connect_to
				remove_wall(connect_to.x+1, connect_to.y, false)  # Right wall of connect_to
			elif diff == neighbour_dir[1]:  # current is left of connect_to
				remove_wall(connect_to.x, connect_to.y, false)  # Left wall of connect_to
			elif diff == neighbour_dir[2]:  # current is below connect_to
				remove_wall(connect_to.x, connect_to.y+1, true)  # Down wall of connect_to
			elif diff == neighbour_dir[3]:  # current is above connect_to
				remove_wall(connect_to.x, connect_to.y, true)  # Up wall of connect_to
			
			# Add current to maze
			in_maze[current.x * maze_size.y + current.y] = true
			
			# Add current's neighbors to frontier
			for dir in neighbour_dir:
				var neighbor = current + dir
				if valid_index(neighbor.x, neighbor.y) and not in_maze[neighbor.x * maze_size.y + neighbor.y]:
					if not frontier.has(neighbor):
						frontier.append(neighbor)

# Helper functions for union-find
func find(parent:PackedInt32Array, v: int) -> int:
	if parent[v] != v:
		parent[v] = find(parent, parent[v])
	return parent[v]

func union(parent:PackedInt32Array, v1: int, v2: int) -> void:
	var root1 = find(parent, v1)
	var root2 = find(parent, v2)
	if root1 != root2:
		parent[root2] = root1  # Simple union

func create_maze_Kruskal() -> void:
	'''
	Kruskal's algorithm: randomly remove walls that connect different sets
	Always creates a perfect maze (no cycles, all cells connected)
	'''
	add_all_walls()
	# Union-Find data structure for tracking connected components
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(maze_size.x * maze_size.y)
	for i in range(parent.size()):
		parent[i] = i  # Each cell starts as its own set
	# Collect internal walls
	var all_walls: Array = []
	for i in range(1,maze_size.x):
		for j in range(maze_size.y):
			if valid_index(i - 1, j) and valid_index(i, j):
				all_walls.append([i, j, false])
	for i in range(maze_size.x):
		for j in range(1,maze_size.y):
			if valid_index(i, j - 1) and valid_index(i, j):
				all_walls.append([i, j, true])
	# Shuffle internal walls
	for i in range(all_walls.size() - 1, 0, -1):
		var swap := _maze_rng.randi_range(0, i)
		var value = all_walls[i]
		all_walls[i] = all_walls[swap]
		all_walls[swap] = value
	for wall_data in all_walls:
		var x = wall_data[0]
		var y = wall_data[1]
		var is_horizontal = wall_data[2]
		
		# Determine which two cells this wall separates
		var cell1: Vector2i
		var cell2: Vector2i
		if is_horizontal:
			cell1 = Vector2i(x, y-1)
			cell2 = Vector2i(x, y)
		else:
			cell1 = Vector2i(x-1, y)
			cell2 = Vector2i(x, y)
		# Get indices in our flat array
		var idx1 = cell1.x * maze_size.y + cell1.y
		var idx2 = cell2.x * maze_size.y + cell2.y
		# If cells are in different sets, remove the wall and union them
		if find(parent,idx1) != find(parent,idx2):
			remove_wall(x, y, is_horizontal)
			union(parent,idx1, idx2)

func create_maze() -> void:
	#create_maze_BFS_tree(0.1)
	#create_maze_Prim()
	create_maze_Kruskal()
