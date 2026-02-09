extends CharacterBody2D

# --- CONFIGURATION ---

@export_category("Movement")
@export var speed: float = 300.0
@export var acceleration: float = 1800.0
@export var friction: float = 2000.0

@export_category("Jump Physics")
@export var jump_height: float = 120.0        # Max height in pixels
@export var jump_time_to_peak: float = 0.4    # Time to reach max height
@export var jump_time_to_descent: float = 0.3 # Time to fall back down (faster = snappy)

@export_category("Jump Feel")
@export var coyote_time: float = 0.15         # Time allowed to jump after leaving ledge
@export var jump_buffer_time: float = 0.1     # Time input is saved before hitting ground
@export var variable_jump_cut: float = 0.5    # Multiplier when releasing jump button early
@export var hang_time_threshold: float = 50.0 # Velocity range to trigger "Apex" gravity
@export var hang_time_gravity_mult: float = 0.5 # Gravity multiplier at the apex

@export_category("Dash")
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0


# --- INTERNAL VARIABLES ---

# Calculated Gravity Variables
var jump_gravity: float
var fall_gravity: float

# Timers (floats are often more precise for physics frames than Timer nodes)
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0

# State Machine
enum State { IDLE, RUN, JUMP, FALL, DASH }
var current_state: int = State.FALL
var can_dash: bool = true

enum Personality {SAD,ANGRY,HAPPY,LOVE}
var current_personality : int = Personality.SAD
var tween: Tween

@onready var player_visual: Node2D = $PlayerVisual
@onready var face: AnimatedSprite2D = $PlayerVisual/Face


func _ready() -> void:
	GameManger.ChangePersonality(current_personality)
	# Calculate gravity and jump velocity based on the configuration numbers
	# Formula: h = 1/2 * g * t^2  =>  g = 2h / t^2
	jump_gravity = (2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
	fall_gravity = (2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)

func _physics_process(delta: float) -> void:
	update_shader()
	ChangePersonality()
	# 1. Update Timers
	if not is_on_floor():
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time
		can_dash = true # Reset dash on floor
		
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# 2. State Machine Logic
	match current_state:
		State.IDLE:
			handle_movement(delta)
			apply_gravity(delta)
			check_jump_start()
			check_dash_start()
			check_fall_transition()
			if velocity.x != 0: change_state(State.RUN)

		State.RUN:
			handle_movement(delta)
			apply_gravity(delta)
			check_jump_start()
			check_dash_start()
			check_fall_transition()
			if velocity.x == 0: change_state(State.IDLE)

		State.JUMP:
			handle_movement(delta)
			apply_gravity(delta)
			check_dash_start()
			handle_variable_jump_height()
			
			if velocity.y > 0: change_state(State.FALL)
			elif is_on_floor(): change_state(State.IDLE)

		State.FALL:
			handle_movement(delta)
			apply_gravity(delta)
			check_jump_start() # Allows coyote jump
			check_dash_start()
			
			if is_on_floor(): change_state(State.IDLE)

		State.DASH:
			dash_timer -= delta
			if dash_timer <= 0:
				#velocity.x = 0 # Optional: Stop momentum after dash
				change_state(State.FALL)

	move_and_slide()

# --- LOGIC HELPERS ---

func change_state(new_state: int) -> void:
	current_state = new_state
	# Optional: Add animation handling here
	# match new_state:
	#    State.JUMP: $AnimationPlayer.play("jump")

func handle_movement(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		# Apply acceleration
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		if direction > 0:
			player_visual.scale.x = abs(player_visual.scale.x)
		else:
			player_visual.scale.x = -abs(player_visual.scale.x)
	else:
		# Apply friction
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func apply_gravity(delta: float) -> void:
	var applied_gravity = 0.0
	
	# Determine which gravity to use
	if abs(velocity.y) < hang_time_threshold:
		# Jump Apex (Hang time) - Lower gravity for floaty feel at top
		applied_gravity = jump_gravity * hang_time_gravity_mult
	elif velocity.y < 0:
		# Jumping up
		applied_gravity = jump_gravity
	else:
		# Falling down
		applied_gravity = fall_gravity
	
	velocity.y += applied_gravity * delta

func check_jump_start() -> void:
	# To jump, we need a valid Buffer AND (be on floor OR have Coyote time)
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0):
		perform_jump()

func perform_jump() -> void:
	# Calculate initial jump velocity: v = sqrt(2 * g * h)
	# Negative because Y-up is negative in Godot
	velocity.y = -sqrt(2.0 * jump_gravity * jump_height)
	
	jump_buffer_timer = 0 # Consume buffer
	coyote_timer = 0      # Consume coyote
	change_state(State.JUMP)

func handle_variable_jump_height() -> void:
	# If player releases button while moving up, cut velocity
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= variable_jump_cut

func check_dash_start() -> void:
	if Input.is_action_just_pressed("dash") and can_dash and dash_cooldown_timer <= 0:
		start_dash()

func start_dash() -> void:
	# Determine dash direction (default to facing direction or input)
	var dash_dir = Input.get_axis("move_left", "move_right")
	if dash_dir == 0:
		# If no input, dash in the direction we are currently moving or facing
		dash_dir = 1 if velocity.x >= 0 else -1
		
	velocity.y = 0 # Remove vertical velocity for a straight dash
	velocity.x = dash_dir * dash_speed
	
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	can_dash = false # Consume dash
	change_state(State.DASH)

func check_fall_transition() -> void:
	# If we walk off a ledge, we aren't jumping, we are falling
	if not is_on_floor() and velocity.y > 0:
		change_state(State.FALL)


func ChangePersonality():
	if Input.is_action_just_pressed("Change"):
		Engine.time_scale = 0.2
		$CanvasLayer/SelectionWheel.show()
	elif Input.is_action_just_released("Change"):
		Engine.time_scale = 1
		if $CanvasLayer/SelectionWheel.close() != -1:
			current_personality= $CanvasLayer/SelectionWheel.close() 
		GameManger.ChangePersonality(current_personality)
		face.frame = current_personality


func update_shader():
	RenderingServer.global_shader_parameter_set("player_pos", global_position)
	var screen_pos = get_global_transform_with_canvas().origin
	RenderingServer.global_shader_parameter_set("player_screen_pos", screen_pos)
	var current_zoom = 1.0
	var cam = get_viewport().get_camera_2d()
	if cam:
		current_zoom = cam.zoom.x
		
	RenderingServer.global_shader_parameter_set("camera_zoom", current_zoom)
