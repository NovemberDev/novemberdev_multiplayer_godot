#
# Author: @November_Dev
# 
extends "res://Scripts/GameInstanceServer.gd"

var bullet_scene = "res://Scenes/Bullet.tscn"
var client_user_scene = "res://Scenes/Player.tscn"
var server_user_scene = load("res://Scenes/Player.tscn")

# Client ------
func _ready():
	if !NetworkManager.is_server:
		rpc_id(1, "cl_user_ready")
		$CanvasLayer/Panel/HSlider.connect("value_changed", self, "on_lag_changed")
		#$CanvasLayer/End/GoToMainMenu.connect("pressed", self, "on_go_to_main_menu")
		$CanvasLayer/Panel1/HSlider.connect("value_changed", self, "on_loss_changed")

# Server sent us an object, dissect it
func _on_server_object_received(obj):
	if Tools.get_dict_val(obj, "type") == "anim":
		var node = get_player_node(obj.id)
		if node != null:
			node.anim_tree.set(obj.key, obj.value)
	elif Tools.get_dict_val(obj, "score") != null:
		$CanvasLayer/Score.text = obj.score

# When we create an instance, we check if extra params
# have been supplied to set properties on these new instances
func _on_server_instantiate(data, instance):
	if instance == null: return
	._on_server_instantiate(data, instance)
	if Tools.get_dict_val(data.params, "direction") != null:
		instance.direction = data.params.direction
		return
	var username = Tools.get_dict_val(data.params, "username")
	if username != null:
		instance.set_username(username)

func on_go_to_main_menu():
	LobbyService.emit_signal("client_on_gameover")
	queue_free()

func on_lag_changed(val):
	$CanvasLayer/Panel/Label.text = "Lag: " + str(val) + "s"
	lag = val
	
func on_loss_changed(val):
	$CanvasLayer/Panel1/Label.text = "Lose every: " + str(int(val)) + " packets"
	loss = int(val)

#puppet func srv_sync_bullet_position(data):
#	var node = get_node(data.name)
#	if node != null:
#		node.target_position = data.position
#
#puppet func srv_on_health_changed(data):
#	var node = get_player_node(data.id)
#	if node != null:
#		node.set_health(data)
#
#puppet func srv_sync_anim(data):
#	var node = get_player_node(data.id)
#	if node != null:
#		node.anim_tree.set(data.key, data.value)

#puppet func srv_scores(scores):
#	for key in scores.keys():
#		$CanvasLayer/Score.text = str(scores[key].name) + " [" + str(scores[key].score) + "]\n"
#
#puppet func srv_end_game(winner_id):
#	$CanvasLayer/End.visible = true
#	if int(winner_id) == get_tree().get_network_unique_id():
#		$CanvasLayer/End.text = "You have won the game"
#	else:
#		$CanvasLayer/End.text = "You have lost the game"


# Server ------

# Override: when a user is done connecting and
# ready to play, we spawn their character across
# all other clients
func _on_user_ready():
	server_instantiate_broadcast({
		position = get_node("SPAWNS/" + str(randi()%($SPAWNS.get_child_count() - 1))).global_position,
		owner_id = str(NetworkManager.caller()),
		name = str(NetworkManager.caller()),
		scene = client_user_scene,
		path = "PLAYERS",
		params = {
			username = current_lobby.users[str(NetworkManager.caller())].name,
			set_game_instance = true
		}
	})
	
	# if more than one player 
	# is ready, we start
	if ready_count > 1:
		server_broadcast_object({
			score = get_score()
		})

func get_score():
	var res = "Scores:\n"
	for user in current_lobby.users.values():
		res += str(user.name) + "[" + str(user.score) + "]\n"
	return res

# User shoots a bullet, 
# instantiate it across all clients
remote func cl_shoot(direction):
	var node = get_player_node(NetworkManager.caller())
	if node != null:
		server_instantiate_broadcast({
			position = node.global_position + direction.normalized() * 100.0,
			name = "bullet_" + UUID.NewID().substr(0, 8),
			owner_id = str(NetworkManager.caller()),
			scene = bullet_scene,
			path = ".",
			params = {
				username = current_lobby.users[str(NetworkManager.caller())].name,
				set_game_instance = true,
				direction = direction
			}
		})

#var server_scores = {}
#var spawn_counter = 0
#
#const MAX_SCORE = 5
#
#func server_broadcast_death(killer_id, id):
#	server_scores[int(killer_id)].score += 1
#	for user in current_lobby.users.values():
#		rpc_id(int(user.id), "srv_scores", server_scores)
#
#	if server_scores[int(killer_id)].score >= MAX_SCORE:
#		server_end_game(killer_id)
#
#func server_broadcast_health(id, health, is_taking_damage):
#	for user in current_lobby.users.values():
#		rpc_id(int(user.id), "srv_on_health_changed", {
#			id = id,
#			health = health,
#			is_taking_damage = is_taking_damage
#		})
#
#func server_broadcast_bullet_position(bullet_name, global_position):
#	for user in current_lobby.users.values():
#		rpc_id(int(user.id), "srv_sync_bullet_position", {
#			name = bullet_name,
#			position = global_position
#		})


