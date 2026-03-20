@tool
class_name Shell extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var size : float = 14
@export var shell_speed : float = 600.
@export var shell_damage : int = 1
@export var shell_lifetime : float = 5.

var shell_direction : Vector2 = Vector2(0,1)
var pending_destroy : bool = false
var spawner : TankBase
var ignore_spawner : bool = true
var radius : float

func _ready():
	# Create a new image with transparency
	create_shell_texture()
	# lifetime
	if not Engine.is_editor_hint():
		var timer = Timer.new()
		timer.wait_time = shell_lifetime
		timer.one_shot = true
		timer.timeout.connect(destroy)
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
	if pending_destroy:
		# handle_destruction_visuals 
		sprite_2d.modulate.a = lerp(sprite_2d.modulate.a, 0., delta*2)
		scale = lerp(scale, Vector2(1.5,1.5), delta)
		
	var movement_step = shell_direction * (shell_speed * scale.x) * delta
	var space_state = get_world_2d().direct_space_state
	var ray_start = global_position
	var ray_end = global_position + movement_step

	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collide_with_areas = true  # sudoku cell
	query.collide_with_bodies = true # wall, tank
	# Ignore tank for a short time
	if ignore_spawner and is_instance_valid(spawner):
		query.exclude = [spawner.get_rid()]
	var result = space_state.intersect_ray(query)

	if result:
		_handle_collision(result)
	else:
		global_position += movement_step

# [VIRTUAL]
func _handle_collision(result:Dictionary)->void:
	var collider = result.collider
	if collider is TankBase:
		collider.receive_damage(shell_damage)
		destroy(true) # Instant destroy on hit
		return
	# wall
	else:
		_bounce(result)

func _bounce(result: Dictionary) -> void:
	var normal = result.normal
	shell_direction = shell_direction.bounce(normal)
	# Push out slightly to prevent getting stuck inside the collider
	global_position = result.position + normal * 2.0

func destroy(immediate:bool=false) -> void:
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

func create_shell_texture() -> void:
	var image = Image.create(int(size), int(size), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center = Vector2(size/2, size/2)
	radius = size/2 - 2
	var samples = 4  # 4x4 supersampling for smooth edges
	for x in range(size):
		for y in range(size):
			var alpha_sum = 0.0
			# Sample multiple points within each pixel for better antialiasing
			for sx in range(samples):
				for sy in range(samples):
					# Subpixel offset
					var offset_x = (sx + 0.5) / samples - 0.5
					var offset_y = (sy + 0.5) / samples - 0.5
					var subpixel_pos = Vector2(x + offset_x, y + offset_y)
					var dist = subpixel_pos.distance_to(center)
					if dist <= radius:
						alpha_sum += 1.0
						# Average the samples to get final alpha
						var alpha = alpha_sum / (samples * samples)
						if alpha > 0:
							image.set_pixel(x, y, Color(0, 0, 0, alpha))
	var texture = ImageTexture.create_from_image(image)
	sprite_2d.texture = texture
