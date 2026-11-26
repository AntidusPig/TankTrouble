@tool
extends Wall

var material_texture: Texture2D
var trim := Color("#ffe5ad")
var _frame := StyleBoxFlat.new()


func _ready() -> void:
	super()
	black_rect.hide()
	z_index = 2
	_frame.bg_color = Color("#3b2624")
	_frame.border_color = Color("#251824")
	_frame.set_border_width_all(2)
	_frame.set_corner_radius_all(8)
	_frame.corner_detail = 5
	_frame.shadow_color = Color(0.11, 0.08, 0.12, 0.42)
	_frame.shadow_size = 3
	_frame.shadow_offset = Vector2(1.5, 2.5)
	queue_redraw()


func _draw() -> void:
	var span := WallSize.y
	if span <= 0.0:
		return
	var width := WallSize.x + 9.0
	var bounds := Rect2(-width * 0.5, -span * 0.5, width, span)
	draw_style_box(_frame, bounds)
	if material_texture != null:
		draw_set_transform(Vector2.ZERO, PI * 0.5)
		draw_texture_rect(material_texture, Rect2(-span * 0.5 + 7.0, -width * 0.5 + 3.5, span - 14.0, width - 7.0), false)
		draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-width * 0.25, -span * 0.39), Vector2(-width * 0.25, span * 0.35), Color(trim, 0.52), 1.45, true)
	for sign_value in [-1, 1]:
		var tip := Vector2(0, sign_value * (span * 0.5 - 6.5))
		draw_circle(tip, 3.0, Color("#291a22"), true, -1, true)
		draw_circle(tip - Vector2(0.7, 0.8), 1.65, trim, true, -1, true)
