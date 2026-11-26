extends RefCounted


static func emit(parent: Node2D, at: Vector2, tint: Color, count: int, speed: float,
		direction: Vector2 = Vector2.UP, spread: float = 180.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var particles := GPUParticles2D.new()
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(direction.x, direction.y, 0)
	material.spread = spread
	material.gravity = Vector3(0, 65, 0)
	material.initial_velocity_min = speed * 0.4
	material.initial_velocity_max = speed
	material.scale_min = 3.0
	material.scale_max = 8.0
	var colors := Gradient.new()
	colors.set_color(0, tint)
	colors.set_color(1, Color(tint, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = colors
	material.color_ramp = ramp
	particles.process_material = material
	particles.amount = count
	particles.one_shot = true
	particles.explosiveness = 0.91
	particles.lifetime = 0.48
	particles.z_index = 22
	particles.position = at
	particles.emitting = false
	parent.add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
