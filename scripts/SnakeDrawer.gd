# scripts/SnakeDrawer.gd
extends Node2D

func _draw() -> void:
	var snake := get_parent()  # the Snake node
	var grid_size := snake.grid_size
	var col: Color = snake.color
	for seg in snake.segments:
		draw_rect(Rect2(seg, Vector2(grid_size, grid_size)), col)
