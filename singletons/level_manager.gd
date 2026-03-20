class_name LevelManager extends Node2D

const TANK_SCENE = preload("uid://csgjg5qdylx7w")
const SHELL_SCENE = preload("uid://dqmmo6iiwmn8g") # normal shell
var maze_builder : MazeBuilder
var tanks : Array[TankBase] = []
var player_tanks : Array[TankPlayer] = []

func _ready() -> void:
	var nodes = get_tree().get_nodes_in_group("MazeBuilder")
	if nodes.size() > 0:
		maze_builder = nodes[0] as MazeBuilder
		
	var player_tank : TankBase = TANK_SCENE.instantiate()
	add_child(player_tank)
	player_tank.SHELL_SCENE = SHELL_SCENE
	player_tank.scale = maze_builder.scale
	player_tank.global_position = maze_builder.get_cell_position(0,0)
	tanks.push_back(player_tank)
	player_tanks.push_back(player_tank)
