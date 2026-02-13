extends Area2D

@export var area_pcam: PhantomCamera2D
@export var main_camera: bool = false
@export var end_marker: Marker2D ## Drag your Marker2D here!

@export_group("Icy Tower Settings")
@export var initial_speed: float = 50.0   
@export var acceleration: float = 10.0    
@export var start_delay: float = 2.0      

@export_subgroup("Return Animation")
@export var return_duration: float = 2.0  
@export var return_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var return_trans: Tween.TransitionType = Tween.TRANS_SINE

@export_subgroup("Player Push")
@export var push_threshold: float = 200.0 
@export var push_speed: float = 10.0      

var current_speed: float = 0.0
var is_moving: bool = false
var start_pos: Vector2
var player_ref: Node2D = null

# Signal to tell the game we finished the level
signal level_reached_top

func _ready() -> void:
	connect("area_entered", _entered_area)
	connect("area_exited", _exited_area)
	start_pos = global_position
	if main_camera:
		GameManger.main_cam = self

func _process(delta: float) -> void:
	# Note: We removed "if not is_moving: return" from the very top
	# so we can clamp the position even if the auto-scroll stopped.
	
	if not main_camera: return
	
	if is_moving:
		# 1. CONSTANT SCROLL UP
		position.y -= current_speed * delta
		current_speed += acceleration * delta
	
	# 2. PLAYER PUSH LOGIC (Smooth Catch-up)
	if player_ref != null:
		var ideal_cam_y = player_ref.global_position.y + push_threshold
		
		# Only push up if we haven't reached the top yet
		if ideal_cam_y < position.y:
			position.y = lerp(position.y, ideal_cam_y, push_speed * delta)

	# 3. STOP AT MARKER (The New Logic)
	if end_marker:
		# In Godot 2D, "Up" means a smaller Y value.
		# So if our Y is LESS than the marker Y, we have gone past it.
		if position.y <= end_marker.global_position.y:
			position.y = end_marker.global_position.y # Snap exactly to marker
			if is_moving:
				is_moving = false # Stop scrolling
				emit_signal("level_reached_top") # Let the game know we won!

# --- GAME LOGIC ---

func start_sequence() -> void:
	if not main_camera: return
	
	# Reset speed
	current_speed = initial_speed
	
	# Wait for player to get ready
	await get_tree().create_timer(start_delay).timeout
	
	# Only start if we are still in "Main Camera" mode
	if main_camera:
		is_moving = true

func return_to_start() -> void:
	if not main_camera: return
	is_moving = false
	
	var tween = create_tween()
	tween.set_trans(return_trans).set_ease(return_ease)
	tween.tween_property(self, "global_position", start_pos, return_duration)
	tween.tween_callback(start_sequence)

# --- AREA LOGIC ---

func _entered_area(area_2d: Area2D) -> void:
	if area_2d.is_in_group("CameraPlayer"):
		area_pcam.set_priority(100)
		player_ref = area_2d
		if main_camera:
			start_sequence()

func _exited_area(area_2d: Area2D) -> void:
	if area_2d.is_in_group("CameraPlayer"):
		area_pcam.set_priority(0)
		player_ref = null
		
		# If we were moving and player exited -> They fell/died
		if main_camera and is_moving:
			is_moving = false
			
			if area_2d.has_method("die"):
				area_2d.die()
			
			return_to_start()
