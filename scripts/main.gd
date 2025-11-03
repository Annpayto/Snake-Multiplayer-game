# scripts/Main.gd
extends Node2D

@onready var snake1: Node = $Snake1
@onready var snake2: Node = $Snake2
@onready var fruit: Node = $Fruit
@onready var score_label: Label = $HUD/ScoreLabel
var grid_size := 20

var game_over := false

func _process(_dt: float) -> void:
	if game_over:
		return
	_check_fruit_collision(snake1)
	_check_fruit_collision(snake2)
	_check_collisions()
	score_label.text = "P1: %d    P2: %d" % [snake1.score, snake2.score]


func _check_fruit_collision(snake: Node) -> void:
	if snake.segments.is_empty():
		return
	# heads are exactly on grid; fruit is aligned to grid too
	if snake.segments[0].distance_to(fruit.position) < grid_size * 0.5:
		snake.grow()
		_respawn_fruit_avoiding_snakes()

func _respawn_fruit_avoiding_snakes() -> void:
	var tries := 0
	while true:
		tries += 1
		fruit.randomize_position()
		if not _fruit_overlaps_any_snake():
			return
		if tries > 50:
			# fallback to just accept position
			return

func _fruit_overlaps_any_snake() -> bool:
	for seg in snake1.segments:
		if seg == fruit.position:
			return true
	for seg in snake2.segments:
		if seg == fruit.position:
			return true
	return false

func _check_collisions() -> void:
	var size := get_viewport_rect().size
	for snake in [snake1, snake2]:
		if snake.segments.is_empty():
			continue
		var head: Vector2 = snake.segments[0]
		# wall collision (use >= because head is top-left of cell)
		if head.x < 0 or head.y < 0 or head.x >= size.x or head.y >= size.y:
			snake.reset_snake()
			return

		# self collision
		for i in range(1, snake.segments.size()):
			if head == snake.segments[i]:
				_end_game()
				return

	# snake vs snake (heads against any segment of the other)
	var head1 = snake1.segments[0]
	var head2 = snake2.segments[0]
	# head-on collision → end immediately (tie possible)
	if head1 == head2:
		_end_game()
		return
	for seg in snake2.segments:
		if head1 == seg:
			_end_game()
			return
	for seg in snake1.segments:
		if head2 == seg:
			_end_game()
			return

func _end_game() -> void:
	game_over = true
	var winner := "Tie"
	if snake1.score > snake2.score:
		winner = "Player 1"
	elif snake2.score > snake1.score:
		winner = "Player 2"

	# simple on-screen label
	var label := Label.new()
	label.text = "Game Over — Winner: %s\nP1: %d   P2: %d" % [winner, snake1.score, snake2.score]
	label.theme_type_variation = "HeaderLarge"
	label.position = get_viewport_rect().size * 0.5 - Vector2(220, 40)
	add_child(label)

	get_tree().paused = true
	
	func _on_GameTimer_timeout() -> void:
		end_game()

func _on_game_timer_timeout() -> void:
	pass # Replace with function body.
