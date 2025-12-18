#Copywrite Andon and Harrison
extends Node
class_name NetworkManager

signal connected_to_server
signal client_connected(id)
signal client_disconnected(id)

var is_server := false
var max_players := 2
var port := 9000
var server_ip := "127.0.0.1"

func _enter_tree() -> void:
	print("NetworkManager loaded")

func start_server():
	is_server = true
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, max_players)
	if result != OK:
		printerr("Failed to start server on port %d" % port)
		return
	multiplayer.multiplayer_peer = peer
	print("Server started on port", port)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Waiting for players...")

func connect_to_server(ip: String):
	is_server = false
	server_ip = ip
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(ip, port)
	if result != OK:
		printerr("Failed to connect to server")
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	print("Connecting to server at %s:%d..." % [ip, port])

func _on_connected_to_server():
	print("Connected to server")
	connected_to_server.emit()

func _on_peer_connected(id):
	print("Client connected:", id)
	client_connected.emit(id)

func _on_peer_disconnected(id):
	print("Client disconnected:", id)
	client_disconnected.emit(id)
