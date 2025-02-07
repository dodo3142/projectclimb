extends CharacterBody3D

#region Exported Variables
@export_group("Movement")
@export var WalkSpeed: float = 10
@export var Accel: float = 10          # Acceleration when changing direction
@export var Decla: float = 5            # Deceleration when stopping

@export_group("Jump")
@export var JumpForce: float = 30       # Initial jump impulse
@export var JumpGravity: float = 120     # Gravity during ascent
@export var JumpApexMax: float = -5      # Maximum downward speed at jump apex
@export var JumpApexGravity: float = 50  # Gravity at jump apex
@export var FallGravity: float = 100     # Gravity during fall
@export var MaxFallSpeed: float = -70    # Terminal velocity
@export_range(0, 1) var JumpStopMult: float = 0.75  # Jump cut multiplier

@export_group("Others")
@export var RotationSpeed: float = 10     # Character rotation speed
@export var JumpBufferTime: float = 0.1  # Time window for jump input buffering
@export var JumpCoyoteTime: float = 0.1   # Time window for coyote time
@export var max_lean_angle := 20.0    # Maximum tilt angle in degrees
@export var lean_speed := 5.0         # How fast to tilt/recover
#endregion

#region Internal Variables
var Speed: float                        # Current movement speed
var InputDir: Vector3                    # Raw input direction
var LastInputDir: Vector3               # Last valid input direction
var AppliedVelocity: Vector3             # Final calculated velocity
var MovementVelocity: Vector3            # Horizontal movement velocity
var rotation_direction: float            # Target rotation angle

# State flags
var CanChangeInput: bool = true
var CanJump: bool = false
var TryingToJump: bool = false
var CanRotate: bool = true
var previously_floored: bool = false
#endregion

#region Node References
@onready var CameraJoint:Node3D = $CameraJoint
@onready var StateManager:StateChart = $StateManger
@onready var PlayerModel: MeshInstance3D = $ModlePovit/PlayerModle
@onready var ModelPivot: Node3D = $ModlePovit
@onready var JumpCoyoteTimer:Timer = $Timers/JumpCoyote
@onready var JumpBufferTimer:Timer = $Timers/JumpBuffer
#endregion

func _ready() -> void:
	Speed = WalkSpeed
	SimpleGrass.set_interactive(true)
	setup_timers()

func _process(delta: float) -> void:
	handle_input(delta)
	handle_state_events()
	handle_effects(delta)
	update_rotation(delta)
	process_jump_input()

func _physics_process(delta: float) -> void:
	SimpleGrass.set_player_position(global_position)
	velocity = AppliedVelocity
	move_and_slide()

#region Core Functions
func setup_timers() -> void:
	"""Configure jump timing-related timers"""
	JumpBufferTimer.wait_time = JumpBufferTime
	JumpCoyoteTimer.wait_time = JumpCoyoteTime

func handle_input(delta: float) -> void:
	"""Process player input and calculate movement direction"""
	InputDir.x = Input.get_axis("MoveLeft", "MoveRight")
	InputDir.z = Input.get_axis("MoveForward", "MoveBackward")
	InputDir = InputDir.rotated(Vector3.UP, CameraJoint.rotation.y).normalized()
	
	if CanChangeInput and InputDir != Vector3.ZERO:
		LastInputDir = InputDir
	
	MovementVelocity = InputDir * Speed

func update_movement(delta: float) -> void:
	"""Apply acceleration/deceleration to horizontal movement"""
	var y_velocity = velocity.y
	if MovementVelocity.length() >= AppliedVelocity.length():
		AppliedVelocity = velocity.move_toward(MovementVelocity, Accel * delta)
	else:
		AppliedVelocity = velocity.move_toward(MovementVelocity, Decla * delta)
	AppliedVelocity.y = y_velocity

func process_jump_input() -> void:
	"""Handle jump input with buffer and coyote time"""
	if is_on_floor() and velocity.y == 0:
		CanJump = true
	elif JumpCoyoteTimer.time_left > 0:
		JumpCoyoteTimer.start()
	
	if Input.is_action_just_pressed("Jump"):
		TryingToJump = true
		JumpBufferTimer.start()
	
	if CanJump and TryingToJump:
		StateManager.send_event("StartJumping")
#endregion

#region Visual Effects
func handle_effects(delta: float) -> void:
	"""Manage visual effects and model scaling"""
	# Movement particles
	$MovingParticles.emitting = is_on_floor() and velocity != Vector3.ZERO
	
	# Model scale interpolation
	PlayerModel.scale = PlayerModel.scale.lerp(Vector3.ONE, delta * 10)
	
	var local_vel = global_transform.basis.inverse() * velocity
	local_vel.y = 0
	
	var target_lean = Vector3.ZERO
	if local_vel.length() > 0.1:
		local_vel = local_vel.normalized()
		target_lean.x = -local_vel.z * max_lean_angle  # Forward/backward tilt
		target_lean.z = -local_vel.x * max_lean_angle  # Left/right tilt
	
	if is_on_floor():
		ModelPivot.rotation_degrees.x = lerp(ModelPivot.rotation_degrees.x, -target_lean.x, lean_speed * delta)
		ModelPivot.rotation_degrees.z = lerp(ModelPivot.rotation_degrees.z, target_lean.z, lean_speed * delta)
	else:
		ModelPivot.rotation_degrees = lerp(ModelPivot.rotation_degrees, Vector3.ZERO, lean_speed * delta)
	
	# Landing squash effect
	if is_on_floor() and AppliedVelocity.y < 2 and !previously_floored:
		PlayerModel.scale = Vector3(1.25, 0.75, 1.25)
	
	previously_floored = is_on_floor()

func update_rotation(delta: float) -> void:
	"""Handle character rotation towards movement direction"""
	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(-LastInputDir.z, -LastInputDir.x).angle()
	
	if CanRotate:
		PlayerModel.rotation.y = lerp_angle(
			PlayerModel.rotation.y, 
			rotation_direction, 
			delta * RotationSpeed
		)
#endregion

#region State Management
func handle_state_events() -> void:
	"""Update state machine based on current conditions"""
	if is_on_floor() and AppliedVelocity.y <= 0:
		StateManager.send_event("IsGrounded")
	else:
		if AppliedVelocity.y <= 0:
			StateManager.send_event("StartFalling")
	
	if InputDir == Vector3.ZERO:
		StateManager.send_event("StopMoving")
	else:
		StateManager.send_event("StartMoving")
#endregion

#region State Handlers
func _on_idle_state_state_physics_processing(delta: float) -> void:
	Speed = WalkSpeed
	update_movement(delta)
	if velocity.y > 0:
		StateManager.send_event("StartFalling")

func _on_walking_state_physics_processing(delta: float) -> void:
	update_movement(delta)
	if velocity.y > 0:
		StateManager.send_event("StartFalling")

func _on_jump_state_state_entered() -> void:
	"""Jump initialization with optional jump cut"""
	AppliedVelocity.y = JumpForce
	TryingToJump = false
	CanJump = false
	PlayerModel.scale = Vector3(0.5, 1.5, 0.5)
	
	if !Input.is_action_pressed("Jump"):
		AppliedVelocity.y *= JumpStopMult

func _on_jump_state_state_physics_processing(delta: float) -> void:
	update_movement(delta)
	AppliedVelocity.y -= JumpGravity * delta
	
	if Input.is_action_just_released("Jump"):
		AppliedVelocity.y *= JumpStopMult

func _on_falling_state_state_physics_processing(delta: float) -> void:
	"""Handle variable gravity during different fall phases"""
	update_movement(delta)
	
	if AppliedVelocity.y > JumpApexMax:
		AppliedVelocity.y -= JumpApexGravity * delta
	elif AppliedVelocity.y <= JumpApexMax and AppliedVelocity.y > MaxFallSpeed:
		AppliedVelocity.y -= FallGravity * delta
	elif AppliedVelocity.y < MaxFallSpeed:
		AppliedVelocity.y = MaxFallSpeed
#endregion

#region Timer Signals
func _on_jump_buffer_timeout():
	TryingToJump = false

func _on_jump_coyote_timeout():
	CanJump = false
#endregion
