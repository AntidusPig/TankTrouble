class_name TankAI extends TankBase

@export var player: TankPlayer # Assign your player tank here
@onready var maze_builder: MazeBuilder = $"../../MazeBuilder"
@onready var maze_astar: MazeAStar = maze_builder.maze_astar

enum State { IDLE, HUNT, ATTACK }
var current_state = State.IDLE

var current_path: PackedVector2Array = []
var target_threshold: float = 4.0
var is_turning: bool = true
var target_pixel_pos: Vector2
@onready var preferred_distance_to_player: float = 2.0*maze_builder.grid_size

func get_next_path_points(target_position: Vector2) -> PackedVector2Array:
	return maze_astar.get_global_enemy_path(global_position, target_position)

func tactical_target_selection()-> Vector2:
	# Find a good spot to shoot the player
	# Calculate the path distance to player through the maze
	return player.global_position
	if not player: return global_position
	var target_pos: Vector2 = player.global_position
	var path_to_player: PackedVector2Array = get_next_path_points(target_pos)
	var distance_to_player: float = 0.0
	if path_to_player.size() > 1:
		for i in range(path_to_player.size() - 1):
			distance_to_player += path_to_player[i].distance_to(path_to_player[i+1])
	else:
		distance_to_player = global_position.distance_to(player.global_position)
	# comfort zone
	var upper_threshold = preferred_distance_to_player + (maze_builder.grid_size * .5)
	var lower_threshold = preferred_distance_to_player - (maze_builder.grid_size * .2)
	if distance_to_player < lower_threshold:
		var away_dir = (global_position - player.global_position).normalized()
		target_pos = global_position + (away_dir * maze_builder.grid_size * 2)
	elif distance_to_player > upper_threshold:
		# PLAYER IS TOO FAR: Advance!
		target_pos = player.global_position
	else:
		# PERFECT DISTANCE: Hold position at the closest cell center, but keep tracking combat/aiming
		target_pos = global_position
	return target_pos
	
func _physics_process(delta: float) -> void:
	current_path = get_next_path_points(tactical_target_selection())
	maze_astar.add_debug_path(name, current_path)
	
	# move to player
	if current_path.size() <= 1:
		velocity = Vector2.ZERO
		_handle_combat(delta)
		return
	var next_milestone_pos = current_path[1]
	if global_position.distance_to(current_path[0]) < target_threshold:
		global_position = current_path[0] 
		var incoming_angle = (next_milestone_pos - global_position).angle()
		if abs(angle_difference(rotation, incoming_angle)) > 0.05:
			is_turning = true
	var desired_angle = (next_milestone_pos - global_position).angle()
	if is_turning:
		velocity = Vector2.ZERO 
		rotation = lerp_angle(rotation, desired_angle, delta * rotate_speed)
		if abs(angle_difference(rotation, desired_angle)) < 0.005:
			rotation = desired_angle 
			is_turning = false
	else:
		velocity = Vector2.from_angle(rotation) * move_speed
	move_and_slide()
	#_handle_combat(delta)

### Firing prediction ###
@export var max_bullet_bounces: int = 2

func _handle_combat(delta: float) -> void:
	# Rotate Turret toward player cleanly as default tracking
	
	
	# AMBUSH CHECK: Try to find a direct or bouncing shot path
	var firing_angle = _find_valid_trick_shot()
	
	if firing_angle != -100.0: # Our custom flag meaning "Valid shot found!"
		# Override turret rotation to lock onto the precise trick-shot angle
		rotation = lerp_angle(rotation, firing_angle, delta * rotate_speed)
		if abs(angle_difference(rotation, firing_angle)) < 0.05:
			shoot()
	#else:
		#var dir_to_player = (player.global_position - global_position).angle()
		#rotation = lerp_angle(rotation, dir_to_player, delta * rotate_speed)
			
func _find_valid_trick_shot() -> float:
	var space_state = get_world_2d().direct_space_state
	
	# Calculate how far a bullet can physically travel before it despawns
	var max_bullet_distance = shell_stats.shell_speed * shell_stats.shell_lifetime
	
	# We will scan in a circle around the tank (e.g., every 5 or 10 degrees)
	# to see if any angle results in a hit on the player
	var angle_step = deg_to_rad(10.0) 
	
	for i in range(36):
		var test_angle = i * angle_step
		var ray_origin = global_position
		var ray_dir = Vector2.from_angle(test_angle)
		var distance_remaining = max_bullet_distance
		
		# Account for player movement: predict where they will be by the time the bullet reaches them
		var test_target_pos = player.global_position + (player.velocity * 0.15) 
		
		for bounce in range(max_bullet_bounces + 1):
			var ray_query = PhysicsRayQueryParameters2D.create(
				ray_origin, 
				ray_origin + (ray_dir * distance_remaining)
			)
			# Don't let the raycast hit the shooting tank itself
			ray_query.exclude = [self.get_rid()] 
			
			var result = space_state.intersect_ray(ray_query)
			
			if result:
				var hit_collider = result.collider
				var hit_pos = result.position
				var hit_normal = result.normal
				
				# Deduct the distance covered by this leg of the bounce
				distance_remaining -= ray_origin.distance_to(hit_pos)
				if distance_remaining <= 0:
					break
				
				# Check if we hit the player tank!
				if hit_collider == player or hit_collider.get_parent() == player:
					return test_angle # Found it! Return the initial angle to fire at
					
				# If we hit a solid wall, calculate the perfect mirror reflection angle vector
				ray_origin = hit_pos + (hit_normal * 0.1) # Offset slightly to prevent stuck rays
				ray_dir = ray_dir.bounce(hit_normal).normalized()
			else:
				# The ray completed its full distance without hitting a solid wall structure
				# Quick proximity check to see if it passed close enough to the player at its tail end
				var final_segment_end = ray_origin + (ray_dir * distance_remaining)
				var distance_to_player_line = Geometry2D.get_closest_point_to_segment(test_target_pos, ray_origin, final_segment_end).distance_to(test_target_pos)
				
				if distance_to_player_line < 32.0: # Adjust based on player tank hit-radius
					return test_angle
				break
				
	return -100.0 # No valid direct or bouncing shot detected this frame
