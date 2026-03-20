class_name TankBase extends CharacterBody2D

const shell_asset = preload("uid://dqmmo6iiwmn8g")
var moving : bool = false
@export var firing_cooldown : float = 0.5
@export var max_num_shells : int = 6
@export var health : int = 3
var shells : Array[Shell] = []
var pending_destroy : bool = false


@onready var move_speed : float = 275;
@onready var rotate_speed : float = PI*1.3;
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle = get_node_or_null("body/head_mount/head/muzzle")
@onready var engine_sound_player: AudioStreamPlayer2D = $EngineSoundPlayer
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
const tank_damaged : Array[Resource] = [preload("uid://c7c5coikwed3h"), preload("uid://cbg6j0oxhfo1d")]

func _physics_process(_delta: float) -> void:
	if pending_destroy:return
	if animation_player.current_animation == "shoot" and animation_player.is_playing():
		move_and_slide() # Still allow movement
		return
	var anim_to_play = "move" if moving else "idle"
	if animation_player.assigned_animation != anim_to_play:
		animation_player.play(anim_to_play)
		
	# Adjust volume based on state
	var target_db = -20.0 if moving else -25.0
	engine_sound_player.volume_db = lerp(engine_sound_player.volume_db, target_db, _delta * 5.0)
	move_and_slide()

func get_forward() -> Vector2:
	return global_transform.x.normalized()

func shoot() -> void:
	if pending_destroy:return
	shells = shells.filter(func(s): return is_instance_valid(s))
	animation_player.play("shoot")
	var shell : Shell = shell_asset.instantiate()
	shell.spawner = self
	get_tree().root.add_child(shell)   # add to root so bullets not destroyed if tank is destroyed
	shell.global_position = muzzle.global_position
	shell.scale = scale
	shell.shell_direction = get_forward()
	shells.push_back(shell)
	if len(shells) > max_num_shells:
		var oldest_shell = shells.pop_front()
		if is_instance_valid(oldest_shell):
			oldest_shell.destroy()

func receive_damage(dmg:int) -> void:
	if pending_destroy:return
	var health_old = health
	health = max(0,health-dmg)
	if health != health_old:
		audio_stream_player_2d.stream = tank_damaged.pick_random()
		audio_stream_player_2d.play()
	if health==0:
		destroy()

func destroy() -> void:
	pending_destroy = true
	animation_player.play("death")
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
