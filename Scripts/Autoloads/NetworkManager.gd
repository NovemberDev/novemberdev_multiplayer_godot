#
# Author: @November_Dev
# 
extends Node

# Server
var is_server
var server_port = 3333
var WSS : WebSocketServer

# Client
var retry_time = 5.0
var client_url = "ws://127.0.0.1:"
var retry_timer = 0.0
var retry_connecting
var WSC : WebSocketClient

signal client_on_connected
signal client_on_disconnected
signal client_start_connecting
signal server_client_connected
signal server_client_disconnected

func _ready():
	for i in range(OS.get_cmdline_args().size()):
		match OS.get_cmdline_args()[i]:
			"--server":
				is_server = true
			"--userindex":
				get_node("/root/Main_Menu").set_auto_login(int(OS.get_cmdline_args()[i+1]))
	
	if !is_server:
		connect("client_start_connecting", self, "client_try_connect")
	else:
		print("Server init...")
		WSS = WebSocketServer.new()
		WSS.listen(3333, PoolStringArray([]), true)
		get_tree().set_network_peer(WSS)
		get_tree().network_peer.connect("peer_connected", self, "server_on_peer_connected")
		get_tree().network_peer.connect("peer_disconnected", self, "server_on_peer_disconnected")
		OS.set_window_title("Server on Port " + str(server_port))
		OS.window_minimized = true

# Server & Client
func _process(delta):
	if is_server:
		WSS.poll()
	else:
		if WSC.get_connection_status() == WSC.CONNECTION_CONNECTING or WSC.get_connection_status() == WSC.CONNECTION_CONNECTED:
			WSC.poll()
		
		if retry_connecting:
			if retry_timer < 0.0:
				client_try_connect()
				retry_timer = retry_time
			retry_timer -= delta

# Client -----------
func client_try_connect():
	retry_connecting = true
	WSC = WebSocketClient.new()
	WSC.connect_to_url(client_url + str(server_port), PoolStringArray([]), true)
	set_network_master(1)
	get_tree().set_network_peer(WSC)
	get_tree().network_peer.connect("connection_succeeded", self, "client_on_connected")
	get_tree().network_peer.connect("connection_failed", self, "client_on_disconnect_server")
	get_tree().network_peer.connect("server_disconnected", self, "client_on_disconnect_server")

func client_on_disconnect_server():
	Notifications.notify("Disconnected from Online-Services")
	if !retry_connecting:
		emit_signal("client_on_disconnected")
	retry_connecting = true
	
func client_on_connected():
	retry_connecting = false
	Notifications.notify("Connected to Online-Services")
	emit_signal("client_on_connected")

# Server -----------
func server_on_peer_connected(id):
	Notifications.notify("Peer connected: " + str(id))
	emit_signal("server_client_connected", int(id))
	
func server_on_peer_disconnected(id):
	Notifications.notify("Peer disconnected " + str(id))
	emit_signal("server_client_disconnected", int(id))

func caller():
	return get_tree().get_rpc_sender_id()
