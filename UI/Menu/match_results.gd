extends MenuPanel

const RESULTS_TABLE := preload("res://UI/Menu/match_results_table.gd")

var outcome := ""
var summary := ""
var rows: Array[Dictionary] = []
var sudoku := false
var winner_slot := -1
var go_random: Callable
var go_menu: Callable
var continue_campaign: Callable


func _ready() -> void:
	backdrop_color = Color("#334f47").darkened(0.25)
	super()
	title.text = outcome
	detail.text = summary
	var table := RESULTS_TABLE.new()
	table.rows = rows
	table.sudoku = sudoku
	table.winner_slot = winner_slot
	show_page(table)
	if continue_campaign.is_valid():
		_button(tr("RESULT_CONTINUE"), continue_campaign).grab_focus()
	var random := _button(tr("RESULT_RANDOM_PUZZLE" if sudoku else "RESULT_RANDOM"), go_random)
	_button(tr("MAIN"), go_menu)
	if not continue_campaign.is_valid():
		random.grab_focus()
	_fit_menu()


func _fit_menu() -> void:
	super()
	if _page == null:
		return
	var reserved := _paper.get_minimum_size().y + 20.0
	var separation := _content.get_theme_constant("separation")
	for child: Control in _content.get_children():
		if child != _page and child.visible:
			reserved += child.get_combined_minimum_size().y + separation
	_page.fit_rows(get_viewport_rect().size.y - reserved)
