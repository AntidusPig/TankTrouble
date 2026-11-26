extends Node2D

@export var maze_path: NodePath = ^"MazeBuilder"


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_arena)
	_fit_arena()


func _fit_arena() -> void:
	var builder := get_node(maze_path) as MazeBuilder
	var camera := $WorldCommon/MyCamera as MyCamera
	var map_size := (Vector2(builder.maze_size) * builder.grid_size + Vector2.ONE * builder.wall_thickness) * builder.global_scale.abs()
	var viewport_size := get_viewport_rect().size
	var padding := Vector2.ONE * minf(64.0, minf(viewport_size.x, viewport_size.y) * 0.15)
	var fit := (viewport_size - padding) / map_size
	camera.zoom = Vector2.ONE * minf(fit.x, fit.y)
	camera.global_position = builder.global_position
	camera.force_update_scroll()
	camera.fit_background()
