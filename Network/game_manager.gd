extends Node

var player_positions: Dictionary = {}
const MAX_SPEED = 5.5
func _enter_tree():
	multiplayer.set_multiplayer_authority(1)


@rpc("any_peer") #game state check to make sure player is moving correctly
func client_request_move(new_position: Vector3):
	
	var caller_id = multiplayer.get_calling_peer()
	
	if not player_positions.has(caller_id):
		
		print("Error: Move request from untracked peer: ", caller_id)
		return
	
	var current_position = player_positions[caller_id]
	var distance = current_position.distance_to(new_position)
	
	var max_allowed_distance = MAX_SPEED * get_physics_process_delta_time() * 2 
	
	if distance > max_allowed_distance: #checks if player is moving to fast
		print("Move rejected" % [caller_id, distance])
		
		sync_position_to_clients.rpc(caller_id, current_position)
		return
	
	player_positions[caller_id] = new_position
	print("move accepted" % [caller_id, new_position])
	
	sync_position_to_clients.rpc(caller_id, new_position)

@rpc("authority")  #this is to sync player movement with server
func sync_position_to_clients(peer_id_to_move: int, position: Vector3):
	
	var player_node = get_node_or_null("Player_" + str(peer_id_to_move))
	if is_instance_valid(player_node):
		player_node.global_position = position
