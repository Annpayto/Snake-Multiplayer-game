# scripts/Fruit.gd
extends Node2D

@export var grid_size: int = 20

var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size

	if NetworkManage.is_server:
		randomize_position()


func randomize_position() -> void:
	if screen_size == Vector2.ZERO:
		screen_size = get_viewport_rect().size

	var cols := int(screen_size.x / grid_size)
	var rows := int(screen_size.y / grid_size)

	var x := randi() % cols
	var y := randi() % rows

	position = Vector2(x * grid_size, y * grid_size)
