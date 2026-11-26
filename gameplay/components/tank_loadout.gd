class_name TankLoadout extends Node

signal changed

var weapon: PickupDefinition
var shots_left: int = 0


func equip(definition: PickupDefinition) -> void:
	weapon = definition
	shots_left = definition.shot_charges
	changed.emit()


func spend_charge() -> void:
	if weapon == null:
		return
	shots_left -= 1
	if shots_left == 0:
		weapon = null
	changed.emit()
