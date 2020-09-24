extends Node
class_name ClientSnapshot

var position : Vector2

func to_object():
	return {
		position = position
	}
