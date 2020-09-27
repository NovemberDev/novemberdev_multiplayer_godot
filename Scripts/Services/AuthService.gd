#
# Author: @November_Dev
# 
extends Node

# We allow the users to reconnect within 30 seconds to not
# lose their authorization status
const DISCONNECT_QUEUE_TIME = 30.0
var disconnect_timer = 0.0

var Users : Dictionary = {}
var current_user : UserClass
var disconnect_queue = []
var auto_login_creds = [
	{ user = "NovemberDev", password = "asdasdasd" }, 
	{ user = "TestUser", password = "asdasdasd"}
]

signal client_on_authorized
signal server_on_client_login
signal server_on_client_logout

# Since mobile networks disconnect and reconnect rapidly,
# we still keep the user profile loaded for a short period of time
# until the user gets removed from the users dictionary.
# If the user reconnects, a removal won't happen.
func _ready():
	NetworkManager.connect("server_client_disconnected", self, "queue_for_disconnect")
	NetworkManager.connect("server_client_connected", self, "dequeue_from_disconnect")
	
	if !NetworkManager.is_server:
		try_auto_login()

func _process(delta):
	disconnect_timer -= delta
	if disconnect_queue.size() > 0 and disconnect_timer <= 0.0:
		disconnect_timer = DISCONNECT_QUEUE_TIME
		var user = disconnect_queue.pop_back()
		emit_signal("server_on_client_logout", user)
		user.save_state()
		Users.erase(user.id)

# Server -------
remote func cl_authenticate(data):
	var user = UserClass.new(data)
	if user.server_initialize_user(data.type == "register"):
		dequeue_from_disconnect(user.id)
		user.id = NetworkManager.caller()
		Users[NetworkManager.caller()] = user
		rpc_id(NetworkManager.caller(), "srv_authenticate", true, "Welcome " + user.name + "!", {
			name = data.username,
			token = user.token
		})
		emit_signal("server_on_client_login", user)
	else:
		rpc_id(NetworkManager.caller(), "srv_authenticate", false, "Invalid user", null)

# Enqueue for complete disconnect including the removal from the
# Users dictionary until the next login / connection happens
func queue_for_disconnect(id):
	# User might not be authorized, but disconnects
	if Users.has(int(id)):
		disconnect_queue.push_back(Users[int(id)])

# Reconnect happened before cleanup timer elapsed
# remove user from disconnect_queue
func dequeue_from_disconnect(id):
	var index = disconnect_queue.find(int(id))
	if index != -1:
		disconnect_queue.remove(index)
		return true
	return false

func get_current_user():
	return Users[NetworkManager.caller()]

# Client -------
# If the client has a token stored locally, we attempt
# to use it for login behind the scenes
func try_auto_login():
	var token_data = Tools.open_json_file("user://token.json")
	if token_data != null:
		self.token = token_data.token
		if self.token != null:
			AuthService.rpc_id(1, "cl_authenticate", {
				token = self.token,
				type = "login"
			})

func client_authorize(username, password, type):
	AuthService.rpc_id(1, "cl_authenticate", {
		password = password,
		username = username,
		type = type
	})

puppet func srv_authenticate(result, message, user):
	Notifications.notify(message)
	
	if result:
		var new_user = UserClass.new(user)
		self.current_user = new_user
		emit_signal("client_on_authorized")
		
