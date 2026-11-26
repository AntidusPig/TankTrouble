class_name TankBase extends CharacterBody2D

@export var SHELL_SCENE : Resource = preload("uid://dqmmo6iiwmn8g")
@export var shell_stats: ShellStats = preload("uid://bvsplecyym1iy")

var moving : bool = false
@export var health : int = 5
var shells : Array[Shell] = []
var pending_destroy : bool = false
@onready var max_health: int = health
@onready var loadout: TankLoadout = _create_loadout()
var time_since_last_shot: float = 0.0
var _shot_requested := false
var laser_beam: TankLaserBeam

@onready var move_speed : float = 275;
@onready var rotate_speed : float = PI*1.3;
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle = get_node_or_null("body/head_mount/head/muzzle")
@onready var engine_sound_player: AudioStreamPlayer2D = $EngineSoundPlayer
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
const tank_damaged : Array[Resource] = [preload("uid://c7c5coikwed3h"), preload("uid://cbg6j0oxhfo1d")]

@export_range(0, 16) var team: int = 0
var shield_points: int = 0
var silent: bool = false
var portal_launcher: Callable
var external_motion: Callable
var boost_left := 0.0
var boost_duration := 0.0
var weapon_effect_parent: Node2D
var _ai_enabled := false
var _ai_turn := 0.0
var _ai_drive := 0.0

signal shoot_signal(pos: Vector2, direction: Vector2)
signal damaged_signal(current_health: int)
signal destroyed_signal

func _ready() -> void:
	add_to_group("arena_tank")
	set_collision_layer_value(2, true)
	if silent:
		engine_sound_player.stop()


func enable_ai_controls(enabled: bool) -> void:
	_ai_enabled = enabled
	_ai_turn = 0.0
	_ai_drive = 0.0
	_shot_requested = false
	velocity = Vector2.ZERO
	moving = false


func set_ai_controls(turn: float, drive: float, fire: bool) -> void:
	if _ai_enabled and not pending_destroy:
		_ai_turn = clampf(turn, -1.0, 1.0)
		_ai_drive = clampf(drive, -1.0, 1.0)
		if fire:
			request_shot()


func apply_drive(turn: float, drive: float, delta: float) -> void:
	if is_instance_valid(laser_beam):
		return
	rotation += turn * rotate_speed * delta
	velocity = get_forward() * drive * move_speed * scale.x * (1.40 if boost_left > 0.0 else 1.0)
	moving = turn != 0.0 or velocity.length_squared() > 5.0


func _physics_process(delta: float) -> void:
	if pending_destroy:return
	if boost_left > 0.0:
		boost_left = maxf(0.0, boost_left - delta)
		queue_redraw()
	if is_instance_valid(laser_beam):
		_shot_requested = false
		laser_beam.advance(delta, self)
		return
	if _ai_enabled:
		apply_drive(_ai_turn, _ai_drive, delta)
	if time_since_last_shot > 0.0:
		time_since_last_shot -= delta
	if _shot_requested:
		_shot_requested = false
		shoot()
		if is_instance_valid(laser_beam):
			return
	if animation_player.current_animation == "shoot" and animation_player.is_playing():
		_move_tank() # Still allow movement
		return
	var anim_to_play = "move" if moving else "idle"
	if animation_player.assigned_animation != anim_to_play:
		animation_player.play(anim_to_play)
		
	# Adjust volume based on state
	var target_db = -20.0 if moving else -25.0
	engine_sound_player.volume_db = lerp(engine_sound_player.volume_db, target_db, delta * 5.0)
	_move_tank()


func _move_tank() -> void:
	if external_motion.is_valid():
		velocity += external_motion.call(global_position)
	move_and_slide()


func get_forward() -> Vector2:
	return global_transform.x.normalized()

func _create_loadout() -> TankLoadout:
	var component := TankLoadout.new()
	add_child(component)
	return component


func request_shot() -> void:
	_shot_requested = true


func shoot() -> void:
	if pending_destroy or is_instance_valid(laser_beam) or time_since_last_shot > 0.0:
		return
	var weapon := loadout.weapon
	var active_stats := shell_stats if weapon == null else weapon.weapon_stats
	var angles := PackedFloat32Array([0.0]) if weapon == null else weapon.shot_angles
	if angles.is_empty():
		return
	var is_portal := weapon != null and weapon.portal_round
	if is_portal and (not portal_launcher.is_valid() or not portal_launcher.call(self, muzzle.global_position, get_forward())):
		return
	time_since_last_shot = active_stats.firing_cooldown
	shells = shells.filter(func(shell): return is_instance_valid(shell))
	if not is_portal:
		for angle in angles:
			var direction := get_forward().rotated(deg_to_rad(angle))
			if active_stats.laser_range > 0.0:
				_fire_laser(direction, active_stats)
			else:
				_fire_shell(direction, active_stats if weapon != null else null)
	shoot_signal.emit(muzzle.global_position, get_forward())
	while shells.size() > active_stats.max_num_shells:
		var oldest: Shell = shells.pop_front()
		if is_instance_valid(oldest):
			oldest.call_deferred("destroy")
	loadout.spend_charge()
	if not is_instance_valid(laser_beam):
		animation_player.play("shoot")
		if not silent:
			CartoonSound.play_at(CartoonSound.pop, muzzle.global_position, -12.0, 0.84)


func _fire_shell(direction: Vector2, profile: ShellStats) -> void:
	var parent := weapon_effect_parent if is_instance_valid(weapon_effect_parent) else get_tree().current_scene as Node2D
	var shell: Shell = SHELL_SCENE.instantiate()
	shell.spawner = self
	shell.shot_color = $body.modulate
	shell.position = parent.to_local(muzzle.global_position)
	shell.scale = scale
	shell.shell_direction = direction
	if profile != null:
		shell.stats = profile
	shell.add_to_group("arena_weapon_effect")
	parent.add_child.call_deferred(shell)
	shells.append(shell)


func _fire_laser(direction: Vector2, profile: ShellStats) -> void:
	var beam := TankLaserBeam.new()
	beam.position = to_local(muzzle.global_position)
	beam.endpoint = to_local(muzzle.global_position + direction * profile.laser_range) - beam.position
	beam.charge_left = profile.laser_charge_time
	beam.z_index = 8
	laser_beam = beam
	add_child(beam)
	velocity = Vector2.ZERO
	moving = false
	animation_player.play("idle")


func heal(amount: int) -> bool:
	if pending_destroy or amount <= 0 or health >= max_health:
		return false
	health = mini(health + amount, max_health)
	return true


func grant_speed_boost(seconds: float) -> bool:
	if pending_destroy or boost_left >= seconds * 0.75:
		return false
	boost_duration = seconds
	boost_left = seconds
	queue_redraw()
	return true


func add_shield(amount: int) -> bool:
	if pending_destroy or amount <= shield_points:
		return false
	shield_points = amount
	queue_redraw()
	return true


func _draw() -> void:
	if boost_left > 0.0:
		draw_arc(Vector2.ZERO, 66.0, PI * 0.70, PI * 1.30, 20, Color("#ffb453"), 5.0, true)
	if shield_points > 0:
		draw_arc(Vector2.ZERO, 83.0, 0.0, TAU, 48, Color(0.53, 0.65, 1.0, 0.9), 3.5, true)


func receive_damage(dmg:int) -> void:
	if pending_destroy or dmg <= 0: return
	if shield_points > 0:
		var absorbed := mini(shield_points, dmg)
		shield_points -= absorbed
		dmg -= absorbed
		queue_redraw()
	var health_old = health
	health = max(0,health-dmg)
	if health != health_old:
		damaged_signal.emit(health)
		if not silent:
			audio_stream_player_2d.stream = tank_damaged.pick_random()
			audio_stream_player_2d.play()
	if health==0:
		destroy()

func destroy() -> void:
	if pending_destroy:
		return
	pending_destroy = true
	health = 0
	engine_sound_player.stop()
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if is_instance_valid(laser_beam):
		laser_beam.queue_free()
	animation_player.play("death")
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
	destroyed_signal.emit()
