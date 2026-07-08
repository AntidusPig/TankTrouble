class_name TankBase extends CharacterBody2D

@export var SHELL_SCENE : Resource = preload("uid://dqmmo6iiwmn8g")
@export var shell_stats: ShellStats = preload("uid://bvsplecyym1iy")

var moving : bool = false
@export var health : int = 5
var shells : Array[Shell] = []
var pending_destroy : bool = false
var time_since_last_shot: float = 0.0

@onready var move_speed : float = 275;
@onready var rotate_speed : float = PI*1.3;
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle = get_node_or_null("body/head_mount/head/muzzle")
@onready var engine_sound_player: AudioStreamPlayer2D = $EngineSoundPlayer
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
const tank_damaged : Array[Resource] = [preload("uid://c7c5coikwed3h"), preload("uid://cbg6j0oxhfo1d")]

signal shoot_signal(pos: Vector2, direction: Vector2)
signal damaged_signal(current_health: int)

func _physics_process(delta: float) -> void:
	if pending_destroy:return
	if time_since_last_shot > 0.0:
		time_since_last_shot -= delta
	if animation_player.current_animation == "shoot" and animation_player.is_playing():
		move_and_slide() # Still allow movement
		return
	var anim_to_play = "move" if moving else "idle"
	if animation_player.assigned_animation != anim_to_play:
		animation_player.play(anim_to_play)
		
	# Adjust volume based on state
	var target_db = -20.0 if moving else -25.0
	engine_sound_player.volume_db = lerp(engine_sound_player.volume_db, target_db, delta * 5.0)
	move_and_slide()

func get_forward() -> Vector2:
	return global_transform.x.normalized()

func shoot() -> void:
	if pending_destroy: return
	if time_since_last_shot > 0.0:
		return
	time_since_last_shot = shell_stats.firing_cooldown
	shells = shells.filter(func(s): return is_instance_valid(s))
	var shell_inst : Shell = SHELL_SCENE.instantiate()
	shell_inst.spawner = self
	# Use call_deferred to avoid physics threading issues when adding to root
	get_tree().root.add_child.call_deferred(shell_inst)
	
	shell_inst.global_position = muzzle.global_position
	shell_inst.scale = scale
	shell_inst.shell_direction = get_forward()
	shells.push_back(shell_inst)
	# Limit shell count
	if shells.size() > shell_stats.max_num_shells:
		var oldest = shells.pop_front()
		if is_instance_valid(oldest):
			oldest.destroy()
	animation_player.play("shoot")
	shoot_signal.emit(muzzle.global_position, get_forward())

func receive_damage(dmg:int) -> void:
	if pending_destroy:return
	var health_old = health
	health = max(0,health-dmg)
	if health != health_old:
		damaged_signal.emit(health)
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
