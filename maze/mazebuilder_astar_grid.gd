class_name MazeAStar extends Node2D

var astar := AStar2D.new()
@export var show_debug := false
@onready var offset: Node2D = $"../offset"
@onready var maze_builder: MazeBuilder = $".."

func get_cell_id(x: int, y: int) -> int:
	return x + (y * maze_builder.maze_size.x)
	
func setup_astar_points() -> void:
	astar.clear()
	for x in range(maze_builder.maze_size.x):
		for y in range(maze_builder.maze_size.y):
			if not maze_builder.valid_index(x, y):
				continue
			var id = get_cell_id(x, y)
			var cell_center = (Vector2(x, y) * maze_builder.grid_size) + Vector2(maze_builder.grid_size / 2.0, maze_builder.grid_size / 2.0) + offset.position
			astar.add_point(id, cell_center)
		
func connect_cells_with_wall(x1: int, y1: int, x2: int, y2: int) -> void:
	var id1 = get_cell_id(x1, y1)
	var id2 = get_cell_id(x2, y2)
	if not astar.are_points_connected(id1, id2):
		astar.connect_points(id1, id2)

func get_global_enemy_path(start_pos: Vector2, target_pos: Vector2) -> PackedVector2Array:
	var start_id = astar.get_closest_point(maze_builder.to_local(start_pos))
	var target_id = astar.get_closest_point(maze_builder.to_local(target_pos))
	return local_2_global(astar.get_point_path(start_id, target_id))
	
func distances_from(positions: PackedVector2Array) -> Dictionary[int, int]:
	var distances: Dictionary[int, int] = {}
	var frontier: Array[int] = []
	for point in positions:
		var start := astar.get_closest_point(maze_builder.to_local(point))
		if start >= 0 and not distances.has(start):
			distances[start] = 0
			frontier.append(start)
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		for neighbor in astar.get_point_connections(current):
			if not distances.has(neighbor):
				distances[neighbor] = distances[current] + 1
				frontier.append(neighbor)
	return distances


func local_2_global(path:PackedVector2Array)-> PackedVector2Array:
	var global_path := PackedVector2Array()
	for local_point in path:
		global_path.append(maze_builder.to_global(local_point))
	return global_path
	
func global_2_local(path:PackedVector2Array)-> PackedVector2Array:
	var local_path := PackedVector2Array()
	for global_point in path:
		local_path.append(maze_builder.to_local(global_point))
	return local_path

### DEBUG ###
var debug_paths: Dictionary = {}

func add_debug_path(tank_name, path: PackedVector2Array, color: Color = Color.MEDIUM_SPRING_GREEN) -> void:
	debug_paths[tank_name] = {
		"color": color,
		"path": global_2_local(path)
	}

func _process(_delta: float) -> void:
	if show_debug:
		queue_redraw()

func _draw() -> void:
	if not show_debug or not astar:
		return
	for point_id in astar.get_point_ids():
		var current_pos = astar.get_point_position(point_id)
		draw_circle(current_pos, 4.0, Color.CORNFLOWER_BLUE)
		var connections = astar.get_point_connections(point_id)
		for target_id in connections:
			var target_pos = astar.get_point_position(target_id)
			draw_line(current_pos, target_pos, Color(1, 0, 0, 0.25), 2.0)
			
	for path_id in debug_paths:
		var path_data = debug_paths[path_id]
		var points: PackedVector2Array = path_data.get("path", PackedVector2Array())
		var path_color: Color = path_data.get("color", Color.WHITE)
		if points.size() > 1:
			for i in range(points.size() - 1):
				draw_line(points[i], points[i+1], path_color, 4.0)
	debug_paths.clear()
