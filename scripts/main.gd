# scripts/Main.gd
extends Node2D

@onready var snake1: Snake = $Snake1
@onready var snake2: Snake = $Snake2
@onready var fruit: Node = $Fruit
@onready var score_label: Label = $HUD/ScoreLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var game_timer: Timer = $GameTimer

var grid_size: int = 20
var game_over: bool = false
var total_time: int = 60  # 1 minute
var time_left: float = total_time


func _ready() -> void:
	# Set timer to 1 minute (60 seconds)
	game_timer.wait_time = 1.0
	game_timer.start()


func _process(delta: float) -> void:
	if game_over:
		return

	# Update snakes and fruit
	_check_fruit_collision(snake1)
	_check_fruit_collision(snake2)
	_check_collisions()

	# Update labels
	score_label.text = "P1: %d    P2: %d" % [snake1.score, snake2.score]
	timer_label.text = "Time: %d" % int(time_left)

	# Countdown manually
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		end_game()

	queue_redraw()


# -------------------------------------------------------
#  FRUIT COLLISION / RESPAWN
# -------------------------------------------------------

func _check_fruit_collision(snake: Snake) -> void:
	if snake.segments.is_empty():
		return

	var head: Vector2 = snake.segments[0]
	if head == fruit.position.snapped(Vector2.ONE * snake.grid_size):
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
			return # fallback if stuck

func _fruit_overlaps_any_snake() -> bool:
	for seg in snake1.segments:
		if seg == fruit.position:
			return true
	for seg in snake2.segments:
		if seg == fruit.position:
			return true
	return false


# -------------------------------------------------------
#  COLLISIONS (WALLS, SELF, OTHER)
# -------------------------------------------------------

func _check_collisions() -> void:
	var size: Vector2 = get_viewport_rect().size

	for snake in [snake1, snake2]:
		if snake.segments.is_empty():
			continue
		var head: Vector2 = snake.segments[0]
		var grid: int = snake.grid_size

		# --- Wall collision fix (for 1152x648 window) ---
		if head.x < 0 or head.y < 0 \
				or head.x >= size.x - grid \
				or head.y >= size.y - grid:
			var start_pos := Vector2(100, 100) if snake == snake1 else Vector2(300, 300)
			snake.reset_snake_to_start(start_pos)
			continue

		# --- Self collision ---
		for i in range(1, snake.segments.size()):
			if head == snake.segments[i]:
				var start_pos := Vector2(100, 100) if snake == snake1 else Vector2(300, 300)
				snake.reset_snake_to_start(start_pos)
				break

	if snake1.segments.is_empty() or snake2.segments.is_empty():
		return

	var head1: Vector2 = snake1.segments[0]
	var head2: Vector2 = snake2.segments[0]

	if head1 == head2:
		snake1.reset_snake_to_start(Vector2(100, 100))
		snake2.reset_snake_to_start(Vector2(300, 300))
		return

	for seg in snake2.segments:
		if head1 == seg:
			snake1.reset_snake_to_start(Vector2(100, 100))
			return

	for seg in snake1.segments:
		if head2 == seg:
			snake2.reset_snake_to_start(Vector2(300, 300))
			return


# -------------------------------------------------------
#  GAME END
# -------------------------------------------------------

func end_game() -> void:
	if game_over:
		return

	game_over = true
	var winner := "Tie"
	if snake1.score > snake2.score:
		winner = "Player 1"
	elif snake2.score > snake1.score:
		winner = "Player 2"

	var label := Label.new()
	label.text = "⏰ Time's Up! Winner: %s\nP1: %d   P2: %d" % [winner, snake1.score, snake2.score]
	label.theme_type_variation = "HeaderLarge"
	label.position = get_viewport_rect().size * 0.5 - Vector2(220, 40)
	add_child(label)

	get_tree().paused = true


# -------------------------------------------------------
#  OPTIONAL: visible border for debugging
# -------------------------------------------------------

func _draw() -> void:
	var size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2)
