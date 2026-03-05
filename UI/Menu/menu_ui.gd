class_name MenuUI extends Control


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Escape"):
		get_tree().quit()
