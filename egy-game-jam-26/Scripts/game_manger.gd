extends Node

enum Personality { SAD, ANGRY, HAPPY, LOVE }
var current_personality: int = Personality.SAD

@export_category("Pulse Settings")
@export var max_pulse_radius: float = 1500.0
@export var min_pulse_radius: float = 0.0

@export_group("Speeds")
@export var open_speed: float = 1500.0  # How fast it grows
@export var close_speed: float = 4000.0 # How fast it shrinks (Make this huge for snap)

# Dictionary to track the size of every personality circle independently
var radii: Dictionary = {
	Personality.SAD: 0.0,
	Personality.ANGRY: 0.0,
	Personality.HAPPY: 0.0,
	Personality.LOVE: 0.0
}

func _process(delta: float) -> void:
	# Loop through every personality (SAD, ANGRY, etc.)
	for p in Personality.values():
		var target = min_pulse_radius
		var current_speed = close_speed 
		
		# If this is the Active Personality, we want to grow
		if p == current_personality:
			target = max_pulse_radius
			current_speed = open_speed
		
		# Move the radius towards the target using the correct speed
		radii[p] = move_toward(radii[p], target, current_speed * delta)
	
	# Send the calculated sizes to the Shaders
	RenderingServer.global_shader_parameter_set("sad_vision_radius", radii[Personality.SAD])
	RenderingServer.global_shader_parameter_set("angry_vision_radius", radii[Personality.ANGRY])
	RenderingServer.global_shader_parameter_set("happy_vision_radius", radii[Personality.HAPPY])
	RenderingServer.global_shader_parameter_set("love_vision_radius", radii[Personality.LOVE])
	RenderingServer.global_shader_parameter_set("current_personality", current_personality)

func ChangePersonality(new_personality: int) -> void:
	current_personality = new_personality
