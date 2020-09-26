#
# Author: @November_Dev
# 
extends Node
class_name ClientSnapshot

# This class can be 
# extended by more properties
# that will be set inside the
# Player script
var position : Vector2

# This method will get all properties
# we want to send to the server
func to_object():
	return {
		position = position
	}
