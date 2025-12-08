extends Node2D

@onready var snake1: Snake = $Snake1
@onready var snake2: Snake = $Snake2
@onready var fruit: Node2D = $Fruit
@onready var score_label: Label = $HUD/ScoreLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var gameover_label: CanvasLayer = $GameOverMenu

var grid_size: int = 20
var game_over: bool = false

var total_time: float = 60.0   # 1 minute
var time_left: float = 60.0

enum Gamestate { WAITING_FOR_PLAYERS, STARTING, IN_GAME, GAME_OVER }
var current_state: Gamestate = Gamestate.WAITING_FOR_PLAYERS

var required_client: int = 1
var connected_client: int = 0


# -------------------------------------------------------
#  READY
# -------------------------------------------------------
func _ready() -> void:
	time_left = total_time
	
	gameover_label.restart.connect(_on_restart_requested)
	gameover_label.get_node("RestartButton").hide()
	# Only host picks the starting fruit position
	if NetworkManage.is_server:
		print("HOST: Game scene loaded. Waiting for client...")
		NetworkManage.client_connected.connect(_on_client_joined)
		NetworkManage.client_disconnected.connect(_on_client_left)
		
		current_state = Gamestate.WAITING_FOR_PLAYERS
		score_label.text = "Waiting for Player 2..."
	else:
		current_state = Gamestate.WAITING_FOR_PLAYERS
		score_label.text = "Connected. Waiting for Host to Start"

func _on_client_joined(id: int) -> void:
	if not NetworkManage.is_server:
		return # Only host cares about new connections for starting the match
	
	connected_client += 1
	
	if connected_client >= required_client:
		print("HOST: Required clients connected. Starting match...")
		_start_match()
	
	else:
		print("HOST: Still waiting for more players...")

func _on_client_left(id: int) -> void: # <-- ADD THIS FUNCTION
	if not NetworkManage.is_server:
		return
	
	connected_client -= 1
	print("HOST: Client disconnected! ID: ", id, ". Remaining clients: ", connected_client)
	if current_state == Gamestate.IN_GAME and connected_client < required_client:
		print("CRITICAL: Client disconnected mid-game. Ending match.")
		end_game()

func _start_match() -> void:
	if current_state != Gamestate.WAITING_FOR_PLAYERS:
		return
	
	current_state = Gamestate.IN_GAME
	time_left = total_time
	
	# Original logic from _ready():
	_respawn_fruit_avoiding_snakes()
	rpc("rpc_sync_fruit", fruit.position)
	
	rpc("rpc_game_start_confirmed")


@rpc("reliable")
func rpc_game_start_confirmed() -> void:
	if current_state != Gamestate.IN_GAME:
		print("Match starting now!")
		current_state = Gamestate.IN_GAME


# -------------------------------------------------------
#  RPC: sync snake state
# -------------------------------------------------------
@rpc("unreliable_ordered")
func rpc_sync_snake(id: int, segments: Array, score: int) -> void:
	# Runs on clients when host calls rpc()
	if NetworkManage.is_server:
		return

	var snake: Snake = snake1 if id == 1 else snake2
	snake.segments = segments.duplicate()
	snake.score = score
	snake.drawer.queue_redraw()


func _sync_snakes_to_clients() -> void:
	if not NetworkManage.is_server:
		return

	rpc("rpc_sync_snake", 1, snake1.segments, snake1.score)
	rpc("rpc_sync_snake", 2, snake2.segments, snake2.score)


# -------------------------------------------------------
#  RPC: server → clients, sync fruit position
# -------------------------------------------------------
@rpc("reliable")
func rpc_sync_fruit(pos: Vector2) -> void:
	# Host already has the correct position
	if NetworkManage.is_server:
		return
	fruit.position = pos


# -------------------------------------------------------
#  RPC: clients → server, request direction change
# -------------------------------------------------------
@rpc("any_peer", "reliable")
func rpc_request_direction(snake_id: int, dir: Vector2) -> void:
	if not NetworkManage.is_server:
		return

	var snake: Snake = snake1 if snake_id == 1 else snake2
	_apply_direction(snake, dir)


func _apply_direction(snake: Snake, dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	if dir == -snake.direction:
		return
	snake.direction = dir


func _get_input_direction(snake: Snake) -> Vector2:
	var c: Dictionary = snake.controls
	var dir := Vector2.ZERO

	if Input.is_action_pressed(c["up"]):
		dir = Vector2.UP
	elif Input.is_action_pressed(c["down"]):
		dir = Vector2.DOWN
	elif Input.is_action_pressed(c["left"]):
		dir = Vector2.LEFT
	elif Input.is_action_pressed(c["right"]):
		dir = Vector2.RIGHT

	return dir


func _handle_local_input() -> void:
	var local_snake: Snake
	var local_id: int

	if NetworkManage.is_server:
		# Host controls snake1
		local_snake = snake1
		local_id = 1
	else:
		# Client controls snake2
		local_snake = snake2
		local_id = 2

	var dir := _get_input_direction(local_snake)
	if dir == Vector2.ZERO:
		return

	if NetworkManage.is_server:
		_apply_direction(local_snake, dir)
	else:
		# Client asks host to apply direction to snake2
		rpc_id(1, "rpc_request_direction", local_id, dir)


# -------------------------------------------------------
#  MAIN LOOP
# -------------------------------------------------------
func _process(delta: float) -> void:
	if current_state != Gamestate.IN_GAME and current_state != Gamestate.GAME_OVER:
		score_label.text = "P1: %d   P2: %d" % [snake1.score, connected_client] 
		timer_label.text = "Waiting..."
		queue_redraw()
		return

	if current_state == Gamestate.GAME_OVER:
		return
		
	# All game logic below will ONLY run if current_state == IN_GAME
	
	# Everyone reads *their* local input
	_handle_local_input()
	if game_over:
		return

	# Everyone reads *their* local input
	_handle_local_input()

	if NetworkManage.is_server:
		# Host runs game logic
		_check_fruit_collision(snake1)
		_check_fruit_collision(snake2)
		_check_collisions()
		_sync_snakes_to_clients()

	# UI updated everywhere
	score_label.text = "P1: %d    P2: %d" % [snake1.score, snake2.score]
	timer_label.text = "Time: %d" % int(time_left)

	time_left -= delta
	if NetworkManage.is_server and time_left <= 0.0:
		time_left = 0.0
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
			if NetworkManage.is_server:
				rpc("rpc_sync_fruit", fruit.position)
			return

		if tries > 50:
			if NetworkManage.is_server:
				rpc("rpc_sync_fruit", fruit.position)
			return


func _fruit_overlaps_any_snake() -> bool:
	for seg in snake1.segments:
		if seg == fruit.position:
			return true
	for seg in snake2.segments:
		if seg == fruit.position:
			return true
	return false


# -------------------------------------------------------
#  COLLISIONS
# -------------------------------------------------------
func _check_collisions() -> void:
	var size: Vector2 = get_viewport_rect().size

	for snake in [snake1, snake2]:
		if snake.segments.is_empty():
			continue

		var head: Vector2 = snake.segments[0]
		var g: int = snake.grid_size

		# Wall collision
		if head.x < 0 or head.y < 0 \
				or head.x >= size.x - g \
				or head.y >= size.y - g:
			var start_pos := Vector2(100, 100) if snake == snake1 else Vector2(300, 300)
			snake.reset_snake_to_start(start_pos)
			continue

		# Self collision
		for i in range(1, snake.segments.size()):
			if head == snake.segments[i]:
				var start_pos := Vector2(100, 100) if snake == snake1 else Vector2(300, 300)
				snake.reset_snake_to_start(start_pos)
				break

	# Snake vs snake
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
	
	print("SERVER GAME ENDED | Winner: %s | P1 Score: %d | P2 Score: %d" % [winner, snake1.score, snake2.score])
	
	var label := Label.new()
	label.text = "Time's Up! Winner: %s\nP1: %d   P2: %d" % [winner, snake1.score, snake2.score]
	label.theme_type_variation = "HeaderLarge"
	
	rpc("rpc_display_final_score", winner, snake1.score, snake2.score)

@rpc("reliable")
func rpc_display_final_score(winner: String, p1_score: int, p2_score: int) -> void:
	if current_state == Gamestate.GAME_OVER:
		return
	
	current_state = Gamestate.GAME_OVER
	
	score_label.text = "P1: %d    P2: %d" % [p1_score, p2_score]
	timer_label.text = "GAME OVER!"
	var label := Label.new()
	label.text = "Time's Up! Winner: %s\nP1: %d    P2: %d" % [winner, p1_score, p2_score]
	label.theme_type_variation = "HeaderLarge"
	label.position = get_viewport_rect().size * 0.5 - Vector2(220, 40)
	add_child(label)
	
	gameover_label.get_node("RestartButton").show()

func _on_restart_requested() -> void:
	rpc_id(1, "rpc_request_rematch")

func _reset_game_on_server() -> void:
	game_over = false
	time_left = total_time
	current_state = Gamestate.IN_GAME
	snake1.reset_snake_to_start(Vector2(100, 100))
	snake2.reset_snake_to_start(Vector2(300, 300))
	snake1.score = 0
	snake2.score = 0
	_respawn_fruit_avoiding_snakes()
	rpc("rpc_rematch_confirmed")
	print("HOST: Game successfully reset and rematch started.")

@rpc("any_peer", "reliable")
func rpc_request_rematch() -> void:
	if not NetworkManage.is_server:
		return
	
	print("HOST: Rematch requested. Resetting game...")
	_reset_game_on_server()

@rpc("reliable")
func rpc_rematch_confirmed() -> void:
	var children = get_children()
	if children.size() > 0:
		var last_child = children[children.size() - 1]
		if last_child is Label:
			last_child.queue_free()
	
	game_over = false
	time_left = total_time
	current_state = Gamestate.IN_GAME
	score_label.text = "P1: 0   P2: 0"
	timer_label.text = "Time: %d" % int(total_time) # Show full time again
	gameover_label.get_node("RestartButton").hide()
	print("Peer %d: Game reset and rematch confirmed." % multiplayer.get_unique_id())

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2)
