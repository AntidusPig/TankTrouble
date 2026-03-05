class_name TankPlayer extends TankBase

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Attack"):
		shoot()

func _physics_process(delta: float) -> void:
	super(delta)
	if pending_destroy:return
	moving = false
	velocity = Vector2(0,0)
	var forward_direction = get_forward()
	if Input.is_action_pressed("Up"):
		velocity = forward_direction * move_speed
		moving = true
	if Input.is_action_pressed("Down"):
		velocity = -forward_direction * move_speed
		moving = true
	if Input.is_action_pressed("Left"):
		rotation -= rotate_speed*delta
		moving = true
	if Input.is_action_pressed("Right"):
		rotation += rotate_speed*delta
		moving = true
