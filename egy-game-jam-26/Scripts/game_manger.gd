extends Node

enum Personality { SAD, ANGRY, HAPPY, LOVE }
var current_personality: int = Personality.SAD

@export_category("Pulse Settings")
@export var max_pulse_radius: float = 1500.0
@export var min_pulse_radius: float = 0.0

@export_group("Durations (Seconds)")
@export var open_duration: float = 1.0   # Time it takes to fully grow
@export var close_duration: float = 0.2  # Time it takes to shrink (Low number = fast snap)

# Dictionary to track the size of every personality circle
var radii: Dictionary = {
	Personality.SAD: 0.0,
	Personality.ANGRY: 0.0,
	Personality.HAPPY: 0.0,
	Personality.LOVE: 0.0
}

var _tween: Tween

func _ready() -> void:
	_update_all_shader_params()

func ChangePersonality(new_personality: int) -> void:
	current_personality = new_personality
	
	RenderingServer.global_shader_parameter_set("current_personality", current_personality)
	
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_parallel(true)
	
	for p in Personality.values():
		# --- OPPOSITE LOGIC START ---
		# DEFAULT: Everything wants to be OPEN (Big)
		var target_radius = max_pulse_radius
		var duration = open_duration
		
		# EXCEPTION: If it is the CURRENT personality, it should CLOSE (Small)
		if p == current_personality:
			target_radius = min_pulse_radius
			duration = close_duration
		# --- OPPOSITE LOGIC END ---
			
		# This tween now creates a "Negative Space" effect
		# (The world is colorful, except for the circle around you)
		_tween.tween_method(
			_update_single_radius.bind(p), 
			radii[p],                      
			target_radius,                 
			duration                        
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC) 

func _update_single_radius(value: float, p: int) -> void:
	radii[p] = value
	
	var param_name = ""
	match p:
		Personality.SAD: param_name = "sad_vision_radius"
		Personality.ANGRY: param_name = "angry_vision_radius"
		Personality.HAPPY: param_name = "happy_vision_radius"
		Personality.LOVE: param_name = "love_vision_radius"
	
	RenderingServer.global_shader_parameter_set(param_name, value)

func _update_all_shader_params() -> void:
	RenderingServer.global_shader_parameter_set("sad_vision_radius", radii[Personality.SAD])
	RenderingServer.global_shader_parameter_set("angry_vision_radius", radii[Personality.ANGRY])
	RenderingServer.global_shader_parameter_set("happy_vision_radius", radii[Personality.HAPPY])
	RenderingServer.global_shader_parameter_set("love_vision_radius", radii[Personality.LOVE])
	RenderingServer.global_shader_parameter_set("current_personality", current_personality)
