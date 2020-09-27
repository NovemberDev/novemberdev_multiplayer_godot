extends "res://Scripts/GameInstanceBase.gd"

# Interpolation time is at 100ms
# since the server runs at 20 fps
# and the snapshot interval is therefore 50ms.
# 100ms gives us air around >= 3 packets
const INTERPOLATION_TIME = 0.1

var snapshot_buffer = []
var last_snapshot_time = 0.0
var current_client_time = 0.0
var current_rendering_time = 0.0

func _process(delta):
	if !NetworkManager.is_server:
		current_client_time += delta
		current_rendering_time = current_client_time - INTERPOLATION_TIME
		
		# if we have any snapshots
		if snapshot_buffer.size() > 1:
			
			# if we have more than 2 snapshots (3 or more)
			# where the second oldest snapshot's time is way behind the rendering time
			while(snapshot_buffer.size() > 2 and current_rendering_time >= snapshot_buffer[1].time):
				# drop the oldest snapshot, because it is outdated
				snapshot_buffer.pop_front()
			
			# loop all entities within the second oldest snapshot
			for entity_path in snapshot_buffer[1].keys():
				var node = get_node2(entity_path)
				if node != null and !(node.is_network_master() and node.is_in_group("player")):
					if !snapshot_buffer[0].has(entity_path): continue
					if !snapshot_buffer[1].has(entity_path): continue
					
					# get the current_render_time between the snapshots
					# and transform it to a value between 0 and 1, which 
					# is how close the values of the entity should be to 
					# the second latest snapshot
					
					# get time span between oldest snapshot and current_render_time
					# then check how much this is on the timespan between the oldest and second oldest snapshot
					var t = clamp((snapshot_buffer[1].time - snapshot_buffer[0].time) / (current_rendering_time - snapshot_buffer[0].time), 0, 1)
					# lerp lerp, it do be smooth
					var dist = (snapshot_buffer[1].time - snapshot_buffer[0].time) * 550.0
					node.global_position = lerp(node.global_position, 
							lerp(snapshot_buffer[0][entity_path].position, 
							snapshot_buffer[1][entity_path].position, 1.0 - t), 
							delta * dist * 0.5)
					
	
func client_send_snapshot(snapshot):
	if snapshot != null:
		rpc_unreliable_id(1, "cl_snapshot", snapshot)

func client_object(obj):
	rpc_id(1, "cl_broadcast_object", obj)

puppet func srv_snapshot(snapshot):
	if loss > 1:
		loss_counter += 1
		if loss_counter % loss == 0:
			return
	snapshot.time = current_client_time + lag
	snapshot_buffer.push_back(snapshot)
	
puppet func srv_object(obj):
	_on_server_object_received(obj)
	
puppet func srv_instantiate(data):
	var new_instance = game_instance_instantiate(data)
	_on_server_instantiate(data, new_instance)
	
puppet func srv_destroy(path):
	game_instance_queue_free(path)
	
# Abstract methods,
# Override these if you need
# their functionality
func _on_server_object_received(obj): pass
func _on_server_instantiate(data, new_instance): pass
