class_name PickupDefinition extends Resource

@export var display_name: String
@export var marker: String
@export var color: Color = Color.WHITE
@export_range(0, 10) var healing: int = 0
@export_range(0, 10) var shield: int = 0
@export var weapon_stats: ShellStats
@export_range(1, 20) var shot_charges: int = 1
@export var shot_angles: PackedFloat32Array = PackedFloat32Array([0.0])


func apply_to(tank: TankBase) -> bool:
	if tank.pending_destroy:
		return false
	if weapon_stats != null:
		tank.loadout.equip(self)
		return true
	if shield > 0:
		return tank.add_shield(shield)
	return tank.heal(healing)
