#
# Author: @November_Dev
# 
extends Node

var waiting_queue = []
var lobbies : Dictionary = {}
var current_lobby : LobbyClass

signal client_on_gameover
signal client_on_lobby_start
signal server_on_lobby_created
signal server_on_game_instance_created

func _ready():
	set_network_master(1)

# Client ------
func client_play():
	rpc_id(1, "cl_quick_play")

puppet func srv_create_game_instance(game_instance_properties):
	if current_lobby != null:
		if is_instance_valid(current_lobby):
			current_lobby.queue_free()
	current_lobby = LobbyClass.new(game_instance_properties.lobby_name)
	LobbyService.add_child(current_lobby)
	current_lobby.create_game_instance(game_instance_properties)

# Server ------
remote func cl_quick_play():
	waiting_queue.push_back(AuthService.get_current_user())

func _process(delta):
	if waiting_queue.size() >= 2:
		on_match_found()

func on_match_found():
	# create lobby
	var new_lobby = LobbyClass.new(UUID.NewID())
	lobbies[new_lobby.name] = new_lobby
	var user1 = waiting_queue.pop_front()
	new_lobby.users[user1.id] = user1
	var user2 = waiting_queue.pop_front()
	new_lobby.users[user2.id] = user2
	emit_signal("server_on_lobby_created", new_lobby)
	
	# in this case we launch the game instantly,
	# we don't show a lobby with a list of players,
	# options or other fancy things
	var game_instance_properties = {
		name = UUID.NewID(),
		lobby_name = new_lobby.name
	}
	new_lobby.create_game_instance(game_instance_properties)
	rpc_id(int(user1.id), "srv_create_game_instance", game_instance_properties)
	rpc_id(int(user2.id), "srv_create_game_instance", game_instance_properties)
	emit_signal("server_on_game_instance_created", new_lobby)
