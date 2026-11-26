class_name ArenaEncyclopedia extends VBoxContainer

const PICKUP_PATH := "res://gameplay/pickups/catalog/"
const PROPS := ["repair_kit", "shield_cell", "needle_capsule", "fork_capsule",
	"breaker_capsule", "laser_capsule", "blast_capsule", "portal_capsule", "turbo_tonic"]
const PROP_NOTES := ["PROP_0", "PROP_1", "PROP_2", "PROP_3", "PROP_4", "PROP_5", "PROP_6", "PROP_7", "PROP_8"]
const AI_NOTES := ["BOT_0", "BOT_1", "BOT_2", "BOT_3", "BOT_4", "BOT_5", "BOT_6"]

var _index := VBoxContainer.new()
var _name := Label.new()
var _description := Label.new()
var _scroll := ScrollContainer.new()
var _marker := Label.new()
var _portrait := PlayerBadge.new()


func _ready() -> void:
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for i in range(2):
		var tab := MenuPanel.create_button(tr(["PROPS", "OPPONENTS"][i]), _show_category.bind(i == 1), true)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)

	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 14)
	add_child(spread)
	_scroll.custom_minimum_size = Vector2(166, 206)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	spread.add_child(_scroll)
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index.add_theme_constant_override("separation", 6)
	_scroll.add_child(_index)

	var page := PanelContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_stylebox_override("panel", RetroUi.ink_box(RetroUi.CREAM, 11, 2, 2))
	spread.add_child(page)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 180
	page.add_child(content)
	_name.add_theme_font_override("font", RetroUi.display_font())
	_name.add_theme_color_override("font_color", RetroUi.BRICK)
	_name.add_theme_font_size_override("font_size", 27)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var feature := HBoxContainer.new()
	feature.add_theme_constant_override("separation", 8)
	content.add_child(feature)
	_portrait.custom_minimum_size = Vector2(46, 46)
	feature.add_child(_portrait)
	_marker.custom_minimum_size = Vector2(43, 43)
	_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_marker.add_theme_font_override("font", RetroUi.display_font())
	_marker.add_theme_font_size_override("font_size", 30)
	_marker.add_theme_color_override("font_outline_color", RetroUi.INK)
	_marker.add_theme_constant_override("outline_size", 5)
	feature.add_child(_marker)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feature.add_child(_name)
	_description.add_theme_font_size_override("font_size", 19)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_description)
	_show_category(false)


func fit_height(available: float) -> void:
	_scroll.custom_minimum_size.y = clampf(available - 238.0, 144.0, 278.0)


func _show_category(opponents: bool) -> void:
	for child in _index.get_children():
		_index.remove_child(child)
		child.queue_free()
	var entries := PlayerRoster.LABELS.size() if opponents else PROPS.size()
	for i in range(entries):
		var caption: String
		var explanation: String
		var marker := ""
		var tint := Color.WHITE
		if opponents:
			caption = PlayerRoster.label_for(i)
			explanation = tr(AI_NOTES[i])
		else:
			var item := load(PICKUP_PATH + PROPS[i] + ".tres") as PickupDefinition
			caption = tr(item.display_name)
			marker = item.marker
			tint = item.color
			explanation = tr(PROP_NOTES[i])
			if item.weapon_stats != null:
				explanation += ("\n\n" + tr("CHARGES")) % item.shot_charges
		var button := MenuPanel.create_button(caption, _show_entry.bind(caption, explanation, marker, tint, i), true)
		button.add_theme_font_override("font", RetroUi.body_font())
		button.add_theme_font_size_override("font_size", 17)
		_index.add_child(button)
		if i == 0:
			_show_entry(caption, explanation, marker, tint, i)


func _show_entry(caption: String, explanation: String, marker: String, tint: Color, index: int) -> void:
	_portrait.visible = marker.is_empty()
	_portrait.player_slot = index
	_marker.visible = not marker.is_empty()
	_marker.text = marker
	_marker.add_theme_color_override("font_color", tint)
	_name.text = caption
	_description.text = explanation
