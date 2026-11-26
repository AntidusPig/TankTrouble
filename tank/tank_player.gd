class_name TankPlayer extends TankBase

signal player_move_signal(move_dir: Vector2)

var input_slot := 1
var _up: StringName
var _down: StringName
var _left: StringName
var _right: StringName
var _attack: StringName


func _ready() -> void:
	super()
	set_input_slot(input_slot)


func set_input_slot(slot: int) -> void:
	input_slot = slot
	var suffix := "2" if slot == 2 else ""
	_up = StringName("Up" + suffix)
	_down = StringName("Down" + suffix)
	_left = StringName("Left" + suffix)
	_right = StringName("Right" + suffix)
	_attack = StringName("Attack" + suffix)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(_attack):
		request_shot()


func _physics_process(delta: float) -> void:
	if pending_destroy:
		return
	var turn := Input.get_axis(_left, _right)
	var drive := Input.get_axis(_down, _up)
	apply_drive(turn, drive, delta)
	var direction := get_forward()
	if drive != 0.0 and not is_instance_valid(laser_beam):
		player_move_signal.emit(direction * signf(drive))
	super(delta)
