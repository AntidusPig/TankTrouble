extends Node2D

const PARTICLES := preload("res://gameplay/vfx/cartoon_particles.gd")
const LIFETIME := 10.0
const ARM_DELAY := 0.40

var entrance: Vector2
var exit: Vector2
var muzzle: Vector2
var tracer_end: Vector2
var radius := 30.0
var arena: Node
var _age := 0.0


func _ready() -> void:
	z_index = 9
	add_to_group("arena_weapon_effect")
	PARTICLES.emit(self, entrance, Color("#4ce9ff"), 22, 190.0)
	PARTICLES.emit(self, exit, Color("#ffb14d"), 22, 190.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()
	if _age < ARM_DELAY:
		return
	for tank: TankBase in arena.tanks:
		if not is_instance_valid(tank) or tank.pending_destroy or is_instance_valid(tank.laser_beam):
			continue
		var spot := to_local(tank.global_position)
		if spot.distance_to(entrance) <= radius and _try_pass(tank, exit):
			return
		if spot.distance_to(exit) <= radius and _try_pass(tank, entrance):
			return


func _try_pass(tank: TankBase, destination: Vector2) -> bool:
	for rival: TankBase in arena.tanks:
		if is_instance_valid(rival) and rival != tank and not rival.pending_destroy and rival.global_position.distance_to(to_global(destination)) < arena.maze_builder.grid_size * 0.72:
			return false
	tank.global_position = to_global(destination)
	tank.velocity = Vector2.ZERO
	PARTICLES.emit(get_parent(), destination, Color("#f8d79c"), 28, 220.0)
	CartoonSound.play_at(CartoonSound.pop, tank.global_position, -9.0, 1.6)
	queue_free()
	return true


func meteor_hits(maze: MazeBuilder, cells: Array[Vector2i]) -> bool:
	return cells.has(maze.cell_at(to_global(entrance))) or cells.has(maze.cell_at(to_global(exit)))


func _draw() -> void:
	if _age < 0.24:
		draw_line(muzzle, tracer_end, Color(0.38, 0.96, 1.0, 1.0 - _age / 0.24), 8.0, true)
	_draw_gate(entrance, Color("#4ce9ff"))
	_draw_gate(exit, Color("#ffab45"))


func _draw_gate(point: Vector2, tint: Color) -> void:
	var wave := 1.0 + sin(_age * 13.0) * 0.08
	draw_circle(point, radius * wave, Color("#241733"), true, -1, true)
	draw_circle(point, radius * 0.86 * wave, Color(tint, 0.78), false, 7.0, true)
	draw_arc(point, radius * 0.63, _age * 4.0, _age * 4.0 + PI * 1.3, 28, Color("#fff1cd"), 4.0, true)
