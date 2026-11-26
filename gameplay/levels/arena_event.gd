extends Node2D

const PARTICLES := preload("res://gameplay/vfx/cartoon_particles.gd")

enum Kind { NONE, STEAM, METEOR, FOUNTAIN }

var _maze: MazeBuilder
var _camera: MyCamera
const METEOR_FLASH := 0.72
var _tanks: Array[TankBase]
var kind: int
var _remaining := 4.0
var _warning := false
var _flash := 0.0
var _center := Vector2.ZERO
var _radius := 0.0
var _warning_time: float
var _impact_cells: Array[Vector2i] = []
var _flames := 0.0
var _ended := false


func setup(maze: MazeBuilder, tanks: Array[TankBase], event_kind: int, camera: MyCamera = null) -> void:
	_camera = camera
	_maze = maze
	_tanks = tanks
	kind = event_kind
	name = "ArenaEvent"
	z_index = 6
	_warning_time = 2.4 if kind == Kind.METEOR else 1.4


func _physics_process(delta: float) -> void:
	_flames = maxf(0.0, _flames - delta)
	if _ended:
		queue_redraw()
		if _flames == 0.0:
			queue_free()
		return
	_remaining -= delta
	_flash = maxf(0.0, _flash - delta)
	if _remaining <= 0.0:
		if _warning:
			_trigger()
		else:
			_mark_cell()
	queue_redraw()


func _mark_cell() -> void:
	var maze := _maze
	var cells := maze.maze_astar.astar.get_point_ids()
	var cell := cells[randi_range(0, cells.size() - 1)]
	_warn_at(Vector2i(cell % maze.maze_size.x, cell / maze.maze_size.x))


func _warn_at(target: Vector2i) -> void:
	var maze := _maze
	_center = to_local(maze.get_cell_position(target.x, target.y))
	if kind == Kind.METEOR:
		_impact_cells.clear()
		for y in range(target.y - 1, target.y + 2):
			for x in range(target.x - 1, target.x + 2):
				if maze.valid_index(x, y):
					_impact_cells.append(Vector2i(x, y))
	var radius_scale := 0.82 if kind == Kind.METEOR else 0.46
	_radius = maze.grid_size * absf(maze.global_scale.x) * radius_scale
	_warning = true
	_remaining = _warning_time


func _trigger() -> void:
	_warning = false
	_remaining = randf_range(6.0, 10.0)
	_flash = METEOR_FLASH if kind == Kind.METEOR else 0.4
	var tint := _tint()
	PARTICLES.emit(self, _center, tint, 65 if kind == Kind.METEOR else 30, _radius * 3.8)
	if kind == Kind.METEOR:
		_flames = 10.0
		_remaining = 10.0 + randf_range(2.0, 5.0)
		_clear_impact()
		PARTICLES.emit(self, _center, Color("#fff0a2"), 40, _radius * 5.6)
		if is_instance_valid(_camera):
			_camera.add_trauma(0.94)
			_camera.add_recoil(Vector2.UP)
	CartoonSound.play_at(CartoonSound.pop, to_global(_center), -10.0, 0.75 if kind == Kind.METEOR else 1.2)
	if kind == Kind.METEOR:
		return
	for tank in _tanks.duplicate():
		if not is_instance_valid(tank) or tank.pending_destroy:
			continue
		if tank.global_position.distance_to(to_global(_center)) > _radius:
			continue
		if kind == Kind.FOUNTAIN:
			tank.heal(1)
		else:
			tank.receive_damage(1)


func flame_seconds() -> float:
	return _flames


func end_round() -> void:
	_ended = true
	_warning = false


func _clear_impact() -> void:
	for tank in _tanks.duplicate():
		if is_instance_valid(tank) and not tank.pending_destroy and _impact_cells.has(_maze.cell_at(tank.global_position)):
			tank.destroy()
	for group in ["arena_pickup", "arena_animal", "arena_weapon_effect", "meteor_breakable"]:
		for actor in get_tree().get_nodes_in_group(group):
			if actor is not Node2D:
				continue
			var hit := _impact_cells.has(_maze.cell_at(actor.global_position))
			if actor.has_method("meteor_hits"):
				hit = actor.meteor_hits(_maze, _impact_cells)
			if hit:
				if actor.has_method("meteor_destroy"):
					actor.meteor_destroy()
				else:
					actor.queue_free()


func _tint() -> Color:
	match kind:
		Kind.STEAM: return Color("#ffe3aa")
		Kind.FOUNTAIN: return Color("#7ce8aa")
		_: return Color("#ff8d51")


func _draw() -> void:
	if kind == Kind.METEOR:
		_draw_impact_tiles()
		if _warning or _flash > 0.0 and not _ended:
			_draw_meteor()
		return
	if not _warning and _flash == 0.0:
		return
	var tint := _tint()
	draw_circle(_center, _radius, Color(tint, 0.23 if _warning else _flash), true, -1.0, true)
	draw_arc(_center, _radius, 0, TAU, 48, Color("#27191e"), 6.0, true)
	var progress := 1.0 - (_remaining / _warning_time) if _warning else 1.0
	draw_arc(_center, _radius, -PI / 2.0, TAU * progress - PI / 2.0, 48, tint, 4.0, true)
	if kind == Kind.FOUNTAIN:
		var size := _radius * 0.24
		draw_line(_center + Vector2.LEFT * size, _center + Vector2.RIGHT * size, Color("#ebffe7"), size * 0.5, true)
		draw_line(_center + Vector2.UP * size, _center + Vector2.DOWN * size, Color("#ebffe7"), size * 0.5, true)
	elif kind == Kind.STEAM:
		for jet in range(-1, 2):
			var nozzle := _center + Vector2(jet * _radius * 0.25, _radius * 0.16)
			var height := _radius * (0.24 + (1.0 - absf(jet)) * 0.16) * (1.0 + progress)
			draw_line(nozzle, nozzle + Vector2(-height * 0.25, -height), tint, _radius * 0.105, true)

func _draw_impact_tiles() -> void:
	if not _warning and _flames <= 0.0:
		return
	var side := _maze.grid_size * absf(_maze.global_scale.x)
	for cell in _impact_cells:
		var center := to_local(_maze.get_cell_position(cell.x, cell.y))
		var tile := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side).grow(-3.0)
		draw_rect(tile, Color(0.93, 0.18, 0.07, 0.26 if _warning else 0.36))
		draw_rect(tile, Color("#f59748"), false, 4.0)
		if _warning:
			continue
		for i in range(5):
			var flicker := 0.80 + 0.20 * sin(_flames * (8.0 + i) + i * 7.4)
			var foot := center + Vector2((i - 2.0) * 0.15, 0.18 + 0.14 * sin(i * 4.2)) * side
			var half := Vector2(side * 0.09, 0)
			var tip := foot + Vector2(sin(_flames * 8 + i) * 0.11, -0.30 * flicker) * side
			var flame := PackedVector2Array([foot - half, foot - half + Vector2(0, -0.13 * side), tip, foot + half])
			draw_colored_polygon(flame, Color(1.0, 0.34 + flicker * 0.25, 0.07, minf(1.0, _flames)))
			draw_colored_polygon(PackedVector2Array([foot - half * 0.52, tip.lerp(foot, 0.37), foot + half * 0.58]), Color(1, 0.83, 0.29, minf(1.0, _flames)))


func _draw_meteor() -> void:
	if _warning:
		var progress := clampf(1.0 - _remaining / _warning_time, 0, 1)
		var pulse := 0.5 + sin(progress * 31.0) * 0.5
		var danger := Color("#ff4932")
		draw_circle(_center, _radius, Color(danger, 0.29 + pulse * 0.20), true, -1, true)
		draw_arc(_center, _radius, 0, TAU, 64, Color("#351525"), 15.0, true)
		draw_arc(_center, _radius, 0, TAU, 64, Color("#ff6a34"), 7.0, true)
		draw_arc(_center, _radius, -PI * 0.5, TAU * progress - PI * 0.5, 64, Color("#fff284"), 8.0, true)
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var tip := _center + direction * (_radius * 0.68)
			var flank := direction.orthogonal() * (_radius * 0.12)
			var base := _center + direction * (_radius * 0.89)
			draw_colored_polygon(PackedVector2Array([tip, base + flank, base - flank]), Color("#fff193"))
		var tail_direction := Vector2(-0.65, -1).normalized()
		var travel := _radius * (0.4 + 2.6 * (1.0 - progress))
		var rock := _center + tail_direction * travel
		var tail := rock + tail_direction * (_radius * 1.04)
		var flank := tail_direction.orthogonal() * _radius
		var flame := PackedVector2Array([rock + flank * 0.25, tail + flank * 0.06, tail - flank * 0.09 - tail_direction * _radius * 0.17, tail - flank * 0.22, rock - flank * 0.23])
		draw_colored_polygon(flame, Color("#6e2334"))
		draw_colored_polygon(PackedVector2Array([rock + flank * 0.18, tail, rock - flank * 0.16]), Color("#ff782a"))
		draw_colored_polygon(PackedVector2Array([rock + flank * 0.085, tail.lerp(rock, 0.20), rock - flank * 0.087]), Color("#ffe983"))
		draw_circle(rock, _radius * 0.30, Color("#421d29"), true, -1, true)
		draw_circle(rock, _radius * 0.24, Color("#d56a4e"), true, -1, true)
		draw_circle(rock + Vector2(-0.07, -0.065) * _radius, _radius * 0.08, Color("#762d3a"), true, -1, true)
	else:
		var fade := _flash / METEOR_FLASH
		var expansion := 1.0 - fade
		draw_circle(_center, _radius * (0.80 + expansion * 0.55), Color(1, 0.54, 0.20, fade * 0.75), true, -1, true)
		draw_circle(_center, _radius * (0.36 + expansion * 0.38), Color(1, 0.93, 0.58, fade), true, -1, true)
		draw_arc(_center, _radius * (0.70 + expansion * 0.74), 0, TAU, 64, Color(1, 0.82, 0.42, fade), 11.0 * fade, true)
		for i in range(9):
			var direction := Vector2.from_angle(i * TAU / 9.0)
			var spark := _center + direction * (_radius * (0.28 + expansion * 1.15))
			draw_line(spark, spark + direction * _radius * 0.25, Color(1, 0.70, 0.37, fade), 7.0 * fade, true)
