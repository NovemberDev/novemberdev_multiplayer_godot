extends Node

var file = File.new()

func open_json_file(path):
	if file.open(path, file.READ) == 0:
		var data = JSON.parse(file.get_as_text()).result
		file.close()
		return data
	return null

func get_dict_val(dict, val):
	if dict.has(val):
		return dict.get(val)
	return null
