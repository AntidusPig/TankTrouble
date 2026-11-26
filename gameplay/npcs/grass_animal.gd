extends CharacterBody2D

const ART := [
	preload("res://gameplay/npcs/art/animal-bunny.glb"),
	preload("res://gameplay/npcs/art/animal-dog.glb"),
	preload("res://gameplay/npcs/art/animal-fox.glb"),
]

var maze: MazeBuilder
var _goal := Vector2.ZERO
var _point_id := -1
var _previous_id := -1
var _wait := 0.0
var _life := 32.0
var _pace := 175.0
var _pivot: Node3D
var _step := 0.0


func _ready() -> void:
	add_to_group("arena_animal")
	z_as_relative = false
	z_index = 3
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var hitbox := CollisionShape2D.new()
	var body := CircleShape2D.new()
	body.radius = maze.grid_size * 0.17
	hitbox.shape = body
	add_child(hitbox)
	if DisplayServer.get_name() != "headless":
		_build_view()
	var graph := maze.maze_astar.astar
	_point_id = graph.get_closest_point(maze.to_local(global_position))
	_goal = global_position
	_pace = randf_range(0.65, 0.95) * maze.grid_size
	_life = randf_range(24.0, 38.0)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var displacement := _goal - global_position
	if displacement.length() <= 5.0:
		_wait = randf_range(0.15, 0.75)
		_pick_destination()
		return
	velocity = displacement.limit_length(_pace * delta) / delta
	move_and_slide()
	if get_slide_collision_count() > 0:
		# Reacquire the nearest corridor center before resuming the route.
		var graph := maze.maze_astar.astar
		_point_id = graph.get_closest_point(maze.to_local(global_position))
		_goal = maze.to_global(graph.get_point_position(_point_id))
	_step += delta * 18.0
	if _pivot != null:
		_pivot.position.y = absf(sin(_step)) * 0.12
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, atan2(velocity.x, velocity.y), minf(1.0, delta * 9.0))
	queue_redraw()


func _build_view() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_pivot.add_child(ART.pick_random().instantiate())
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	viewport.add_child(camera)
	camera.position = Vector3(1.8, 2.0, 2.5)
	camera.look_at(Vector3(0, 0.30, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 28, 0)
	light.light_energy = 1.4
	viewport.add_child(light)
	var environment := WorldEnvironment.new()
	var lighting := Environment.new()
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color.WHITE
	lighting.ambient_light_energy = 0.65
	environment.environment = lighting
	viewport.add_child(environment)
	var display := Sprite2D.new()
	display.texture = viewport.get_texture()
	display.scale = Vector2.ONE * maze.grid_size * 0.80 / viewport.size.x
	display.position.y = -6.0
	add_child(display)


func _pick_destination() -> void:
	var graph := maze.maze_astar.astar
	var links := Array(graph.get_point_connections(_point_id))
	if links.size() > 1:
		links.erase(_previous_id)
	if links.is_empty():
		return
	_previous_id = _point_id
	_point_id = links.pick_random()
	_goal = maze.to_global(graph.get_point_position(_point_id))


func _draw() -> void:
	draw_set_transform(Vector2(0, 20), 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, maze.grid_size * 0.18, Color(0.1, 0.08, 0.05, 0.28), true, -1, true)
