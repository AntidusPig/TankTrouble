class_name TankLaserBeam extends Node2D

const TANK_MASK := 1 << 1
const ACTIVE_DURATION := 0.25

var endpoint := Vector2.ZERO
var charge_left: float
var active_left := ACTIVE_DURATION


func advance(delta: float, shooter: TankBase) -> void:
	if charge_left > 0.0:
		charge_left = maxf(0.0, charge_left - delta)
		queue_redraw()
		if charge_left > 0.0:
			return
		if not shooter.silent:
			CartoonSound.play_at(CartoonSound.pop, global_position, -8.0, 0.64)
	else:
		active_left -= delta
		if active_left <= 0.0:
			queue_free()
			return

	var query := PhysicsRayQueryParameters2D.create(global_position, to_global(endpoint), TANK_MASK)
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


func _draw() -> void:
	if charge_left > 0.0:
		draw_line(Vector2.ZERO, endpoint, Color(1.0, 0.12, 0.12, 0.48), 2.0, true)
	else:
		draw_line(Vector2.ZERO, endpoint, Color(0.84, 0.0, 0.03, 0.50), 15.0, true)
		draw_line(Vector2.ZERO, endpoint, Color("#ff2424"), 7.0, true)
