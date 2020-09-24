extends Node2D

var current_lobby

func _ready():
	set_network_master(1)

func get_player_node(id):
	return get_node2("PLAYERS/" + str(id))

func get_node2(path):
	if has_node(str(path)):
		return get_node(str(path))
	return null

