extends Node

enum Personality { SAD, ANGRY, HAPPY, LOVE }
var current_personality: int = Personality.SAD

@export_category("Pulse Settings")
@export var max_pulse_radius: float = 1500.0
@export var min_pulse_radius: float = 0.0

@export_group("Durations (Seconds)")
@export var open_duration: float = 1.0   # Time it takes to fully grow
@export var close_duration: float = 0.2  # Time it takes to shrink (Low number = fast snap)


@onready var timer: Label = $CanvasLayer2/Timer

# Dictionary to track the size of every personality circle
var radii: Dictionary = {
	Personality.SAD: 0.0,
	Personality.ANGRY: 0.0,
	Personality.HAPPY: 0.0,
	Personality.LOVE: 0.0
}

# Store the active tween so we can interrupt it if personality changes fast
var _tween: Tween

var main_cam: Node2D

var Started : bool = false
var IS_paused : bool = false


@onready var transtion: ColorRect = $CanvasLayer2/Transtion
@onready var settings: MarginContainer = $CanvasLayer2/Settings
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# Initialize the shader values immediately on start
	#$CanvasLayer2/Timer.start_timer()
	_update_all_shader_params()

func Start():
	Started = true
	animation_player.play("Start")
	await get_tree().create_timer(0.5).timeout 
	get_tree().change_scene_to_file("res://Sceen/test_map.tscn")
	animation_player.play("Start_Level")
	$CanvasLayer2/Timer.start_timer()

func Restart():
	Started = false
	animation_player.play("Start")
	await get_tree().create_timer(0.5).timeout 
	get_tree().change_scene_to_file("res://Sceen/main_menu.tscn")
	animation_player.play("Start_Level")


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Pause"):
		if IS_paused:
			settings.visible = false
			Engine.time_scale = 1
		else:
			settings.visible = true
			Engine.time_scale = 0
		IS_paused = not IS_paused

func main_cam_update(area):
	main_cam.start_pos.y = area.global_position.y

func ChangePersonality(new_personality: int) -> void:
	current_personality = new_personality
	
	# update the integer uniform immediately
	RenderingServer.global_shader_parameter_set("current_personality", current_personality)
	
	# If a tween is already running, kill it so we don't have fighting animations
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	# IMPORTANT: This makes all animations happen simultaneously 
	# (e.g., Sad closes WHILE Happy opens)
	_tween.set_parallel(true)
	
	for p in Personality.values():
		var target_radius = min_pulse_radius
		var duration = close_duration
		
		# If this is the new active personality, set targets to Open
		if p == current_personality:
			target_radius = max_pulse_radius
			duration = open_duration
			
		# We use tween_method so we can run a function every frame of the animation
		# We bind 'p' (the personality type) to the function
		_tween.tween_method(
			_update_single_radius.bind(p), # Function to call
			radii[p],                      # Start value (current size)
			target_radius,                 # End value
			duration                       # Time to complete
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC) 

# This function is called by the Tween every frame during animation
func _update_single_radius(value: float, p: int) -> void:
	# 1. Update internal dictionary
	radii[p] = value
	
	# 2. Update the specific Shader Parameter
	var param_name = ""
	match p:
		Personality.SAD: param_name = "sad_vision_radius"
		Personality.ANGRY: param_name = "angry_vision_radius"
		Personality.HAPPY: param_name = "happy_vision_radius"
		Personality.LOVE: param_name = "love_vision_radius"
	
	RenderingServer.global_shader_parameter_set(param_name, value)

# Helper to force set all values (used in _ready)
func _update_all_shader_params() -> void:
	RenderingServer.global_shader_parameter_set("sad_vision_radius", radii[Personality.SAD])
	RenderingServer.global_shader_parameter_set("angry_vision_radius", radii[Personality.ANGRY])
	RenderingServer.global_shader_parameter_set("happy_vision_radius", radii[Personality.HAPPY])
	RenderingServer.global_shader_parameter_set("love_vision_radius", radii[Personality.LOVE])
	RenderingServer.global_shader_parameter_set("current_personality", current_personality)


func _on_close_pressed() -> void:
	Engine.time_scale = 1.0
	animation_player.play("Start")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
