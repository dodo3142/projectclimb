extends Node
class_name ButtonEffect

@export var ease_type : Tween.EaseType
@export var trans_type : Tween.TransitionType
@export var anim_duration : float = 0.07
@export var scale_amount : Vector2 = Vector2(1.1,1.1)
@export var rotation_amount : float = 3.0

@onready var button : Button = get_parent()

var tween : Tween

func _ready() -> void:
	# Connect signals
	button.mouse_entered.connect(_on_mouse_hoverd.bind(true))
	button.mouse_exited.connect(_on_mouse_hoverd.bind(false))
	button.pressed.connect(_on_button_presed)
	
	button.pivot_offset_ratio = Vector2(0.5,0.5)


func _on_button_presed() -> void:
	reset_tween()
	tween.tween_property(button, "scale", scale_amount, anim_duration).from(Vector2(0.8, 0.8))
	tween.tween_property(button, "rotation_degrees", rotation_amount * [1, -1].pick_random(), anim_duration).from(0)

func _on_mouse_hoverd(hovered: bool) -> void:
	reset_tween()
	
	# Standard Button Animation
	tween.tween_property(button, "scale", scale_amount if hovered else Vector2.ONE, anim_duration)
	tween.tween_property(button, "rotation_degrees", rotation_amount * [-1, 1].pick_random() if hovered else 0.0, anim_duration)
	
	# --- NEW PERSONALITY LOGIC ---
	if hovered:
		# 1. Update the shader first so the effect happens at the button location
		update_shader()
		
		# 2. Get all possible personalities from the GameManger Enum
		var all_personalities = GameManger.Personality.values()
		
		# 3. (Optional) Filter out the CURRENT personality
		all_personalities.erase(GameManger.current_personality)
		
		# 4. Pick a random one
		var random_p = all_personalities.pick_random()
		
		# 5. Tell GameManger to switch
		GameManger.ChangePersonality(random_p)

func reset_tween():
	if tween:
		tween.kill()
	tween = create_tween().set_ease(ease_type).set_trans(trans_type).set_parallel(true)

# --- NEW FUNCTION ADDED HERE ---
func update_shader() -> void:
	# Since this script extends Node, we use 'button' to get positions.
	# We also add button.size/2 so the effect spawns in the CENTER of the button, not top-left.
	var center_pos = button.global_position + (button.size / 2)
	RenderingServer.global_shader_parameter_set("player_pos", center_pos)
	
	# 1. Get the pixel position in the viewport (Canvas coordinates)
	var screen_pos = button.get_global_transform_with_canvas().origin + (button.size / 2)
	
	# 2. Get the viewport size (logical resolution)
	var viewport_size = button.get_viewport_rect().size
	
	# 3. Normalize the position (Result is between 0.0 and 1.0)
	var normalized_pos = screen_pos / viewport_size
	
	RenderingServer.global_shader_parameter_set("player_screen_pos", normalized_pos)
	
	var cam = button.get_viewport().get_camera_2d()
	var current_zoom = cam.zoom.x if cam else 1.0
	# Note: Assuming your shader uses "camera_zoom" as a float
	RenderingServer.global_shader_parameter_set("camera_zoom", current_zoom)
