extends Node2D
class_name Snake

@export var color: Color = Color.GREEN
@export var grid_size: int = 20

# Controls are editable in Inspector (click the pencil)
@export var controls: Dictionary = {
	"up": "ui_up",
	"down": "ui_down",
	"left": "ui_left",
	"right": "ui_right"
}

# Start position in WORLD coordinates (set different per snake in Inspector)
@export var start_pos: Vector2 = Vector2(100, 100)

var direction := Vector2.RIGHT
var segments: Array[Vector2] = []
var grow_amount := 0
var score := 0

@onready var move_timer: Timer = $MoveTimer
@onready var drawer: Node2D = $Drawer

func _ready() -> void:
	# IMPORTANT: keep the Snake node itself at origin so local==world space
	position = Vector2.ZERO

	segments.clear()
	segments.append(start_pos.snapped(Vector2.ONE * grid_size))
	drawer.queue_redraw()
	move_timer.timeout.connect(_on_move_timer_timeout)

func _process(_dt: float) -> void:
	_handle_input()

func _handle_input() -> void:
	if Input.is_action_pressed(controls["up"]) and direction != Vector2.DOWN:
		direction = Vector2.UP
	elif Input.is_action_pressed(controls["down"]) and direction != Vector2.UP:
		direction = Vector2.DOWN
	elif Input.is_action_pressed(controls["left"]) and direction != Vector2.RIGHT:
		direction = Vector2.LEFT
	elif Input.is_action_pressed(controls["right"]) and direction != Vector2.LEFT:
		direction = Vector2.RIGHT

func _on_move_timer_timeout() -> void:
	_move()

func _move() -> void:
	var new_head := segments[0] + direction * grid_size
	segments.insert(0, new_head)
	if grow_amount > 0:
		grow_amount -= 1
	else:
		segments.pop_back()
	drawer.queue_redraw()

func grow(cells: int = 3) -> void:
	grow_amount += cells
	score += 1

func reset_snake_to_start(start_world_pos: Vector2) -> void:
	direction = Vector2.RIGHT
	score = 0
	grow_amount = 0
	segments.clear()
	segments.append(start_world_pos.snapped(Vector2.ONE * grid_size))
	drawer.queue_redraw()
