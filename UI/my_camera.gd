class_name MyCamera extends Camera2D

var trauma = 0.0
var trauma_power = 2 # 2 or 3 is good
var max_roll = 0.1 # Max rotation in radians
var max_offset = Vector2(2, 2) # Max displacement

# camera offset
@export var offset_distance: float = 20.0 # How far the camera "peers" ahead
@export var offset_speed: float = 2.0    # How fast it slides (lower = floatier)
var target_offset: Vector2 = Vector2.ZERO
@onready var background: Sprite2D = $"../Background"
@export var bg_parallax_factor: float = 0.5

func _process(delta):
	offset = offset.lerp(target_offset, delta * offset_speed)
	
	if trauma > 0:
		trauma = max(trauma - delta, 0.0) # Decay over time
		_shake()
	
	if background:
		background.position = -offset * bg_parallax_factor

func _shake():
	var amount = pow(trauma, trauma_power)
	rotation = max_roll * amount * randf_range(-1, 1)
	offset.x = max_offset.x * amount * randf_range(-1, 1)
	offset.y = max_offset.y * amount * randf_range(-1, 1)

func add_trauma(amount):
	trauma = min(trauma + amount, 1.0)
	
func apply_offset(velocity_normalized: Vector2):
	target_offset = velocity_normalized * offset_distance
