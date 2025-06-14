extends CharacterBody3D

#region Exported Variables
@export_group("Movement")
@export var walk_speed: float = 10
@export var acceleration: float = 10  # Acceleration when changing direction
@export var deceleration: float = 5   # Deceleration when stopping

@export_group("Jump")
@export var jump_force: float = 30       # Initial jump impulse
@export var jump_gravity: float = 120    # Gravity during ascent
@export var jump_apex_max_speed: float = -5  # Maximum downward speed at jump apex
@export var jump_apex_gravity: float = 50    # Gravity at jump apex
@export var fall_gravity: float = 100        # Gravity during fall
@export var max_fall_speed: float = -70       # Terminal velocity
@export_range(0, 1) var jump_cut_multiplier: float = 0.75  # Jump cut multiplier

@export_group("GroundSmash")
@export var ground_smash_gravity: float = 200
@export var ground_smash_max_speed: float = -100
@export var ground_smash_jump_force: float = 50
@export var ground_smash_jump_gravity_unused: float = 120
@export var ground_smash_time: float = 0.2

@export_group("WallJump")
@export var walljump_force_up: float = 30
@export var walljump_force_xz: float = 20

@export_group("Dashing")
@export var dash_speed: float = 1500
@export var dash_duration: float = 2
@export var dash_cooldown: float = 0.5

@export_group("Swinging")
@export var swing_speed: float = 2.0  # Speed of swinging
@export var swing_radius: float = 3.0 # Distance from the swing anchor

@export_group("Others")
@export var rotation_speed: float = 10     # Character rotation speed
@export var jump_buffer_time: float = 0.1  # Time window for jump input buffering
@export var jump_coyote_time: float = 0.1  # Time window for coyote time
@export var wall_jump_ray_lenght: float = 0.5
@export var max_lean_angle: float = 20.0   # Maximum tilt angle in degrees
@export var lean_speed: float = 5.0        # How fast to tilt/recover
#endregion

#region Internal Variables
@onready var current_speed: float = walk_speed  # Current movement speed
var input_direction: Vector3                    # Raw input direction
var last_input_direction: Vector3 = Vector3.FORWARD              # Last valid input direction
var target_velocity: Vector3                    # Horizontal movement velocity
var rotation_direction: float                   # Target rotation angle
var current_jump_force: float
var bouncedir: Vector3
var swing_angle: float = 0.0

# State flags
var can_change_input: bool = true
var can_move: bool = true
var can_jump: bool = false
var trying_to_jump: bool = false
var manual_jump: bool = false
var can_rotate: bool = true
var previously_floored: bool = false
var is_jumping: bool = false
var is_falling: bool = false
var is_groundsmashing: bool = false
var is_swinging: bool = false
var is_dashing: bool = false
var can_dash:bool = true

#endregion

#region Node References
@onready var camera_joint: Node3D = $CameraJoint
@onready var current_camera: PhantomCamera3D = $CameraJoint/SpringArm3D/PhantomCamera3D
@onready var state_manager: StateChart = $StateManger
@onready var player_model: MeshInstance3D = $ModlePovit/PlayerModle
@onready var model_pivot: Node3D = $ModlePovit
@onready var jump_coyote_timer: Timer = $Timers/JumpCoyote
@onready var jump_buffer_timer: Timer = $Timers/JumpBuffer
@onready var ground_smashing_timer: Timer = $Timers/GroundSmashing
@onready var dash_timer: Timer = $Timers/Dashing
@onready var dash_cooldown_timer: Timer = $Timers/DashCooldown
@onready var speed_number: Label = $Debug/DebugText/VBoxContainer/HBoxContainer/SpeedNumber
@onready var velocity_number: Label = $Debug/DebugText/VBoxContainer/HBoxContainer2/VelocityNumber
@onready var wall_jump_ray_cast: RayCast3D = $Raycasts/WallJumpRayCast
#endregion

func _ready() -> void:
	SimpleGrass.set_interactive(true)
	setup_timers()

func _process(delta: float) -> void:
	handle_visual_effects(delta)
	update_rotation(delta)
	debug()

func _physics_process(delta: float) -> void:
	SimpleGrass.set_player_position(global_position)
	handle_input(delta)
	handle_state_events()
	process_jump_input()
	move_and_slide()


#region Core Functions
func debug() -> void:
	DebugDraw3D.draw_arrow(position,position + (velocity * 0.2),Color(0.0, 0.831, 0.841),0.1)
	DebugDraw3D.draw_arrow(position,position + (input_direction.normalized() * 3),Color(0.0, 0.0, 0.0),0.1)
	speed_number.text = str(Vector2(velocity.x,velocity.z).length_squared()).pad_decimals(2)
	velocity_number.text = str(velocity)

func setup_timers() -> void:
	"""Configure jump timing-related timers."""
	jump_buffer_timer.wait_time = jump_buffer_time
	jump_coyote_timer.wait_time = jump_coyote_time
	ground_smashing_timer.wait_time = ground_smash_time
	dash_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown

func handle_input(delta: float) -> void:
	"""Process player input and calculate movement direction."""
	var forward = current_camera.global_basis.z
	var right = current_camera.global_basis.x
	input_direction.x = Input.get_axis("MoveLeft", "MoveRight")
	input_direction.z = Input.get_axis("MoveForward", "MoveBackward")
	input_direction = input_direction.rotated(Vector3.UP, camera_joint.rotation.y).normalized()
	if can_change_input and input_direction != Vector3.ZERO:
		last_input_direction = input_direction

func handle_movement(delta: float) -> void:
	"""Apply acceleration/deceleration to horizontal movement."""
	target_velocity = input_direction * current_speed * delta
	target_velocity.y = velocity.y
	
	if target_velocity.length() >= velocity.length():
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(target_velocity,deceleration * delta)

func process_jump_input() -> void:
	"""Handle jump input with buffer and coyote time."""
	if is_on_floor() and velocity.y <= 0:
		can_jump = true
	elif jump_coyote_timer.time_left > 0:
		jump_coyote_timer.start()
	
	if Input.is_action_just_pressed("Jump"):
		trying_to_jump = true
		jump_buffer_timer.start()
	
	if can_jump and trying_to_jump:
		if is_groundsmashing:
			current_jump_force = ground_smash_jump_force
		else:
			manual_jump = true
			current_jump_force = jump_force
		state_manager.send_event("StartJumping")

func jump(jump_force: float) -> void:
	"""Apply jump force and handle jump cut."""
	velocity.y = jump_force
	trying_to_jump = false
	can_jump = false
	player_model.scale = Vector3(0.5, 1.5, 0.5)
	
	if !Input.is_action_pressed("Jump") and manual_jump:
		manual_jump = false
		velocity.y *= jump_cut_multiplier

func launch_player(jump_force: float) -> void:
	"""Launch the player with a specific jump force."""
	current_jump_force = jump_force
	state_manager.send_event("StartJumping")

#endregion

#region Visual Effects
func handle_visual_effects(delta: float) -> void:
	"""Manage visual effects and model scaling."""
	# Movement particles
	%MovingParticles.emitting = is_on_floor() and velocity != Vector3.ZERO
	
	# Model scale interpolation
	player_model.scale = player_model.scale.lerp(Vector3.ONE, delta * 10)
	
	var local_velocity = global_transform.basis.inverse() * velocity
	local_velocity.y = 0
	
	var target_lean = Vector3.ZERO
	if local_velocity.length() > 0.1:
		local_velocity = local_velocity.normalized()
		target_lean.x = -local_velocity.z * max_lean_angle  # Forward/backward tilt
		target_lean.z = -local_velocity.x * max_lean_angle  # Left/right tilt
	
	if is_on_floor():
		model_pivot.rotation_degrees.x = lerp(model_pivot.rotation_degrees.x, -target_lean.x, lean_speed * delta)
		model_pivot.rotation_degrees.z = lerp(model_pivot.rotation_degrees.z, target_lean.z, lean_speed * delta)
	else:
		model_pivot.rotation_degrees = lerp(model_pivot.rotation_degrees, Vector3.ZERO, lean_speed * delta)
	
	# Landing squash effect
	if is_on_floor() and velocity.y < 2 and !previously_floored:
		player_model.scale = Vector3(1.25, 0.75, 1.25)
	
	previously_floored = is_on_floor()

func update_rotation(delta: float) -> void:
	"""Handle character rotation towards movement direction."""
	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(-last_input_direction.z, -last_input_direction.x).angle()
	
	if can_rotate:
		player_model.rotation.y = lerp_angle(
			player_model.rotation.y, 
			rotation_direction, 
			delta * rotation_speed
		)
#endregion

#region State Management
func handle_state_events() -> void:
	"""Update state machine based on current conditions."""
	if is_on_floor():
		state_manager.send_event("IsGrounded")
	else:
		if velocity.y <= 0:
			state_manager.send_event("StartFalling")
	
	if input_direction == Vector3.ZERO:
		state_manager.send_event("StopMoving")
	else:
		state_manager.send_event("StartMoving")
	
	if Input.is_action_just_pressed("GroundSmash"):
		state_manager.send_event("IsGroundSmashing")
	
	if Input.is_action_just_pressed("Dash") and can_dash:
		state_manager.send_event("isDashing")
#endregion


#IDLESTATE
func _on_idle_state_state_entered() -> void:
	velocity.y = 0

func _on_idle_state_state_physics_processing(delta: float) -> void:
	handle_movement(delta)
	current_speed = walk_speed


#WALKINGSTATE
func _on_walking_state_state_entered() -> void:
	pass

func _on_walking_state_state_physics_processing(delta: float) -> void:
	handle_movement(delta)

#JUMPINGSTATE
func _on_jump_state_state_entered() -> void:
	"""Jump initialization with optional jump cut."""
	is_jumping = true
	jump(current_jump_force)

func _on_jump_state_state_physics_processing(delta: float) -> void:
	handle_movement(delta)
	velocity.y -= jump_gravity * delta
	if Input.is_action_just_released("Jump") and manual_jump:
		manual_jump = false
		velocity.y *= jump_cut_multiplier

func _on_jump_state_state_exited() -> void:
	manual_jump = false
	is_jumping = false

#FALLINGSTATE
func _on_falling_state_state_physics_processing(delta: float) -> void:
	"""Handle variable gravity during different fall phases."""
	handle_movement(delta)
	if velocity.y > jump_apex_max_speed:
		velocity.y -= jump_apex_gravity * delta
	elif velocity.y <= jump_apex_max_speed and velocity.y > max_fall_speed:
		velocity.y -= fall_gravity * delta
	elif velocity.y < max_fall_speed:
		velocity.y = max_fall_speed

#GROUNDSMASHING
func _on_ground_smashing_state_state_entered() -> void:
	is_groundsmashing = true
	velocity = Vector3.ZERO
	can_move = false

func _on_ground_smashing_state_state_physics_processing(delta: float) -> void:
	if velocity.y > jump_apex_max_speed:
		velocity.y -= jump_apex_gravity * delta
	elif velocity.y <= jump_apex_max_speed and velocity.y > ground_smash_max_speed:
		velocity.y -= ground_smash_gravity * delta
	elif velocity.y < ground_smash_max_speed and !is_on_floor():
		velocity.y = ground_smash_max_speed
	
	if is_on_floor():
		can_move = true

func _on_ground_smashing_state_state_exited() -> void:
	ground_smashing_timer.start()
	can_move = true

#DASHING
func _on_dashing_state_state_entered() -> void:
	is_dashing = true
	can_dash = false
	can_change_input = false
	wall_jump_ray_cast.target_position = last_input_direction.normalized() * wall_jump_ray_lenght
	dash_timer.start()
	dash_cooldown_timer.start()
	velocity = last_input_direction * dash_speed
	velocity.y = 0

func _on_dashing_state_state_physics_processing(delta: float) -> void:
	if wall_jump_ray_cast.is_colliding():
		var collision_normal = wall_jump_ray_cast.get_collision_normal()
		bouncedir =  (last_input_direction * dash_speed).normalized().bounce(collision_normal)
		state_manager.send_event("WallJump")

func _on_dashing_state_state_exited() -> void:
	is_dashing = false
	can_change_input = true

#WALLJUMPING
func _on_wall_jump_state_state_entered() -> void:
	velocity = bouncedir * walljump_force_xz
	velocity.y = walljump_force_up


func _on_wall_jump_state_state_physics_processing(delta: float) -> void:
	handle_movement(delta)
	velocity.y -= jump_gravity * delta

#region Timer Signals
func _on_jump_buffer_timeout():
	trying_to_jump = false

func _on_jump_coyote_timeout():
	can_jump = false

func _on_ground_smashing_timeout() -> void:
	is_groundsmashing = false

func _on_dashing_timeout() -> void:
	state_manager.send_event("DoneDashing")

func _on_dash_cooldown_timeout() -> void:
	can_dash = true
#endregion



#WIP
#func _on_swinging_state_state_physics_processing(delta: float) -> void:
	## Calculate the new position based on the swing angle
	#swing_angle += swing_speed * delta
	#var x = swing_radius * sin(swing_angle)
	#var y = -swing_radius * cos(swing_angle)
	#
	## Update the player's position relative to the swing anchor
	#global_position = swing_joint.global_position + Vector3(x, y, 0)
