class_name MyCamera extends Camera2D

@export var recoil_pixels := 7.0
@export var bg_parallax_factor := 0.5

const MAX_RECOIL := 12.0
const HIT_PIXELS := 4.0

var _recoil := Vector2.ZERO
var _hit_strength := 0.0
var _hit_phase := 0.0
@onready var background: Sprite2D = $"../Background"


func _ready() -> void:
	fit_background()


func _process(delta: float) -> void:
	_recoil *= exp(-18.0 * delta)
	_hit_strength *= exp(-11.0 * delta)
	_hit_phase += 50.0 * delta
	var hit := Vector2(sin(_hit_phase), cos(_hit_phase * 0.75)) * (_hit_strength * HIT_PIXELS)
	offset = (_recoil + hit) / zoom
	fit_background()


func add_recoil(direction: Vector2) -> void:
	_recoil = (_recoil - direction.normalized() * recoil_pixels).limit_length(MAX_RECOIL)


func add_trauma(amount: float) -> void:
	if _hit_strength < 0.02:
		_hit_phase = 0.0
	_hit_strength = clampf(_hit_strength + amount, 0.0, 1.0)


func fit_background() -> void:
	if background == null or background.texture == null:
		return
	var view_size := get_viewport_rect().size / zoom
	var margin := Vector2.ONE * (MAX_RECOIL + HIT_PIXELS * 1.5) * (1.0 + absf(bg_parallax_factor)) / zoom
	var cover_size := view_size + margin * 2.0
	var texture_size := background.texture.get_size()
	background.scale = Vector2.ONE * maxf(cover_size.x / texture_size.x, cover_size.y / texture_size.y)
	background.position = position - offset * bg_parallax_factor
