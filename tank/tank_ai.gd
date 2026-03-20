class_name TankAI extends TankBase

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@export var player: TankPlayer # Assign your player tank here

enum State { IDLE, HUNT, ATTACK }
var current_state = State.IDLE

func _ready():
	# Wait for the first frame so the NavMesh is fully loaded
	call_deferred("actor_setup")

func actor_setup():
	await get_tree().physics_frame
	set_movement_target(player.global_position)

func set_movement_target(target: Vector2):
	nav_agent.target_position = target

func _physics_process(delta):
	if nav_agent.is_navigation_finished():
		return

	# 1. PATHFINDING
	var current_pos = global_position
	var next_path_pos = nav_agent.get_next_path_position()
	
	# Calculate direction to the next point in the NavMesh
	var new_velocity = (next_path_pos - current_pos).normalized() * move_speed
	
	# 2. STEERING (Smooth Rotation)
	if new_velocity.length() > 0:
		var target_angle = new_velocity.angle()
		rotation = lerp_angle(rotation, target_angle, delta * 5.0)
		
	# 3. MOVEMENT
	velocity = new_velocity
	move_and_slide()
	
	# 4. TARGETING LOGIC
	_handle_combat(delta)

func _handle_combat(delta):
	# Update target position to follow player
	set_movement_target(player.global_position)
	
	#var prediction_time = 0.5
	#var predicted_pos = player.global_position + (player.velocity * prediction_time)
	#nav_agent.target_position = predicted_pos
	
	# Rotate Turret toward player
	var dir_to_player = (player.global_position - global_position).angle()
	rotation = lerp_angle(rotation, dir_to_player, delta * 4.0)
	
	# Check Line of Sight before shooting
	if _has_line_of_sight():
		shoot() # Call your base TankBase shoot function

func _has_line_of_sight() -> bool:
	return false
