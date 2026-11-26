class_name TankLaserBeam extends Node2D

const PARTICLES := preload("res://gameplay/vfx/cartoon_particles.gd")
const TARGET_MASK := (1 << 1) | (1 << 2)
const ACTIVE_DURATION := 0.25

var endpoint := Vector2.ZERO
var charge_left: float
var charge_duration: float


func _ready() -> void:
	charge_duration = charge_left
	z_index = 18
	PARTICLES.emit(self, Vector2.ZERO, Color("#ff5146"), 14, 65.0)
var active_left := ACTIVE_DURATION


func advance(delta: float, shooter: TankBase) -> void:
	if charge_left > 0.0:
		charge_left = maxf(0.0, charge_left - delta)
		queue_redraw()
		if charge_left > 0.0:
			return
		var world := shooter.get_parent() as Node2D
		var direction := (to_global(endpoint) - global_position).normalized()
		PARTICLES.emit(world, world.to_local(global_position), Color("#ff3428"), 32, 175.0,
			world.to_local(global_position + direction) - world.to_local(global_position), 35.0)
		queue_redraw()
		if not shooter.silent:
			CartoonSound.play_at(CartoonSound.pop, global_position, -8.0, 0.64)
	else:
		active_left -= delta
		if active_left <= 0.0:
			queue_free()
			return

	var query := PhysicsRayQueryParameters2D.create(global_position, to_global(endpoint), TARGET_MASK)
	query.hit_from_inside = true
	var excluded: Array[RID] = [shooter.get_rid()]
	var space := get_world_2d().direct_space_state
	while true:
		query.exclude = excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		excluded.append(hit.rid)
		if hit.collider is TankBase:
			var victim := hit.collider as TankBase
			victim.receive_damage(victim.health + victim.shield_points)
		elif hit.collider.has_method("shell_hit"):
			hit.collider.shell_hit()


func _draw() -> void:
	var screen_scale := maxf(0.01, get_global_transform_with_canvas().get_scale().abs().x)
	if charge_left > 0.0:
		var progress := 1.0 - charge_left / maxf(charge_duration, 0.01)
		var width := lerpf(6.0, 10.0, progress) / screen_scale
		draw_line(Vector2.ZERO, endpoint, Color(1.0, 0.14, 0.11, 0.22), width * 2.4, true)
		draw_line(Vector2.ZERO, endpoint, Color(0.86, 0.02, 0.08, 0.80), width, true)
		draw_dashed_line(Vector2.ZERO, endpoint, Color("#ffb2a1"), width * 0.35, 18.0, true, true)
		draw_circle(Vector2.ZERO, width * 0.85, Color("#ff4d43"), true, -1.0, true)
	else:
		draw_line(Vector2.ZERO, endpoint, Color(0.85, 0.0, 0.03, 0.45), 22.0 / screen_scale, true)
		draw_line(Vector2.ZERO, endpoint, Color("#ff2424"), 12.0 / screen_scale, true)
		draw_line(Vector2.ZERO, endpoint, Color("#ffd0b6"), 4.0 / screen_scale, true)
