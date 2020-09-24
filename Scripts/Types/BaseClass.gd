#
# Author: @November_Dev
# 
extends Node
class_name BaseClass

var id : String

func _init(name = null):
	self.id = UUID.NewID()
	
	if name == null:
		self.name = str(self.id)
	else:
		self.name = name
