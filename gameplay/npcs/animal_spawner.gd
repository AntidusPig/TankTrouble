extends Node2D

const ANIMAL := preload("res://gameplay/npcs/grass_animal.gd")
const MAX_ANIMALS := 4
var maze: MazeBuilder
var _spawn_delay := 1.0


func _physics_process(delta: float) -> void:
	_spawn_delay -= delta
	if _spawn_delay > 0.0:
		return
	_spawn_delay = 3.0
	if get_child_count() >= MAX_ANIMALS:
		return
	var graph := maze.maze_astar.astar
	var candidates := Array(graph.get_point_ids())
	for actor in get_tree().get_nodes_in_group("arena_tank") + get_children():
		var location := maze.to_local(actor.global_position)
		candidates.erase(graph.get_closest_point(location))
	if candidates.is_empty():
		return
	var animal := ANIMAL.new()
	animal.maze = maze
	animal.position = to_local(maze.to_global(graph.get_point_position(candidates.pick_random())))
	add_child(animal)
