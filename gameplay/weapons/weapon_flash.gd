class_name WeaponFlash extends Node2D

var blast_radius := 0.0
var time_left := 0.16


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
	else:
		modulate.a = clampf(time_left / 0.16, 0.0, 1.0)


func _draw() -> void:
	if blast_radius > 0.0:
		draw_circle(Vector2.ZERO, blast_radius, Color(1.0, 0.43, 0.17, 0.26))
		draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 48, Color(1.0, 0.65, 0.24), 4.0, true)
