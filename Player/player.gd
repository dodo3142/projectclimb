extends CharacterBody3D

@export_group("Movement")
@export var WalkSpeed : float = 10
@export var Accel : float = 10
@export var Decla : float = 5

@export_group("Jump")
@export var JumpForce : float = 30
@export var JumpGravity : float = 120
@export var JumpApexMax : float = -5
@export var JumpApexGravity : float = 50
@export var FallGravity : float = 100
@export var MaxFallSpeed : float = -70
@export_range(0,1) var JumpStopMult : float = 0.75


@export_group("Others")
@export var RotationSpeed : float = 10
@export var JumpBufferTime : float = 0.1
@export var JumpCoyoteTime : float = 0.1

var Speed : float
var InputDir : Vector3
var LastInputDir : Vector3
var AppliedVelocity: Vector3
var MovementVelocity: Vector3
var rotation_direction: float

var CanChangeInput : bool = true
var CanJump : bool = false
var TryingToJump : bool = false
var CanRotate : bool = true
var previously_floored : bool = false

@onready var CameraJoint = $CameraJoint
@onready var StateManger = $StateManger
@onready var PlayerModle: MeshInstance3D = $PlayerModle

@onready var JumpCoyoteTimer = $Timers/JumpCoyote
@onready var JumpBufferTimer = $Timers/JumpBuffer

func _ready() -> void:
	Speed = WalkSpeed
	SimpleGrass.set_interactive(true)
	SetTimers()

func _process(delta: float) -> void:
	HandleInput(delta)
	HandleStateEvents()
	HandleEffects(delta)
	Rotations(delta)
	JumpingInput()

func _physics_process(delta: float) -> void:
	SimpleGrass.set_player_position(global_position)
	velocity = AppliedVelocity
	move_and_slide()

func HandleEffects(delta):
	if is_on_floor() and velocity != Vector3.ZERO:
		$MovingParticles.emitting = true
	else:
		$MovingParticles.emitting = false
	
	PlayerModle.scale = PlayerModle.scale.lerp(Vector3(1, 1, 1), delta * 10)
	
	if is_on_floor() and AppliedVelocity.y < 2 and !previously_floored:
		PlayerModle.scale = Vector3(1.25, 0.75, 1.25)
	
	previously_floored = is_on_floor()

func SetTimers():
	JumpBufferTimer.wait_time = JumpBufferTime
	JumpCoyoteTimer.wait_time = JumpCoyoteTime

func Rotations(delta):
	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(-LastInputDir.z, -LastInputDir.x).angle()
	
	if CanRotate:
		PlayerModle.rotation.y = lerp_angle(PlayerModle.rotation.y, rotation_direction, delta * RotationSpeed)

func HandleStateEvents():
	if is_on_floor() and AppliedVelocity.y <= 0:
		StateManger.send_event("IsGrounded")
	else:
		if AppliedVelocity.y <= 0:
			StateManger.send_event("StartFalling")
	
	if InputDir == Vector3.ZERO:
		StateManger.send_event("StopMoving")
	else:
		StateManger.send_event("StartMoving")

func HandleInput(delta):
	InputDir.x = Input.get_axis("MoveLeft","MoveRight")
	InputDir.z = Input.get_axis("MoveForward","MoveBackWard")
	
	InputDir = InputDir.rotated(Vector3.UP, CameraJoint.rotation.y).normalized()
	
	if CanChangeInput:
		if InputDir != Vector3.ZERO:
			LastInputDir = InputDir
	
	MovementVelocity = InputDir * Speed

func HandleMovement(delta):
	var yVelocity = velocity.y
	if MovementVelocity.length() >= AppliedVelocity.length():
		AppliedVelocity = velocity.move_toward(MovementVelocity, Accel * delta)
	elif MovementVelocity.length() < AppliedVelocity.length():
		AppliedVelocity = velocity.move_toward(MovementVelocity, Decla * delta)
	AppliedVelocity.y = yVelocity

func JumpingInput():
	if is_on_floor() and velocity.y == 0:
		CanJump = true
	else:
		if JumpCoyoteTimer.time_left > 0:
			JumpCoyoteTimer.start()
	
	if Input.is_action_just_pressed("Jump"):
		TryingToJump = true
		JumpBufferTimer.start()
	
	if(CanJump and TryingToJump):
		StateManger.send_event("StartJumping")

func _on_idle_state_state_physics_processing(delta: float) -> void:
	Speed = WalkSpeed
	HandleMovement(delta)
	if velocity.y > 0:
		StateManger.send_event("StartFalling")

func _on_walking_state_physics_processing(delta):
	HandleMovement(delta)
	if velocity.y > 0:
		StateManger.send_event("StartFalling")


func _on_jump_state_state_entered() -> void:
	AppliedVelocity.y = JumpForce
	TryingToJump = false
	CanJump = false
	PlayerModle.scale = Vector3(0.5, 1.5, 0.5)
	if !Input.is_action_pressed("Jump"):
		AppliedVelocity.y = AppliedVelocity.y * JumpStopMult

func _on_jump_state_state_physics_processing(delta: float) -> void:
	HandleMovement(delta)
	AppliedVelocity.y -= JumpGravity * delta
	
	if Input.is_action_just_released("Jump"):
		AppliedVelocity.y = AppliedVelocity.y * JumpStopMult

func _on_falling_state_state_physics_processing(delta: float) -> void:
	HandleMovement(delta)
	if AppliedVelocity.y > JumpApexMax:
		AppliedVelocity.y -= JumpApexGravity * delta
	elif AppliedVelocity.y <= JumpApexMax and AppliedVelocity.y > MaxFallSpeed:
		AppliedVelocity.y -= FallGravity * delta
	elif AppliedVelocity.y < MaxFallSpeed:
		AppliedVelocity.y = MaxFallSpeed

func _on_jump_buffer_timeout():
	TryingToJump = false

func _on_jump_coyote_timeout():
	CanJump = false
