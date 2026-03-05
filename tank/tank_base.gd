class_name TankBase extends CharacterBody2D

const shell_asset = preload("res://tank/shell/shell.tscn")
@onready var move_speed : float = 275;
@onready var rotate_speed : float = PI*1.3;
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle: Node2D = $body/head_mount/head/muzzle
var moving : bool = false
@export var firing_cooldown : float = 0.5
@export var max_num_shells : int = 6
@export var health : int = 3
var shells : Array[Shell] = []
var pending_destroy : bool = false


func _physics_process(_delta: float) -> void:
	if pending_destroy:return
	var anim_to_play = "move" if moving else "idle"
	if animation_player.assigned_animation != anim_to_play:
		animation_player.play(anim_to_play)
	move_and_slide()

func get_forward() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)

func shoot() -> void:
	if pending_destroy:return
	shells = shells.filter(func(s): return is_instance_valid(s))
	var shell : Shell = shell_asset.instantiate()
	add_child(shell)
	shell.top_level = true # otherwise inherit transform
	shell.global_position = muzzle.global_position
	shell.shell_direction = get_forward()
	#shell.get_node("RayCast2D").add_exception(self)
	if len(shells) > max_num_shells:
		shells.pop_front().destroy()
	shells.push_back(shell)

func receive_damage(dmg:int) -> void:
	if pending_destroy:return
	health = max(0,health-dmg)
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
