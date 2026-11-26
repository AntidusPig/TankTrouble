class_name LevelManager extends Node2D

@export var PLAYER_TANK_SCENE: PackedScene = preload("uid://csgjg5qdylx7w")
@export var TANK_SCENE: PackedScene = preload("uid://csgjg5qdylx7w")
@export var ENEMY_TANK_SCENE: PackedScene = preload("uid://djlo0siowsb36")
# Default shell, can be overridden by children
@export var DEFAULT_SHELL: Resource = preload("uid://dqmmo6iiwmn8g") 

var maze_builder: MazeBuilder
var tanks: Array[TankBase] = []
var player_tanks: Array[TankPlayer] = []
var enemy_tanks: Array[TankBase] = []
@onready var camera: MyCamera = $"../WorldCommon/MyCamera"

@export var player_spawn_pos = Vector2i(0,0)
@export var number_of_enemies : int = 1
var used_pos: Array[Vector2i] = [player_spawn_pos]
@onready var navigation_region_2d: MazeNavRegion = $"../WorldCommon/NavigationRegion2D"

func _ready() -> void:
	setup_maze()
	spawn_player()
	await get_tree().process_frame
	navigation_region_2d.bake_maze_navigation()

func setup_maze() -> void:
	var nodes = get_tree().get_nodes_in_group("MazeBuilder")
	if nodes.size() > 0:
		maze_builder = nodes[0] as MazeBuilder
	navigation_region_2d.bake_finished.connect(_on_navmesh_bake_finished)

func spawn_player() -> void:
	if not maze_builder: return
	var player_tank : TankPlayer = add_tank(PLAYER_TANK_SCENE, player_spawn_pos.x, player_spawn_pos.y)
	player_tanks.push_back(player_tank)
	_on_player_spawned(player_tank)
	
func spawn_enemy() -> void:
	var new_pos = Vector2i(max(2, randi() % maze_builder.maze_size.x), max(2, randi() % maze_builder.maze_size.y))
	while new_pos in used_pos:
		new_pos = Vector2i(max(2, randi() % maze_builder.maze_size.x), max(2, randi() % maze_builder.maze_size.y))
	used_pos.append(new_pos)
	var enemy_tank : TankBase = add_tank(ENEMY_TANK_SCENE, new_pos.x, new_pos.y)
	enemy_tanks.push_back(enemy_tank)

func add_tank(tank_asset:PackedScene, posx:int, posy:int)-> TankBase:
	var tank : TankBase = tank_asset.instantiate()
	tank.SHELL_SCENE = get_shell_resource()
	tank.scale = maze_builder.scale
	tank.position = to_local(maze_builder.get_cell_position(posx, posy))
	add_child(tank)
	tanks.push_back(tank)
	return tank

# Virtual methods for children to override
func get_shell_resource() -> Resource:
	return DEFAULT_SHELL

# Virtual
func _on_player_spawned(tank: TankPlayer) -> void:
	if camera:
		tank.shoot_signal.connect(func(_p, direction): camera.add_recoil(direction))
		tank.damaged_signal.connect(func(_hp): camera.add_trauma(0.5))

func _on_navmesh_bake_finished() -> void:
	for i in range(number_of_enemies):
		spawn_enemy()
