extends Node2D

const THEME := preload("res://gameplay/levels/arena_theme.gd")
const BARREL := preload("res://gameplay/levels/items/factory_barrel.gd")
const PARTICLES := preload("res://gameplay/vfx/cartoon_particles.gd")

var maze: MazeBuilder
var mode: int
var _belt: Array[Vector2i] = []
var _belt_direction := Vector2.RIGHT
var _belt_bounds := Rect2()
var _well := Vector2i(-1, -1)
var _buds: Dictionary[Vector2i, float] = {}
var _age := 0.0


func _ready() -> void:
	z_index = -4
	if mode == THEME.Items.FACTORY:
		_prepare_belt()


func _prepare_belt() -> void:
	for y in range(maze.maze_size.y):
		var run: Array[Vector2i] = []
		for x in range(maze.maze_size.x):
			if not maze.valid_index(x, y):
				run.clear()
				continue
			run.append(Vector2i(x, y))
			if run.size() > _belt.size() or (run.size() == _belt.size() and abs(y - maze.maze_size.y / 2) < abs(_belt[0].y - maze.maze_size.y / 2)):
				_belt.assign(run)
	if _belt.size() < 2:
		_belt.clear()
		return
	for i in range(1, _belt.size()):
		maze.remove_inner_wall_between(_belt[i - 1], _belt[i])
	_belt_direction = Vector2.RIGHT if randi() % 2 == 0 else Vector2.LEFT
	var span := maze.grid_size
	var first := _center(_belt.front())
	var last := _center(_belt.back())
	_belt_bounds = Rect2(first - Vector2(span * 0.44, span * 0.40), last - first + Vector2(span * 0.88, span * 0.80))


func populate(free_cells: Array[Vector2i]) -> void:
	match mode:
		THEME.Items.FACTORY:
			for cell in _belt:
				free_cells.erase(cell)
			free_cells.shuffle()
			for i in range(mini(4, free_cells.size())):
				var barrel := BARREL.new()
				barrel.maze = maze
				barrel.cell = free_cells[i]
				barrel.position = _center(barrel.cell)
				add_child(barrel)
		THEME.Items.MOON:
			if not free_cells.is_empty():
				var middle := Vector2(maze.maze_size - Vector2i.ONE) * 0.5
				free_cells.sort_custom(func(a: Vector2i, b: Vector2i): return Vector2(a).distance_squared_to(middle) < Vector2(b).distance_squared_to(middle))
				_well = free_cells[0]
		THEME.Items.FOREST:
			free_cells.shuffle()
			for i in range(mini(3, free_cells.size())):
				_buds[free_cells[i]] = 0.0
	queue_redraw()


func reserved(cell: Vector2i) -> bool:
	for barrel in get_children():
		if barrel.is_in_group("factory_barrel") and not barrel.spent and barrel.cell == cell:
			return true
	return false


func motion_for(world_position: Vector2) -> Vector2:
	var point := to_local(world_position)
	if mode == THEME.Items.FACTORY and _belt_bounds.has_point(point):
		return _belt_direction * 118.0
	if _well.x >= 0 and _well_active():
		var pull := _center(_well) - point
		var range_limit := maze.grid_size * 1.16
		if pull.length() < range_limit:
			return pull.normalized() * 145.0 * clampf(pull.length() / 35.0, 0.0, 1.0)
	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	_age += delta
	for cell in _buds:
		if _buds[cell] > 0.0:
			_buds[cell] = maxf(0.0, _buds[cell] - delta)
			continue
		for actor in get_tree().get_nodes_in_group("arena_tank"):
			if actor is TankBase and not actor.pending_destroy and to_local(actor.global_position).distance_to(_center(cell)) < 39.0 and actor.add_shield(2):
				_buds[cell] = 12.0
				PARTICLES.emit(self, _center(cell), Color("#d8ff9e"), 24, 135.0)
				CartoonSound.play_at(CartoonSound.pickup, actor.global_position, -13.0, 1.2)
				break
	queue_redraw()


func _well_active() -> bool:
	return fmod(_age, 7.0) >= 3.0


func _center(cell: Vector2i) -> Vector2:
	return to_local(maze.get_cell_position(cell.x, cell.y))


func _draw() -> void:
	if not _belt.is_empty():
		_draw_belt()
	if _well.x >= 0:
		_draw_well()
	for cell in _buds:
		_draw_bud(_center(cell), _buds[cell] == 0.0)


func _draw_belt() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#352e35")
	frame.border_color = Color("#211a24")
	frame.set_border_width_all(5)
	frame.set_corner_radius_all(17)
	draw_style_box(frame, _belt_bounds)
	var track := _belt_bounds.grow(-9.0)
	for sign_value: int in [-1, 1]:
		var y := track.get_center().y + sign_value * track.size.y * 0.40
		draw_line(Vector2(track.position.x, y), Vector2(track.end.x, y), Color("#dda95d"), 5.0, true)
	var scroll := fposmod(_age * 118.0 * _belt_direction.x, 38.0)
	var center_y := track.get_center().y
	for i in range(ceili(track.size.x / 38.0)):
		var x := track.position.x + 16.0 + scroll + i * 38.0
		if x > track.end.x - 16.0:
			continue
		draw_line(Vector2(x, track.position.y + 17), Vector2(x, track.end.y - 17), Color("#5e5960"), 4.0, true)
		var tip := Vector2(x + _belt_direction.x * 10.0, center_y)
		draw_polyline(PackedVector2Array([tip + Vector2(-_belt_direction.x * 16, -13), tip, tip + Vector2(-_belt_direction.x * 16, 13)]), Color("#f2cc73"), 5.0, true)
	for x in [_belt_bounds.position.x + 13, _belt_bounds.end.x - 13]:
		for y in [_belt_bounds.position.y + 14, _belt_bounds.end.y - 14]:
			draw_circle(Vector2(x, y), 6.0, Color("#d99a59"), true, -1, true)


func _draw_well() -> void:
	var point := _center(_well)
	var active := _well_active()
	var tint := Color("#79e9fb") if active else Color("#6ba4b7")
	draw_circle(point, 40.0, Color("#242540"), true, -1, true)
	draw_arc(point, 36.0, 0, TAU, 40, tint, 4.0, true)
	for i in range(3):
		var phase := fposmod(_age * 1.8 + float(i) / 3.0, 1.0)
		if active:
			draw_arc(point, lerpf(24.0, maze.grid_size * 1.13, 1.0 - phase), 0, TAU, 48, Color(tint, 0.46 * phase), 3.5, true)
		draw_arc(point, 11.0 + i * 6.0, _age * (2.0 + i), _age * (2.0 + i) + PI * 1.4, 24, tint, 3.0, true)


func _draw_bud(point: Vector2, blooming: bool) -> void:
	var ink := Color("#3d3032")
	draw_circle(point + Vector2(3, 6), 27.0, Color(0.17, 0.09, 0.08, 0.32), true, -1, true)
	for i in range(5):
		var petal := point + Vector2.from_angle(i * TAU / 5.0) * (17.0 if blooming else 10.0)
		draw_circle(petal, 14.0, ink, true, -1, true)
		draw_circle(petal, 11.0, Color("#edaa60") if blooming else Color("#65936b"), true, -1, true)
	draw_circle(point, 15.0, ink, true, -1, true)
	draw_circle(point, 11.0, Color("#f6e5a0") if blooming else Color("#456f51"), true, -1, true)
	if blooming:
		draw_polyline(PackedVector2Array([point + Vector2(-5,0), point + Vector2(-2,4), point + Vector2(6,-4)]), ink, 3.0, true)
