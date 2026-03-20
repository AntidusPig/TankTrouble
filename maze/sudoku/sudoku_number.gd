class_name SudokuNumber extends Node2D

var fixed: bool = true
var current_value: int = 0
var max_value: int = 9  # set this!
var grid_index: int = 0
const NUMBER_STYLE_FIXED = preload("uid://cvoa04jo56leq")
const NUMBER_STYLE_GUESSED = preload("uid://cgbe3u8s2wmo8")
@onready var label: Label = $Label

signal value_changed(index: int, new_value: int)

# do not instantiate this class, create it!!!
static func create(max_val: int, is_fixed: bool, idx: int) -> SudokuNumber:
	var scene : Resource = load("uid://d0etr1ysu0j7o")
	var node : SudokuNumber = scene.instantiate()
	
	node.max_value = max_val
	node.fixed = is_fixed
	node.grid_index = idx
		
	return node
	
func _ready() -> void:
	set_fixed(fixed)

func set_fixed(is_fixed: bool) -> void:
	fixed = is_fixed
	if is_fixed:
		label.label_settings = NUMBER_STYLE_FIXED
	else:
		label.label_settings = NUMBER_STYLE_GUESSED

func increment_value():
	current_value = (current_value % max_value) + 1
	$Label.text = str(current_value)
	value_changed.emit(grid_index, current_value)
	
func set_number(num: int) -> void:
	current_value = num
	if num == 0:
		label.text = ""
	else:
		label.text = str(num)
