class_name RetroUi extends RefCounted

const DISPLAY_FONT := preload("res://UI/Art/Fonts/Bangers-Regular.ttf")
const BODY_FONT := preload("res://UI/Art/Fonts/BarlowCondensed-SemiBold.ttf")
const CJK_FALLBACK := preload("res://i18n/fonts/NotoSansSC-UI.ttf")
const ARABIC_FALLBACK := preload("res://i18n/fonts/NotoSansArabic-UI.ttf")

const INK := Color("#302019")
const PAPER := Color("#ffedc7")
const MUSTARD := Color("#edb44a")
const BRICK := Color("#982f26")
const TEAL := Color("#315d51")
const CREAM := Color("#fff4d9")
const DIM := Color(0.12, 0.075, 0.06, 0.78)

static var _shared_theme: Theme
static var _display: FontVariation
static var _body: FontVariation


static func display_font() -> Font:
	if _display == null:
		_display = _with_fallback(DISPLAY_FONT)
	return _display


static func body_font() -> Font:
	if _body == null:
		_body = _with_fallback(BODY_FONT)
	return _body


static func _with_fallback(base: Font) -> FontVariation:
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Segoe UI", "Arial", "Microsoft YaHei", "Noto Sans"])
	var compatible := FontVariation.new()
	compatible.base_font = base
	compatible.fallbacks = [ARABIC_FALLBACK, CJK_FALLBACK, system]
	return compatible


static func theme_resource() -> Theme:
	if _shared_theme != null:
		return _shared_theme
	var theme := Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = 24
	theme.set_color("font_color", "Label", INK)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color("#756354"))
	theme.set_stylebox("normal", "Button", ink_box(MUSTARD, 11, 2, 4))
	theme.set_stylebox("hover", "Button", ink_box(Color("#ffcd70"), 11, 2, 4))
	theme.set_stylebox("pressed", "Button", ink_box(Color("#dc8b38"), 11, 2, 1))
	theme.set_stylebox("disabled", "Button", ink_box(Color("#e5d0a4"), 11, 2, 0))
	var focus := ink_box(CREAM, 11, 2, 0)
	focus.draw_center = false
	focus.border_color = BRICK
	focus.expand_margin_left = 4.0
	focus.expand_margin_right = 4.0
	focus.expand_margin_top = 3.0
	focus.expand_margin_bottom = 3.0
	theme.set_stylebox("focus", "Button", focus)
	_shared_theme = theme
	return _shared_theme


static func ink_box(fill: Color, radius: int, border: int, shadow: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = INK
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.corner_detail = 12
	box.shadow_color = INK
	box.shadow_size = shadow
	box.shadow_offset = Vector2(2, shadow * 0.7) if shadow > 0 else Vector2.ZERO
	box.content_margin_left = 15.0
	box.content_margin_right = 15.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 5.0
	return box
