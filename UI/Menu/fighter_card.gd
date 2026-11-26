class_name FighterCard extends PanelContainer

var player_slot: int
var role: int
var difficulty := -1
var _difficulty_label := Label.new()
var _badge := PlayerBadge.new()
var _nameplate := Label.new()
var _role_name := Label.new()
var _score := Label.new()
var _lives := Label.new()
const PROP_METER := preload("res://UI/Menu/prop_meter.gd")
const TURBO := preload("res://gameplay/pickups/catalog/turbo_tonic.tres")
var _weapon_meter := PROP_METER.new()
var _turbo_meter := PROP_METER.new()
var _armor := Label.new()
var _status := Label.new()
var _hull := ProgressBar.new()
var _column := VBoxContainer.new()
var _paper: StyleBoxFlat


func _ready() -> void:
	var tint: Color = PlayerRoster.COLORS[player_slot]
	theme = RetroUi.theme_resource()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = 155.0
	size_flags_vertical = Control.SIZE_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role_name.text = PlayerRoster.label_for(role)
	_role_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_paper = RetroUi.ink_box(RetroUi.PAPER.lerp(tint, 0.13), 10, 2, 2)
	if difficulty >= 0:
		_paper.bg_color = AiSettings.CARD_COLORS[difficulty]
	_paper.content_margin_left = 11
	_paper.content_margin_right = 11
	add_theme_stylebox_override("panel", _paper)
	_column.layout_direction = Control.LAYOUT_DIRECTION_LOCALE
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_column)
	var heading := HBoxContainer.new()
	_column.add_child(heading)
	heading.add_theme_constant_override("separation", 9)
	_badge.player_slot = player_slot
	heading.add_child(_badge)
	_nameplate.text = tr("PLAYER") % (player_slot + 1)
	_nameplate.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_nameplate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nameplate.add_theme_font_override("font", RetroUi.display_font())
	heading.add_child(_nameplate)
	_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(_score)
	_difficulty_label.visible = difficulty >= 0
	if difficulty >= 0:
		_difficulty_label.text = tr(AiSettings.LABELS[difficulty])
		_difficulty_label.add_theme_color_override("font_color", RetroUi.BRICK)
	_difficulty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var condition := HBoxContainer.new()
	_column.add_child(condition)
	_lives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lives.add_theme_font_size_override("font_size", 15)
	_lives.add_theme_color_override("font_color", RetroUi.BRICK)
	condition.add_child(_lives)
	_armor.add_theme_font_size_override("font_size", 14)
	condition.add_child(_armor)
	condition.add_child(_weapon_meter)
	condition.add_child(_turbo_meter)
	_weapon_meter.hide()
	_turbo_meter.hide()

	_hull.show_percentage = false
	_hull.custom_minimum_size.y = 11
	var track := RetroUi.ink_box(Color("#d9c097"), 3, 1, 0)
	var fill := RetroUi.ink_box(tint, 3, 1, 0)
	for style in [track, fill]:
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.content_margin_left = 0
		style.content_margin_right = 0
	_hull.add_theme_stylebox_override("background", track)
	_hull.add_theme_stylebox_override("fill", fill)
	_column.add_child(_hull)
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	_column.add_child(detail)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_child(_status)
	_role_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_role_name.add_theme_color_override("font_color", RetroUi.INK.lerp(tint, 0.30))
	detail.add_child(_role_name)
	detail.add_child(_difficulty_label)
	fit_height(160.0)


func fit_height(height: float) -> void:
	_difficulty_label.add_theme_font_size_override("font_size", 11 if height < 141.0 else 14)
	var small := height < 141.0
	var tall := height >= 215.0
	var meter_size := 24.0 if small else (37.0 if tall else 32.0)
	_weapon_meter.custom_minimum_size = Vector2.ONE * meter_size
	_turbo_meter.custom_minimum_size = Vector2.ONE * meter_size
	var pad := 3.0 if small else 5.0
	_paper.content_margin_top = pad
	_paper.content_margin_bottom = pad
	_column.add_theme_constant_override("separation", 1 if small else (7 if tall else 4))
	var badge_size := 58.0 if tall else (26.0 if small else 42.0)
	_badge.custom_minimum_size = Vector2.ONE * badge_size
	_nameplate.add_theme_font_size_override("font_size", 33 if tall else (16 if small else 25))
	_role_name.add_theme_font_size_override("font_size", 19 if tall else (11 if small else 15))
	_score.add_theme_font_size_override("font_size", 24 if tall else (12 if small else 18))
	_lives.add_theme_font_size_override("font_size", 22 if tall else (13 if small else 18))
	_armor.add_theme_font_size_override("font_size", 19 if tall else (11 if small else 16))
	_status.add_theme_font_size_override("font_size", 20 if tall else (11 if small else 17))
	_hull.custom_minimum_size.y = 15.0 if tall else (5.0 if small else 10.0)


func update_fighter(tank: TankBase, lives: int, wins: int) -> void:
	_score.text = tr("WINS") % wins
	_lives.text = "●".repeat(lives) + "○".repeat(3 - lives)
	_armor.text = ""
	if not is_instance_valid(tank):
		_weapon_meter.hide()
		_turbo_meter.hide()
		_hull.value = 0
		_status.text = tr("RESPAWNING") if lives > 0 else tr("ELIMINATED")
		return
	_hull.max_value = tank.max_health
	_hull.value = tank.health
	if tank.shield_points > 0:
		_armor.text = tr("SHIELD") % tank.shield_points
	var weapon := tank.loadout.weapon
	_status.text = tr("STANDARD") if weapon == null else "%s · %d" % [tr(weapon.display_name), tank.loadout.shots_left]
	if weapon == null:
		_weapon_meter.hide()
	else:
		_weapon_meter.show_prop(weapon.marker, weapon.color, float(tank.loadout.shots_left) / weapon.shot_charges, _status.text)
	if tank.boost_left > 0.0:
		_turbo_meter.show_prop(TURBO.marker, TURBO.color, tank.boost_left / tank.boost_duration,
			"%s · %s" % [tr(TURBO.display_name), tr("SECONDS_REMAINING") % ceili(tank.boost_left)])
	else:
		_turbo_meter.hide()


func update_sudoku(edits: int, human: bool) -> void:
	_lives.hide()
	_armor.hide()
	_hull.hide()
	_score.text = tr("EDITS") % edits
	_role_name.text = tr("HUMAN") if human else tr("SUDOKU_AI")
	_status.hide()
	_role_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
