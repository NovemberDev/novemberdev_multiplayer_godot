extends "res://Scripts/GameInstanceBase.gd"

const INTERPOLATION_TIME = 0.1

var snapshot_buffer = []
var last_snapshot_time = 0.0
var current_client_time = 0.0
var current_rendering_time = 0.0

# lag
var lag = 0.0

# packet loss
var loss = 10
var loss_counter = 0

func _ready():
	if !NetworkManager.is_server:
		rpc_id(1, "cl_user_ready")
		$CanvasLayer/Panel/HSlider.connect("value_changed", self, "on_lag_changed")
		$CanvasLayer/End/GoToMainMenu.connect("pressed", self, "on_go_to_main_menu")
		$CanvasLayer/Panel1/HSlider.connect("value_changed", self, "on_loss_changed")

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
				if node != null and !node.is_network_master():
					
					# project the current_render_time onto the time between the snapshots
					# to find a value between 0 and 1, which is how close the values of the
					# entity should be to the second latest snapshot
					
					# get time span between oldest snapshot and current_render_time
					# then check how much this is on the timespan between the oldest and second oldest snapshot
					var t = clamp((snapshot_buffer[1].time - snapshot_buffer[0].time) / (current_rendering_time - snapshot_buffer[0].time), 0, 1)
					# lerp lerp to avoid floating point precision errors
					var dist = (snapshot_buffer[1].time - snapshot_buffer[0].time) * 550.0
					node.global_position = lerp(node.global_position, lerp(snapshot_buffer[0][entity_path].position, snapshot_buffer[1][entity_path].position, 1.0 - t), delta * dist * 0.5)

func on_lag_changed(val):
	$CanvasLayer/Panel/Label.text = "Lag: " + str(val) + "s"
	lag = val
	
func on_loss_changed(val):
	$CanvasLayer/Panel1/Label.text = "Lose every: " + str(int(val)) + " packets"
	loss = int(val)

func on_go_to_main_menu():
	LobbyService.emit_signal("client_on_gameover")
	queue_free()

func client_send_snapshot(snapshot):
	if snapshot != null:
		rpc_unreliable_id(1, "cl_snapshot", snapshot)

puppet func srv_snapshot(snapshot):
	loss_counter += 1
	if loss_counter % loss == 0:
		return
	snapshot.time = current_client_time + lag
	snapshot_buffer.push_back(snapshot)
	
puppet func srv_sync_anim(data):
	var node = get_player_node(data.id)
	if node != null:
		node.anim_tree.set(data.key, data.value)

puppet func srv_sync_bullet_position(data):
	var node = get_node(data.name)
	if node != null:
		node.target_position = data.position

puppet func srv_on_health_changed(data):
	var node = get_player_node(data.id)
	if node != null:
		node.set_health(data)
		
puppet func srv_destroy(node_name):
	if has_node(node_name):
		get_node(node_name).queue_free()

puppet func srv_instantiate(data):
	var new_instance = load(data.scene).instance()
	new_instance.set_network_master(int(data.name))
	if data.owner_id != null:
		new_instance.owner_id = data.owner_id
	if data.username != null:
		new_instance.username = data.username
	new_instance.name = data.name
	new_instance.game_instance = self
	new_instance.global_position = data.position
	get_node(data.parent_path).add_child(new_instance)
	
puppet func srv_scores(scores):
	for key in scores.keys():
		$CanvasLayer/Score.text = str(scores[key].name) + " [" + str(scores[key].score) + "]\n"
		
puppet func srv_end_game(winner_id):
	$CanvasLayer/End.visible = true
	if int(winner_id) == get_tree().get_network_unique_id():
		$CanvasLayer/End.text = "You have won the game"
	else:
		$CanvasLayer/End.text = "You have lost the game"
