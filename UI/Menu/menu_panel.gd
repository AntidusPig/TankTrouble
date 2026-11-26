class_name MenuPanel extends CenterContainer

const MASCOT := preload("res://UI/Art/menu-mascot.png")
const FILM_GRAIN := preload("res://UI/background.png")

var backdrop_color := RetroUi.TEAL
var show_title_art := false
var actions := GridContainer.new()
var detail := Label.new()
var title := Label.new()
var _illustration: TextureRect
var _content := VBoxContainer.new()
var _page: Control
var _paper: StyleBoxFlat


func _ready() -> void:
	theme = RetroUi.theme_resource()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit_menu)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 45)
	add_child(row)
	if show_title_art:
		_illustration = TextureRect.new()
		_illustration.texture = MASCOT
		_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_illustration)

	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paper = RetroUi.ink_box(RetroUi.PAPER, 27, 4, 7)
	_paper.content_margin_left = 34.0
	_paper.content_margin_right = 34.0
	_paper.content_margin_top = 24.0
	_paper.content_margin_bottom = 27.0
	card.add_theme_stylebox_override("panel", _paper)
	row.add_child(card)
	_content.add_theme_constant_override("separation", 11)
	card.add_child(_content)

	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", RetroUi.display_font())
	title.add_theme_font_size_override("font_size", 67)
	title.add_theme_color_override("font_color", RetroUi.BRICK)
	title.add_theme_color_override("font_shadow_color", RetroUi.INK)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	_content.add_child(title)

	var divider := ColorRect.new()
	divider.color = RetroUi.BRICK
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.custom_minimum_size.y = 3
	_content.add_child(divider)

	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 21)
	_content.add_child(detail)

	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 10)
	_content.add_child(actions)
	_fit_menu()


func _fit_menu() -> void:
	var compact := _compact_menu()
	_paper.content_margin_top = 13.0 if compact else 24.0
	_paper.content_margin_bottom = 15.0 if compact else 27.0
	_content.add_theme_constant_override("separation", 8 if compact else 11)
	_content.custom_minimum_size.x = clampf(size.x - 116.0, 225.0, 340.0)
	if _page != null and _page.has_method("preferred_width"):
		_content.custom_minimum_size.x = _page.call("preferred_width", get_viewport_rect().size.x)
	var tall_script := TranslationServer.get_locale() in ["ar", "zh_CN"]
	var base_size := 54 if tall_script else 67
	title.add_theme_font_size_override("font_size", mini(46, base_size) if compact or size.x < 455.0 else base_size)
	actions.add_theme_constant_override("v_separation", 6 if compact else 10)
	for button in actions.get_children():
		_fit_action(button)
	if _illustration != null:
		_illustration.visible = _page == null and size.x >= 880.0 and size.y >= 470.0
		var extent := clampf(minf(size.x * 0.35, size.y * 0.70), 280.0, 445.0)
		_illustration.custom_minimum_size = Vector2(extent, extent)
	if _page != null and _page.has_method("fit_height"):
		_page.call("fit_height", get_viewport_rect().size.y)
	queue_redraw()


func _compact_menu() -> bool:
	return get_viewport_rect().size.y < (745.0 if show_title_art and _page == null else 570.0)


func _fit_action(button: Button) -> void:
	var compact := _compact_menu()
	button.custom_minimum_size.y = 33.0 if compact else 43.0
	button.add_theme_font_size_override("font_size", 21 if compact else 25)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), backdrop_color)
	if not show_title_art:
		return

	var art_side := 0.72 if is_layout_rtl() else 0.28
	var center := Vector2(size.x * art_side if size.x >= 880.0 else size.x * 0.5, size.y * 0.53)
	var radius := size.length()
	for ray in range(14):
		var start := float(ray) * TAU / 14.0
		var finish := start + 0.16
		draw_colored_polygon(PackedVector2Array([
			center, center + Vector2.from_angle(start) * radius,
			center + Vector2.from_angle(finish) * radius
		]), Color(1.0, 0.86, 0.57, 0.085))
	draw_texture_rect(FILM_GRAIN, Rect2(Vector2.ZERO, size), false, Color(1, 0.97, 0.79, 0.14))
	if size.x > 400.0 and size.y > 340.0:
		draw_rect(Rect2(Vector2(13, 13), size - Vector2(26, 26)), RetroUi.INK, false, 3.0)
		draw_rect(Rect2(Vector2(19, 19), size - Vector2(38, 38)), Color(0.98, 0.87, 0.64, 0.50), false, 1.0)


func show_page(page: Control) -> void:
	if _page != null:
		_content.remove_child(_page)
		_page.queue_free()
	_page = page
	if _page != null:
		_content.add_child(_page)
		_content.move_child(_page, actions.get_index())
	_fit_menu()


func _clear_actions() -> void:
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()


func _button(caption: String, action: Callable) -> Button:
	var button := create_button(caption, action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(button)
	_fit_action(button)
	return button


static func create_button(caption: String, action: Callable, compact := false) -> Button:
	var button := Button.new()
	button.theme = RetroUi.theme_resource()
	button.text = caption
	button.custom_minimum_size.y = 34.0 if compact else 43.0
	button.add_theme_font_override("font", RetroUi.display_font())
	button.add_theme_font_size_override("font_size", 20 if compact else 25)
	button.pressed.connect(CartoonSound.play_confirm)
	button.pressed.connect(action)
	return button
