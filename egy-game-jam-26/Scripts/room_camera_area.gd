extends Area2D

@export var area_pcam: PhantomCamera2D
@export var main_camera: bool = false

@export_group("Icy Tower Settings")
@export var initial_speed: float = 50.0   # Starting scroll speed
@export var acceleration: float = 10.0    # Speed increase per second
@export var start_delay: float = 2.0      # Wait time before starting

@export_subgroup("Return Animation")
@export var return_duration: float = 2.0  # Time to slide back to start (in seconds)
@export var return_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var return_trans: Tween.TransitionType = Tween.TRANS_SINE

@export_subgroup("Player Push")
@export var push_threshold: float = 200.0 # How high player can go before pushing cam
@export var push_speed: float = 10.0      # How fast camera catches up (Lerp speed)

var current_speed: float = 0.0
var is_moving: bool = false
var start_pos: Vector2
var player_ref: Node2D = null

func _ready() -> void:
	connect("area_entered", _entered_area)
	connect("area_exited", _exited_area)
	start_pos = global_position
	
	if main_camera:
		start_sequence()

func _process(delta: float) -> void:
	if not is_moving: return
	
	# 1. CONSTANT SCROLL UP
	position.y -= current_speed * delta
	current_speed += acceleration * delta
	
	# 2. PLAYER PUSH LOGIC (Smooth Catch-up)
	if player_ref != null:
		# "Ideal" camera Y is player Y + threshold (keeping player below the top line)
		var ideal_cam_y = player_ref.global_position.y + push_threshold
		
		# If the ideal position is HIGHER (smaller Y) than current camera...
		if ideal_cam_y < position.y:
			# Smoothly lerp towards it so it feels fluid, not jerky
			position.y = lerp(position.y, ideal_cam_y, push_speed * delta)

# --- GAME LOGIC ---

func start_sequence() -> void:
	# Reset speed
	current_speed = initial_speed
	
	# Wait for player to get ready
	await get_tree().create_timer(start_delay).timeout
	
	# Only start if we are still in "Main Camera" mode
	if main_camera:
		is_moving = true

func return_to_start() -> void:
	is_moving = false
	
	# Create the smooth return tween
	var tween = create_tween()
	tween.set_trans(return_trans).set_ease(return_ease)
	
	# Tween position back to start_pos over 'return_duration' seconds
	tween.tween_property(self, "global_position", start_pos, return_duration)
	
	# Once the tween finishes, restart the game loop automatically
	tween.tween_callback(start_sequence)

# --- AREA LOGIC ---

func _entered_area(area_2d: Area2D) -> void:
	if area_2d.is_in_group("Player"):
		area_pcam.set_priority(100)
		player_ref = area_2d

func _exited_area(area_2d: Area2D) -> void:
	if area_2d.is_in_group("Player"):
		area_pcam.set_priority(0)
		player_ref = null
		
		# If game was active -> Player Died!
		if main_camera and is_moving:
			is_moving = false # Stop scrolling immediately
			
			if area_2d.has_method("die"):
				area_2d.die()
			
			# Wait 1s to see the death effect
			#await get_tree().create_timer(1.0).timeout
			
			# Trigger the smooth return
			return_to_start()
