@tool
class_name Shell extends Node2D

const PARTICLES := preload("res://gameplay/vfx/cartoon_particles.gd")

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var size : float = 14
@export var stats: ShellStats

var shell_direction : Vector2 = Vector2(0,1)
var pending_destroy : bool = false
var spawner : TankBase
var ignore_spawner : bool = true
var shot_color := Color("#f3bb5d")

func _ready():
	sprite_2d.hide()
	z_index = 7
	get_viewport().size_changed.connect(queue_redraw)
	# lifetime
	if not Engine.is_editor_hint():
		var timer = Timer.new()
		timer.wait_time = stats.shell_lifetime
		timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
		timer.one_shot = true
		timer.timeout.connect(_expire)
		add_child(timer)
		timer.start()
		
		# ignore initial spawner collision
		timer = Timer.new()
		timer.wait_time = 0.05  # TWEAK this in case of self collision
		timer.one_shot = true
		timer.timeout.connect(enable_spawner_collision)
		add_child(timer)
		timer.start()
	
	
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if is_queued_for_deletion(): return
	if pending_destroy:
		# handle_destruction_visuals 
		self_modulate.a = lerp(self_modulate.a, 0.0, delta * 2.0)
		scale = lerp(scale, Vector2(1.5,1.5), delta)
		return
		
	var movement_step = shell_direction * (stats.shell_speed * scale.x) * delta
	var space_state = get_world_2d().direct_space_state
	var ray_start = global_position
	var ray_end = global_position + movement_step

	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end, _collision_mask())
	# hitting from inside sudoku cell is possible
	query.hit_from_inside = true
	query.collide_with_areas = true  # sudoku cell
	query.collide_with_bodies = true # wall, tank
	# Ignore tank for a short time
	if ignore_spawner and is_instance_valid(spawner):
		query.exclude = [spawner.get_rid()]
	var result = space_state.intersect_ray(query)

	if result:
		var is_inside : bool = result.position.is_equal_approx(ray_start)
		var should_move: bool = _handle_collision(result, is_inside)
		if should_move:
			global_position += movement_step
	else:
		global_position += movement_step

func _collision_mask() -> int:
	return 0xffffffff


# [VIRTUAL]
func _handle_collision(result:Dictionary, _is_inside:bool) -> bool:
	'''
		return whether you should move forward
	'''
	if result.collider.has_method("shell_hit"):
		result.collider.shell_hit()
		destroy(true)
		return false
	if stats.blast_radius > 0.0:
		_detonate(result.position + result.normal * 2.0, result.collider)
		return false
	var collider = result.collider
	if collider is TankBase:
		collider.receive_damage(stats.shell_damage)
		destroy(true) # Instant destroy on hit
	# wall
	else:
		_bounce(result)
	return false

func _bounce(result: Dictionary) -> void:
	var normal = result.normal
	shell_direction = shell_direction.bounce(normal)
	# Push out slightly to prevent getting stuck inside the collider
	global_position = result.position + normal * 2.0

func _expire() -> void:
	if pending_destroy or is_queued_for_deletion():
		return
	if stats.blast_radius > 0.0:
		_detonate(global_position)
	else:
		destroy()


func _detonate(center: Vector2, direct_hit: Object = null) -> void:
	var blast_size := stats.blast_radius * absf(scale.x)
	var circle := CircleShape2D.new()
	circle.radius = blast_size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, center)
	var space := get_world_2d().direct_space_state
	var victims := {}
	if direct_hit is TankBase:
		victims[direct_hit] = true
	for overlap in space.intersect_shape(params, 64):
		var tank := overlap.collider as TankBase
		if tank == null or victims.has(tank):
			continue
		var sight := PhysicsRayQueryParameters2D.create(center, tank.global_position)
		var obstruction := space.intersect_ray(sight)
		if obstruction.is_empty() or obstruction.collider == tank:
			victims[tank] = true
	for tank in victims:
		tank.receive_damage(stats.shell_damage)

	var parent := get_parent() as Node2D
	PARTICLES.emit(parent, parent.to_local(center), Color("#ffb144"), 28, blast_size * 2.3)
	var flash := WeaponFlash.new()
	flash.position = parent.to_local(center)
	flash.blast_radius = blast_size
	flash.z_index = 8
	flash.add_to_group("arena_weapon_effect")
	parent.add_child.call_deferred(flash)
	destroy(true)


func destroy(immediate:bool=false) -> void:
	if pending_destroy or is_queued_for_deletion():
		return
	if immediate: queue_free()
	else:
		pending_destroy = true
		var timer = Timer.new()
		timer.wait_time = 0.5
		timer.one_shot = true
		timer.timeout.connect(queue_free)
		add_child(timer)
		timer.start()
	
func enable_spawner_collision() -> void:
	ignore_spawner = false

func _draw() -> void:
	var zoom := maxf(0.01, get_global_transform_with_canvas().get_scale().abs().x)
	var shell_radius := maxf(size * 0.5, 5.5 / zoom)
	var rim := 1.3 / zoom
	var core := shot_color.lerp(Color.WHITE, 0.39)
	draw_circle(Vector2.ZERO, shell_radius, Color("#251825"), true, -1, true)
	draw_circle(Vector2.ZERO, shell_radius - rim, core, true, -1, true)
	draw_circle(Vector2(-0.25, -0.29) * shell_radius, shell_radius * 0.21, Color("#fff8dc"), true, -1, true)
