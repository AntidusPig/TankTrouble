@tool
class_name Wall extends StaticBody2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var black_rect: Sprite2D = $BlackRect

var WallSize : Vector2
func _ready():
	WallSize = collision_shape_2d.shape.get_rect().size
	self.position = collision_shape_2d.shape.get_rect().position + WallSize/2.
	set_color(Color.BLACK)

func set_color(color:Color=Color.RED) -> void:
	var image = Image.create(int(WallSize.x), int(WallSize.y), false, Image.FORMAT_RGBA8)
	image.fill(color)
	black_rect.texture = ImageTexture.create_from_image(image)
