class_name MazeNavRegion extends NavigationRegion2D

@export var height : float = 1080
@export var width : float = 1920

func bake_maze_navigation() -> void:
	var source_geometry = NavigationMeshSourceGeometryData2D.new()
	
	NavigationServer2D.parse_source_geometry_data(
		navigation_polygon, 
		source_geometry, 
		get_tree().current_scene
	)
	
	source_geometry.add_traversable_outline(PackedVector2Array([
		Vector2(-width/2., -height/2.),
		Vector2(width/2., -height/2.),
		Vector2(width/2., height/2.),
		Vector2(-width/2., height/2.),
	]))
	
	NavigationServer2D.bake_from_source_geometry_data_async(
		navigation_polygon, 
		source_geometry,
		func(): bake_finished.emit()
	)
