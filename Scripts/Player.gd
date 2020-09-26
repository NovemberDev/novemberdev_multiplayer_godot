extends KinematicBody2D

const SPEED = 500.0
const SHOOT_TIMEOUT = 0.5

var username
var anim_tree
var health = 100
var game_instance
var anim_state = {}
var can_move = true
var shoot_timeout = 0.0
var direction_input = Vector2.ZERO
var aim_direction = Vector2(0, -1)

func _ready():
	anim_tree = $AnimationTree
	anim_tree.active = true

func _process(delta):
	if !is_network_master(): return
	direction_input = Vector2.ZERO
	$Camera2D.current = true
	shoot_timeout -= delta
	
	if can_move:
		if Input.is_key_pressed(KEY_W):
			direction_input.y = -1
		if Input.is_key_pressed(KEY_S):
			direction_input.y = 1
		if Input.is_key_pressed(KEY_A):
			direction_input.x = -1
		if Input.is_key_pressed(KEY_D):
			direction_input.x = 1
		if direction_input != Vector2.ZERO:
			aim_direction = direction_input
		if Input.is_action_just_pressed("ui_select") and shoot_timeout <= 0.0:
			game_instance.rpc_id(1, "cl_shoot", aim_direction)
			shoot_timeout = SHOOT_TIMEOUT
		
		client_send_snapshot()
		
		set_anim("parameters/movement/blend_position", Vector2(1, -1) * direction_input)
		set_anim("parameters/movement_time/scale", direction_input.length())
		
		move_and_slide(direction_input * SPEED)

func set_username(username):
	self.username = username
	$Info.text = str(username)

func client_send_snapshot():
	var cl_snapshot = ClientSnapshot.new()
	cl_snapshot.position = global_position
	game_instance.client_send_snapshot(cl_snapshot.to_object())

func server_handle_cl_snapshot(client_snapshot):
	global_position = client_snapshot.position

func set_anim(key, value):
	if is_network_master():
		if anim_state.has(key):
			if anim_state[key] == value:
				return
		anim_state[key] = value
		game_instance.client_object({
			id = get_tree().get_network_unique_id(),
			type = "anim",
			value = value,
			key = key
		})
		anim_tree.set(key, value)

func take_damage(bullet_owner_id, damage):
	health -= damage
	$FX.play("damage")
	game_instance.server_broadcast_object({
		type = "health",
		value = health,
		id = int(name)
	})
	if health <= 0.0:
		game_instance.server_broadcast_death(bullet_owner_id, int(name))

func die():
	if is_network_master():
		can_move = false

func set_health(data):
	health = data.health
	$Health.value = data.health
	if data.is_taking_damage:
		$FX.play("damage")
