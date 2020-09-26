extends Area2D

var DAMAGE = 25
var SPEED = 500.0
var owner_id = null
var auto_destroy = 5.0
var game_instance = null
var direction = Vector2.ZERO
var target_position = Vector2.ZERO

func _ready():
	target_position = global_position
	connect("body_entered", self, "on_body_entered")
	
func _physics_process(delta):
	if NetworkManager.is_server:
		global_position = global_position + direction * SPEED * delta
		game_instance.server_snapshot[str(name)] = { position = global_position }
		
func _process(delta):
	auto_destroy -= delta
	if auto_destroy <= 0.0:
		queue_free()

func on_body_entered(body):
	if body.is_in_group("player"):
		if int(body.name) != owner_id:
			if NetworkManager.is_server:
				queue_free()
				body.take_damage(owner_id, DAMAGE)
				game_instance.server_broadcast_destroy(name)
