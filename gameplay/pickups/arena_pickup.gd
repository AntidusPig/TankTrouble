class_name ArenaPickup extends Area2D

const PARTICLES := preload("res://gameplay/vfx/cartoon_particles.gd")

var definition: PickupDefinition
var cell: Vector2i
var collected := false


func _ready() -> void:
	add_to_group("arena_pickup")
	# Only monitor tank/wall bodies. The pickup itself is invisible to shell rays.
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	var sensor := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	sensor.shape = circle
	add_child(sensor)


func _physics_process(_delta: float) -> void:
	if collected:
		return
	for body in get_overlapping_bodies():
		if body is TankBase and definition.apply_to(body):
			collected = true
			if not body.silent:
				var parent := get_parent() as Node2D
				PARTICLES.emit(parent, parent.to_local(global_position), definition.color, 18, 102.0)
				CartoonSound.play_at(CartoonSound.pickup, global_position, -13.0)
			queue_free()
			return


func _draw() -> void:
	if definition == null:
		return
	draw_circle(Vector2(2.0, 3.0), 23.0, RetroUi.INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, 22.0, RetroUi.INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, 19.0, RetroUi.PAPER, true, -1.0, true)
	draw_arc(Vector2.ZERO, 16.5, 0.0, TAU, 32, definition.color.darkened(0.14), 2.5, true)
	var font := RetroUi.DISPLAY_FONT
	var width := font.get_string_size(definition.marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x
	draw_string(font, Vector2(-width * 0.5, 8.0), definition.marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, RetroUi.INK)
