#Copywrite Andon and Harrison
extends Node2D
class_name Snake

@export var color: Color = Color.GREEN
@export var grid_size: int = 20

# Input actions this snake uses – set in node inspector
@export var controls: Dictionary = {
	"up": "ui_up",
	"down": "ui_down",
	"left": "ui_left",
	"right": "ui_right",
}

# Start position in world coordinates
@export var start_pos: Vector2 = Vector2(100, 100)

var direction: Vector2 = Vector2.RIGHT
var segments: Array[Vector2] = []
var grow_amount: int = 0
var score: int = 0

@onready var move_timer: Timer = $MoveTimer
@onready var drawer: Node2D = $Drawer


func _ready() -> void:
	# Keep node at origin
	position = Vector2.ZERO

	segments.clear()
	segments.append(start_pos.snapped(Vector2.ONE * grid_size))
	drawer.queue_redraw()

	if NetworkManage.is_server:
		# Only host runs movement
		move_timer.timeout.connect(_on_move_timer_timeout)
	else:
		# Clients just render synced data
		move_timer.stop()


func _on_move_timer_timeout() -> void:
	_move()

func _move() -> void:
	if segments.is_empty():
		return

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
