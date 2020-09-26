extends "res://Scripts/GameInstanceClient.gd"

var ready_count = 0
var timestep = 0.03
var current_time = 0.0
var server_snapshot = {}
var server_tracked_objects = []
var server_tracked_node_instances = {}

func _process(delta):
	if NetworkManager.is_server:
		current_time += delta
		if current_time >= timestep:
			current_time = 0.0
			for id in server_snapshot.keys():
				var node = get_player_node(id)
				if node != null:
					node.server_handle_cl_snapshot(server_snapshot[id])
			for user in current_lobby.users.values():
				rpc_unreliable_id(int(user.id), "srv_snapshot", server_snapshot)

# User signals that they are ready,
# replicate every node that has been created
# and do the same with all objects that have
# been sent
remote func cl_user_ready():
	ready_count += 1
	for tracked_node in server_tracked_node_instances.values():
		rpc_id(int(NetworkManager.caller()), "srv_instantiate", tracked_node)
	for tracked_obj in server_tracked_objects:
		rpc_id(int(NetworkManager.caller()), "srv_object", tracked_obj)
	_on_user_ready()

# Keep track of the latest values
# on a per-client basis
remote func cl_snapshot(client_snapshot):
	server_snapshot["PLAYERS/" + str(NetworkManager.caller())] = client_snapshot
	var node = get_player_node(NetworkManager.caller())
	if node != null:
		node.global_position = server_snapshot["PLAYERS/" + str(NetworkManager.caller())].position
		_on_client_snapshot_updated(server_snapshot["PLAYERS/" + str(NetworkManager.caller())])

remote func cl_sync_anim(data):
	_on_client_broadcast_animation(data)
	data.id = NetworkManager.caller()
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_sync_anim", data)

# Removes a node across all clients and
# remove it from the tracked instances,
# so new clients dont create this node
func server_queue_free_broadcast(name, path):
	if server_tracked_node_instances.has(name):
		server_tracked_node_instances.erase(name)
	game_instance_queue_free(path)
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_destroy", path)

# Instantiates a node across all clients,
# we also keep track of the new instance to
# instantiate it on new clients as well when we
# initially sync the game for them
func server_instantiate_broadcast(data):
	server_tracked_node_instances[name] = data
	var new_instance = game_instance_instantiate(data)
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_instantiate", data)
	_on_server_instantiate(data, new_instance)
	
# Broadcasts an object with values
# to every client (convenience)
func server_broadcast_object(obj):
	server_tracked_objects.push_back(obj)
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_object", obj)

# Broadcasts an object with values
# to every client from another client
remote func cl_broadcast_object(obj):
	server_tracked_objects.push_back(obj)
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_object", obj)

# Abstract methods,
# Override these if you need
# their functionality

# A connected user signals ready
func _on_user_ready(): pass

# A client sent their world state,
# keep track of additional values if needed
# (quaternion rotations, velocity, timestamps...)
func _on_client_snapshot_updated(client_snapshot): pass

# We are about to relay a clients
# reliable animation change to other clients
func _on_client_broadcast_animation(data): pass
func _on_server_instantiate(data, instance): pass
