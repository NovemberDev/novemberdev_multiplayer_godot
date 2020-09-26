#
# Author: @November_Dev
# 
extends BaseClass
class_name UserClass

var token
var password
var loaded : bool = false

# Extra properties
var score = 0

func _init(data):
	._init()
	
	self.id = str(NetworkManager.caller())
	self.password = Tools.get_dict_val(data, "password")
	var n = Tools.get_dict_val(data, "username")
	if n != null: 
		self.name = n
	self.token = Tools.get_dict_val(data, "token")

# Server -----
func server_initialize_user(is_register):
	var directory = Directory.new()
	directory.open("user://")
	directory.make_dir("users")
	print(self.name)
	# if the user supplied a token
	if token != null:
		# we open a file that is named by the token and extract the username 
		# for further processing
		var user_info = Tools.open_json_file("user://users/" + self.token.to_upper() + ".json")
		print(user_info)
		if user_info != null:
			self.name = user_info.name
	if directory.file_exists("user://users/" + self.name.to_upper() + ".json"):
		if is_register: return false
		var this_user = Tools.open_json_file("user://users/" + self.name.to_upper() + ".json")
		if this_user == null: 
			return false
		if this_user != null:
			if self.password.sha256_text() == this_user.password:
				loaded = true
				return true
			else:
				return false
	elif is_register:
		var file = File.new()
		self.token = UUID.NewID().sha256_text()
		if file.open("user://users/" + self.token.to_upper() + ".json", file.WRITE) == 0:
			file.store_string(JSON.print({
				name = self.name.to_upper()
			}))
			file.close()
		if file.open("user://users/" + self.name.to_upper() + ".json", file.WRITE) == 0:
			file.store_string(JSON.print({ 
				username = self.name.to_upper(), 
				password = self.password.sha256_text()
			}))
			file.close()
			loaded = true
			return true
	return false
