extends StaticBody2D

const PARTICLES := preload("res://gameplay/vfx/cartoon_particles.gd")
var maze: MazeBuilder
var cell: Vector2i
var spent := false


func _ready() -> void:
	add_to_group("factory_barrel")
	add_to_group("meteor_breakable")
	collision_layer = 1 << 2
	collision_mask = 0
	z_index = 3
	var collider := CollisionShape2D.new()
	var hull := CircleShape2D.new()
	hull.radius = 29.0
	collider.shape = hull
	add_child(collider)


func shell_hit() -> void:
	if spent or not is_inside_tree():
		return
	spent = true
	var parent := get_parent() as Node2D
	if parent.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var burst := WeaponFlash.new()
	burst.position = position
	burst.blast_radius = maze.grid_size * 1.1
	burst.z_index = 10
	burst.add_to_group("arena_weapon_effect")
	parent.add_child.call_deferred(burst)
	PARTICLES.emit(parent, position, Color("#ffd266"), 48, 370.0)
	CartoonSound.play_at(CartoonSound.pop, global_position, -6.0, 0.61)
	_break_walls()
	for actor in get_tree().get_nodes_in_group("arena_tank"):
		if actor is TankBase and actor.global_position.distance_to(global_position) <= burst.blast_radius:
			actor.receive_damage(3)
	for barrel in get_tree().get_nodes_in_group("factory_barrel"):
		if barrel != self and not barrel.spent and barrel.global_position.distance_to(global_position) <= burst.blast_radius:
			barrel.shell_hit.call_deferred()
	queue_free()


func meteor_destroy() -> void:
	shell_hit()


func _break_walls() -> void:
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var from := Vector2i(x, y)
			for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other := from + side
				var midpoint := (maze.get_cell_position(from.x, from.y) + maze.get_cell_position(other.x, other.y)) * 0.5
				if midpoint.distance_to(global_position) <= maze.grid_size * 1.13:
					maze.remove_inner_wall_between(from, other)


func _draw() -> void:
	var ink := Color("#26202a")
	draw_set_transform(Vector2(4, 13), 0.0, Vector2(1.0, 0.48))
	draw_circle(Vector2.ZERO, 32.0, Color(0.11, 0.07, 0.09, 0.36), true, -1, true)
	draw_set_transform(Vector2.ZERO)
	var drum := StyleBoxFlat.new()
	drum.bg_color = Color("#a84336")
	drum.border_color = ink
	drum.set_border_width_all(4)
	drum.set_corner_radius_all(12)
	draw_style_box(drum, Rect2(-28, -34, 56, 65))
	for y in [-19.0, 17.0]:
		draw_line(Vector2(-27, y), Vector2(27, y), ink, 7.0, true)
		draw_line(Vector2(-25, y - 1), Vector2(25, y - 1), Color("#e5a66c"), 2.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-13), Vector2(13,11), Vector2(-13,11)]), Color("#ffd775"))
	draw_line(Vector2(0,-5), Vector2(0,4), ink, 3.0, true)
	draw_circle(Vector2(0,8), 1.7, ink)
