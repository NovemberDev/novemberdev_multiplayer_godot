#
# Author: @November_Dev
# 
extends BaseClass
class_name UserClass

var password
var loaded : bool = false

func _init(username : String, password):
	._init()
	
	self.id = str(NetworkManager.caller())
	self.password = password
	self.name = username

# Server -----
func server_initialize_user(is_register):
	var file = File.new()
	var directory = Directory.new()
	directory.open("user://")
	directory.make_dir("users")
	if directory.file_exists("user://users/" + self.name.to_upper() + ".json"):
		if is_register: return false
		# Warning: fragile file handling, todo: catch errors
		file.open("user://users/" + self.name.to_upper() + ".json", file.READ)
		var this_user = JSON.parse(file.get_as_text()).result
		file.close()
		if this_user != null:
			if self.password.sha256_text() == this_user.password:
				loaded = true
				return true
			else:
				return false
	elif is_register:
		file.open("user://users/" + self.name.to_upper() + ".json", file.WRITE)
		file.store_string(JSON.print({ 
			username = self.name.to_upper(), 
			password = self.password.sha256_text()
		}))
		loaded = true
		return true
	return false
