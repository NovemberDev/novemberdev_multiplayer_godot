#
# Author: @November_Dev
# 
extends Node

var Users : Dictionary = {}
var current_user : UserClass
var auto_login_creds = [
	{ user = "NovemberDev", password = "asdasdasd" }, 
	{ user = "TestUser", password = "asdasdasd"}
]

signal client_on_authorized

# Server -------
remote func cl_authenticate(data):
	var user = UserClass.new(data.name, data.password)
	if user.server_initialize_user(data.type == "register"):
		user.id = NetworkManager.caller()
		Users[NetworkManager.caller()] = user
		rpc_id(NetworkManager.caller(), "srv_authenticate", true, "Welcome " + user.name + "!", {
			name = data.name
		})
	else:
		rpc_id(NetworkManager.caller(), "srv_authenticate", false, "Invalid user", null)

func get_current_user():
	return Users[NetworkManager.caller()]

# Client -------
func client_authorize(user, password, is_register):
	if is_register:
		AuthService.rpc_id(1, "cl_authenticate", {
			type = "register",
			name = user,
			password = password
		})
	else:
		AuthService.rpc_id(1, "cl_authenticate", {
			type = "login",
			name = user,
			password = password
		})

puppet func srv_authenticate(result, message, user):
	Notifications.notify(message)
	
	if result:
		var new_user = UserClass.new(user.name, null)
		self.current_user = new_user
		emit_signal("client_on_authorized")
		
