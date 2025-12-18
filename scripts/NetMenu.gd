#Copywrite Andon and Harrison
extends Control

@onready var host_button: Button = $VBox/HostButton
@onready var join_button: Button = $VBox/JoinButton
@onready var ip_edit: LineEdit = $VBox/IpEdit
@onready var status_label: Label = $VBox/StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	# listen for signal from the autoload
	NetworkManage.connected_to_server.connect(_on_connected_to_server)

func _on_host_pressed() -> void:
	NetworkManage.start_server()
	status_label.text = "Server started. Loading game..."
	# host immediately loads the game scene
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_join_pressed() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"  
	status_label.text = "Connecting to %s..." % ip
	NetworkManage.connect_to_server(ip)

func _on_connected_to_server() -> void:
	status_label.text = "Connected! Loading game..."
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
