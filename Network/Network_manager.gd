extends Node

@export var snake_scene: PackedScene
@onready var game_manager_node = get_node("/root/Main/GameManager")
const DEFAULT_PORT = 54612
const MAX_PLAYERS = 2
const SERVER_IP = "127.0.0.1" 
var snake_positions: Dictionary = {}
var snake_directions: Dictionary = {}
var is_server_peer: bool = false

func server_start():  #function to start the server and sends a fail messgae if applicable
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(DEFAULT_PORT, MAX_PLAYERS) 
	
	if result != OK:
		print("Failed to start server: ", result)
		return
	
	multiplayer.multiplayer_peer = peer #create the server's id

	multiplayer.peer_connected.connect(_on_peer_connected) # instances for connected and disconnected 
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("Server started on port %d! Max players: %d" % [DEFAULT_PORT, MAX_PLAYERS]) # a indication the server started


func client_start():  # fucnction to create the player 
	var peer = ENetMultiplayerPeer.new()

	var result = peer.create_client(SERVER_IP, DEFAULT_PORT) # creates the client for the player
	
	if result != OK:
		print("Failed to start client (connection attempt failed): ", result)
		return
		
	multiplayer.multiplayer_peer = peer #makes the player similiar to the server
	
	multiplayer.connection_failed.connect(_on_connection_failed) #tells if the client failed to connect
	multiplayer.connected_to_server.connect(_on_connected_to_server) #tells if they failed to connect to server
	
	print("Attempting to connect to server at %s:%d..." % [SERVER_IP, DEFAULT_PORT]) #nice little load message

func end_network(): #func to close the network
	multiplayer.peer_connected.disconnect(_on_peer_connected)
	multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	multiplayer.connection_failed.disconnect(_on_connection_failed)
	multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("Network ended.")

func _on_peer_connected(id): # connects the peer and creates a snake for the player
	print("Client connected! Peer ID: ", id)
	if is_server_peer:
		spawn_snake.rpc(id)


func _on_peer_disconnected(id):
	print("Client disconnected! Peer ID: ", id)
	if is_server_peer:
		delete_snake.rpc(id)

@rpc("call_local", "unreliable")
func spawn_snake(id: int):
	var snake_node = snake_scene.instantiate() as Node2D
	snake_node.set_multiplayer_authority(id)
	snake_node.name = "Snake_" + str(id)
	
	get_tree().root.add_child(snake_node)
	snake_positions[id] = snake_node.start_pos.snapped(Vector2.ONE * snake_node.grid_size)
	snake_directions[id] = Vector2.RIGHT
	var main_node = get_node("/root/Main")
	
	if is_instance_valid(main_node) and main_node.has_method("register_snake"):
		main_node.register_snake(id, snake_node)
	
	print("Spawned snake for peer ID: ", id)

@rpc("call_local", "unreliable")
func delete_snake(id: int):
	var snake_node = get_tree().root.get_node_or_null("Snake_" + str(id))
	if is_instance_valid(snake_node):
		snake_node.queue_free()
	
	snake_positions.erase(id)
	snake_directions.erase(id)
	
	var main_node = get_node("/root/Main")
	if is_instance_valid(main_node) and main_node.has_method("unregister_snake"):
		main_node.unregister_snake(id)
	
	print("Deleted snake for peer ID: ", id)



func _on_connected_to_server():
	print("Successfully connected to server!")


func _on_connection_failed():
	print("Connection failed! Make sure the server is running.")

func get_id() -> int: #func to get player id
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()

func is_server() -> bool: #bool for us to initialize server
	return multiplayer.is_server()

func _ready(): #func to test server and client
	if OS.get_cmdline_args().has("--server"):
		server_start()
	else:
		client_start()
	
	if multiplayer.multiplayer_peer:
		is_server_peer = (multiplayer.get_unique_id() == 1)
		
	if is_server():
		print("I am the server. My network ID: ", get_id())
		spawn_snake(1)
	else:
		print("I am a client. My network ID (after connecting): ", get_id())
