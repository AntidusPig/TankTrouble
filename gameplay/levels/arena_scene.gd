extends Node2D

@export var maze_path: NodePath = ^"MazeBuilder"
const FLOOR_ART := preload("res://maze/illustrated_floor.gd")
const WALL_SCENE := preload("res://maze/wall/illustrated_wall.tscn")
const MATERIALS := preload("res://maze/maze_materials.gd")
const THEME_CATALOG := preload("res://gameplay/levels/arena_theme.gd")

var _hud_insets := Vector3.ZERO
var hud: ArenaHud


func _enter_tree() -> void:
	var builder := get_node(maze_path) as MazeBuilder
	var scene_mode := GameSession.SUDOKU_MODE if builder is MazeBuilderSudoku else GameSession.ARENA_MODE
	if scene_mode == GameSession.mode:
		builder.maze_size = Vector2i.ONE * GameSession.map_size
	if scene_mode == GameSession.ARENA_MODE:
		var stage := THEME_CATALOG.for_level(GameSession.level)
		builder.footprint = stage.footprint
		builder.wall_scene = WALL_SCENE
		builder.wall_material = MATERIALS.texture(MATERIALS.WALL, stage.material)
		builder.wall_trim = MATERIALS.TRIM[stage.material]
		builder.painted_cells = GameSession.custom_tiles
		if GameSession.single_arena:
			$WorldCommon/MenuUi.checkpoint_enabled = false
		var floor_art := FLOOR_ART.new()
		floor_art.name = "IllustratedFloor"
		floor_art.maze = builder
		floor_art.material_texture = MATERIALS.texture(MATERIALS.FLOOR, stage.material)
		builder.add_child(floor_art)
		if stage.backdrop != null:
			$WorldCommon/Background.texture = stage.backdrop


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_arena)
	_fit_arena()


func set_hud_insets(left: float, right: float, top: float) -> void:
	var insets := Vector3(left, right, top)
	_hud_insets = insets
	if is_node_ready():
		_fit_arena()


func _fit_arena() -> void:
	var builder := get_node(maze_path) as MazeBuilder
	var camera := $WorldCommon/MyCamera as MyCamera
	var map_size := (Vector2(builder.maze_size) * builder.grid_size + Vector2.ONE * builder.wall_thickness) * builder.global_scale.abs()
	var viewport_size := get_viewport_rect().size
	var content := Rect2(
		Vector2(_hud_insets.x, _hud_insets.z),
		viewport_size - Vector2(_hud_insets.x + _hud_insets.y, _hud_insets.z)
	)
	content = content.grow(-8.0)
	var fit := content.size / map_size
	var zoom_level := maxf(0.01, minf(fit.x, fit.y))
	var board_center := Vector2(content.get_center().x, content.position.y + map_size.y * zoom_level * 0.5)
	if is_instance_valid(hud):
		var board_extent := map_size * zoom_level
		hud.place_around_board(Rect2(board_center - board_extent * 0.5, board_extent))

	camera.zoom = Vector2.ONE * zoom_level
	camera.global_position = builder.global_position + (viewport_size * 0.5 - board_center) / zoom_level
	camera.force_update_scroll()
	camera.fit_background()
