extends Node3D

@export var Mouse_Sensitivity = 0.05
@export var CameraLenght = 7
@export var FollowSpeed = 5.0
@onready var SpringArm = $SpringArm3D
@onready var Player = $".."
@onready var CameraHeight = $"../CameraHeight"



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
	global_position = lerp(global_position, CameraHeight.global_position, FollowSpeed * delta)
	pass
