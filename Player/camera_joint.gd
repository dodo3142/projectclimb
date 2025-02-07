extends Node3D

@export var Mouse_Sensitivity = 0.05
@export var CameraLenght = 7
@onready var SpringArm = $SpringArm3D
@onready var Player = $".."
@onready var CameraHeight = $"../CameraHeight"


const FOLLOW_SPEED = 5.0
const ROTATE_SPEED = 2.0
const DISTANCE = Vector3(0, 5, -10) # Initial distance from the Player
const HEIGHT_OFFSET = 2.0

func _ready():
	top_level = true
	SpringArm.spring_length = CameraLenght
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	if Input.is_action_just_released("Pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotation_degrees.x -= event.relative.y * Mouse_Sensitivity
		rotation_degrees.x = clamp(rotation_degrees.x, -90, 30)
		
		rotation_degrees.y -= event.relative.x * Mouse_Sensitivity
		rotation_degrees.y = wrapf(rotation_degrees.y, 0, 360)
		

func _physics_process(delta):
	global_position = lerp(global_position, CameraHeight.global_position, 20 * delta)
	#follow_player(delta)
	pass

func follow_player(delta):
	if Player:
		var target_position = Player.global_transform.origin 
		
		var new_position = position.lerp(target_position, FOLLOW_SPEED * delta)
		
		position = new_position
		
		look_at(Player.global_transform.origin, Vector3(0, 1, 0))
		
		var rotation_direction = Vector3(0, Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"), 0)
		rotate_y(rotation_direction.x * ROTATE_SPEED * delta)
		
