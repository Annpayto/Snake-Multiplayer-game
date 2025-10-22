# scripts/Snake.gd
extends Node2D
class_name Snake  # lets us instantiate by type later if we want

@export var color: Color = Color.GREEN
@export var grid_size: int = 20
@export var controls := {
	"up": "ui_up",
	"down": "ui_down",
	"left": "ui_left",
	"right": "ui_right"
}

var direction := Vector2.RIGHT
var segments: Array[Vector2] = []
var grow_amount := 0
var score := 0

@onready var move_timer: Timer = $MoveTimer
@onready var drawer: Node2D = $Drawer

func _ready() -> void:
	# start with a single cell aligned to grid
	position = position.snapped(Vector2.ONE * grid_size)
	segments.clear()
	segments.append(position)
	drawer.queue_redraw()
	move_timer.timeout.connect(_on_move_timer_timeout)

func _process(_dt: float) -> void:
	_handle_input()

func _handle_input() -> void:
	# change direction but never allow immediate reversal
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
	var head := segments[0]
	var new_head := head + direction * grid_size
	segments.insert(0, new_head)

	if grow_amount > 0:
		grow_amount -= 1
	else:
		segments.pop_back()

	drawer.queue_redraw()

func grow(cells: int = 3) -> void:
	grow_amount += cells
	score += 1

# drawing lives on the Drawer child so we can call _draw
func _on_drawer_draw() -> void:
	# handled via signal hookup (see below)
	pass
