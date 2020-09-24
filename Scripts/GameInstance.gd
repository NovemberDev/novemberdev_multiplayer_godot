#
# Author: @November_Dev
# 
extends Node2D

const MAX_SCORE = 5

var current_lobby
var ready_count = 0

var timestep = 0.03
var current_time = 0.0
var old_snapshot = {}
var new_snapshot = {}
var server_snapshot = {}
var server_scores = {}
var spawn_counter = 0

var bullet_scene = "res://Scenes/Bullet.tscn"
var client_user_scene = "res://Scenes/Player.tscn"
var server_user_scene = load("res://Scenes/Player.tscn")
var spawns = [Vector2(-282, 0), Vector2(282, 0), Vector2(0, 282), Vector2(0, -282)]

func _ready():
	set_network_master(1)
	if !NetworkManager.is_server:
		rpc_id(1, "cl_user_ready")
		$CanvasLayer/End/GoToMainMenu.connect("pressed", self, "on_go_to_main_menu")

func _process(delta):
	if NetworkManager.is_server:
		current_time += delta
		if current_time >= timestep:
			current_time = 0.0
			for user in current_lobby.users.values():
				rpc_unreliable_id(int(user.id), "srv_snapshot", server_snapshot)
	else:
		for key in new_snapshot.keys():
			var node = get_player_node(key)
			if node != null:
				if !node.is_network_master():
					node.global_position = node.global_position.linear_interpolate(new_snapshot[key].position, delta * (new_snapshot[key].position - node.global_position).length()/5)
					if (node.global_position - new_snapshot[key].position).length() > 500:
						node.global_position = new_snapshot[key].position

func on_go_to_main_menu():
	LobbyService.emit_signal("client_on_gameover")
	queue_free()
	
func get_player_node(id):
	if has_node("PLAYERS/" + str(id)):
		return get_node("PLAYERS/" + str(id))
	return null

puppet func srv_snapshot(snapshot):
	old_snapshot = new_snapshot
	new_snapshot = snapshot
	
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
	
# Server ------
func server_start_round():
	spawn_counter = 0
	for user in current_lobby.users.values():
		server_scores[int(user.id)] = {
			name = user.name,
			score = 0
		}
		server_respawn(int(user.id))
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_scores", server_scores)

func server_respawn(id):
	var user = current_lobby.users[str(id)]
	if spawn_counter >= spawns.size()-1:
		spawn_counter = 0
	var data = {
		owner_id = null,
		name = str(user.id),
		username = user.name,
		parent_path = "PLAYERS",
		scene = client_user_scene,
		position = spawns[spawn_counter]
	}
	for peer in current_lobby.users.values():
		rpc_id(int(peer.id), "srv_instantiate", data)
	srv_instantiate(data)
	spawn_counter += 1

func server_broadcast_death(killer_id, id):
	server_scores[int(killer_id)].score += 1
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_scores", server_scores)
	
	if server_scores[int(killer_id)].score >= MAX_SCORE:
		server_end_game(killer_id)

func server_broadcast_health(id, health, is_taking_damage):
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_on_health_changed", {
			id = id,
			health = health,
			is_taking_damage = is_taking_damage
		})

func server_broadcast_bullet_position(bullet_name, global_position):
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_sync_bullet_position", {
			name = bullet_name,
			position = global_position
		})

func server_broadcast_destroy(node_name):
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_destroy", node_name)

func server_end_game(winner_id):
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_end_game", winner_id)

remote func cl_user_ready():
	ready_count += 1
	# clients might crash and this value will never increment fully,
	# if that happens run a timeout timer to cancel the game if that
	# happens
	if ready_count >= 2:
		server_start_round()

remote func cl_sync_transform(data):
	server_snapshot[NetworkManager.caller()] = data
	var node = get_player_node(NetworkManager.caller())
	if node != null:
		node.global_position = server_snapshot[NetworkManager.caller()].position

remote func cl_sync_anim(data):
	data.id = NetworkManager.caller()
	for user in current_lobby.users.values():
		rpc_id(int(user.id), "srv_sync_anim", data)

remote func cl_shoot(direction):
	var node = get_player_node(NetworkManager.caller())
	if node != null:
		var new_bullet = load(bullet_scene).instance()
		new_bullet.owner_id = NetworkManager.caller()
		new_bullet.name = "bullet_" + UUID.NewID().substr(0, 8)
		new_bullet.direction = direction.normalized()
		new_bullet.game_instance = self
		new_bullet.global_position = node.global_position + direction.normalized() * 100.0
		add_child(new_bullet)
		var data = {
			username = null,
			parent_path = ".",
			scene = bullet_scene,
			name = new_bullet.name,
			owner_id = NetworkManager.caller(),
			position = new_bullet.global_position
		}
		for user in current_lobby.users.values():
			rpc_id(int(user.id), "srv_instantiate", data)
