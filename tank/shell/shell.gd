@tool
class_name Shell extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var ray_cast_2d: RayCast2D = $RayCast2D

@export var size : float = 14
@export var shell_speed : float = 600.
@export var shell_damage : int = 1
@export var shell_lifetime : float = 5.

var shell_direction : Vector2 = Vector2(0,1)
var pending_destroy : bool = false
var spawner : TankBase
var ignore_spawner : bool = true

func _ready():
	# Create a new image with transparency
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center = Vector2(size/2, size/2)
	var radius = size/2 - 2
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
	
	# lifetime
	var timer = Timer.new()
	timer.wait_time = shell_lifetime
	timer.one_shot = true
	timer.timeout.connect(destroy)
	add_child(timer)
	timer.start()
	
	# ignore initial spawner collision
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(enable_spawner_collision)
	add_child(timer)
	timer.start()
	
func _process(delta) -> void:
	position += shell_direction * shell_speed * delta
	if pending_destroy:
		sprite_2d.modulate.a = lerp(sprite_2d.modulate.a, 0., delta*2)
		scale = lerp(scale, Vector2(1.5,1.5), delta)
	ray_cast_2d.target_position = shell_direction.normalized() * size
	if ray_cast_2d.is_colliding():
		var other = ray_cast_2d.get_collider()
		if other is TankBase and not pending_destroy and not(ignore_spawner and other == spawner):
			other.receive_damage(shell_damage)
			destroy(true)
		else:
			var normal = ray_cast_2d.get_collision_normal()
			shell_direction = shell_direction.bounce(normal)
			global_position += normal * size * 2
		
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
