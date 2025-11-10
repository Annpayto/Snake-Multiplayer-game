# scripts/SnakeDrawer.gd
extends Node2D

func _draw() -> void:
	var snake = get_parent()
	var g = snake.grid_size
	var col: Color = snake.color
	for seg in snake.segments:
		draw_rect(Rect2(seg, Vector2(g, g)), col)
