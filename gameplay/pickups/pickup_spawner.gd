class_name PickupSpawner extends Node2D

@export var catalog: Array[PickupDefinition] = []
@export_range(0, 16) var max_active: int = 3
@export_range(0.1, 60.0) var spawn_interval: float = 4.0
@export_range(0.1, 120.0) var pickup_lifetime: float = 18.0

const PICKUP_SCENE := preload("res://gameplay/pickups/arena_pickup.tscn")

var arena: ArenaRoundManager
var timer := Timer.new()


func _ready() -> void:
	add_child(timer)
	timer.timeout.connect(_spawn)


func start() -> void:
	timer.start(spawn_interval)


func reset() -> void:
	timer.stop()
	for child in get_children():
		if child is ArenaPickup:
			child.set_physics_process(false)
			child.queue_free()


func _spawn() -> void:
	if catalog.is_empty() or not arena.round_active:
		return
	var occupied: Array[Vector2i] = []
	for child in get_children():
		if child is ArenaPickup and not child.is_queued_for_deletion():
			occupied.append(child.cell)
	if occupied.size() >= max_active:
		return
	var cells := arena.available_cells(occupied)
	if cells.is_empty():
		return
	var pickup := PICKUP_SCENE.instantiate() as ArenaPickup
	pickup.cell = cells.pick_random()
	pickup.definition = catalog.pick_random()
	pickup.position = to_local(arena.maze_builder.get_cell_position(pickup.cell.x, pickup.cell.y))
	add_child(pickup)
	var expiry := Timer.new()
	expiry.one_shot = true
	pickup.add_child(expiry)
	expiry.timeout.connect(pickup.queue_free)
	expiry.start(pickup_lifetime)
