extends Node2D

var grid_size := 20
var screen_size := Vector2.ZERO

func _ready():
	screen_size = get_viewport_rect().size
	randomize_position()

func randomize_position():
	var cols = int(screen_size.x / grid_size)
	var rows = int(screen_size.y / grid_size)
	var xcell = randi_range(0, cols - 1)
	var ycell = randi_range(0, rows - 1)
	position = Vector2(xcell, ycell) * grid_size
	position = position.snapped(Vector2.ONE * grid_size)
