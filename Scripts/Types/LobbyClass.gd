#
# Author: @November_Dev
# 
extends BaseClass
class_name LobbyClass

var current_game_instance
var users : Dictionary = {}
var game_instance_scene = load("res://Scenes/GameInstance.tscn")

func _init(name : String):
	._init(name)
	pass

func create_game_instance(game_instance_properties):
	current_game_instance = game_instance_scene.instance()
	current_game_instance.name = game_instance_properties.name
	current_game_instance.current_lobby = self
	LobbyService.add_child(current_game_instance)
	# Set per-game-instance properties (like map or game mode)
	# should be passed from the Lobby, a complex lobby
	# system can be implemented
	LobbyService.emit_signal("client_on_lobby_start")
