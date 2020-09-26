extends Node2D

# lag
var lag = 0.0

# packet loss
var loss = 10
var loss_counter = 0

var current_lobby

func _ready():
	set_network_master(1)

# Get the player node by User-Id
func get_player_node(id):
	return get_node2("PLAYERS/" + str(id))

# Check if the node exists 
# before getting it
func get_node2(path):
	if has_node(str(path)):
		return get_node(str(path))
	return null

func game_instance_instantiate(data):
	if !has_node(data.path + "/" + str(data.name)):
		var new_instance = load(data.scene).instance()
		new_instance.set_network_master(int(data.owner_id))
		new_instance.global_position = data.position
		new_instance.name = str(data.name)
		if Tools.get_dict_val(data.params, "set_game_instance"):
			new_instance.game_instance = self
		get_node(data.path).add_child(new_instance)
		return new_instance
	return null

func game_instance_queue_free(path):
	if has_node(path):
		get_node(path).queue_free()
