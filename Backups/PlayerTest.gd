extends CharacterBody3D

# State machine
enum States { IDLE, MOVING, JUMPING, FALLING, FAST_FALLING }
var current_state: States = States.IDLE
var previous_state: States = States.IDLE
const STATE_NAMES = ["IDLE", "MOVING", "JUMPING", "FALLING", "FAST_FALLING"]

# Movement settings
@export var max_speed := 10.0
@export var acceleration := 15.0
@export var deceleration := 25.0
@export var air_control := 5.0
@export var jump_force := 4.5
@export var tall_jump_force := 6.0

# Gravity settings
@export var base_gravity := 9.8
@export var jump_gravity := 4.0
@export var fall_gravity := 12.0
@export var fast_fall_gravity := 25.0
@export var max_fall_speed := 20.0
@export var apex_gravity_threshold := 1.0
@export var apex_gravity_multiplier := 0.5

# Fast fall settings
@export var fast_fall_speed := 40.0
@export var tall_jump_window := 0.2
var tall_jump_timer := 0.0
var is_fast_falling := false

# Coyote time settings
@export var coyote_duration := 0.15
var coyote_timer := 0.0

# Jump buffer settings
@export var jump_buffer_duration := 0.2
var jump_buffer_timer := 0.0

# Camera reference
@export var camera : Node3D

var direction := Vector3.ZERO

func _ready():
	if not camera:
		camera = get_node("%Camera3D") # Change this to your camera path

func _physics_process(delta):
	handle_jump_timers(delta)
	handle_fast_fall()
	apply_gravity(delta)
	handle_jump()
	handle_movement(delta)
	move_and_slide()
	update_state()

func update_state():
	var new_state: States
	
	if is_on_floor():
		if is_fast_falling:
			is_fast_falling = false
			tall_jump_timer = tall_jump_window
		
		var horizontal_velocity = Vector2(velocity.x, velocity.z)
		if horizontal_velocity.length_squared() > 0.1:
			new_state = States.MOVING
		else:
			new_state = States.IDLE
	else:
		if is_fast_falling:
			new_state = States.FAST_FALLING
		elif velocity.y > 0:
			new_state = States.JUMPING
		else:
			new_state = States.FALLING
	
	if new_state != current_state:
		current_state = new_state
		print("Current State: ", STATE_NAMES[current_state])

func handle_jump_timers(delta):
	if is_on_floor():
		coyote_timer = coyote_duration
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)
	
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer = jump_buffer_duration
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	
	tall_jump_timer = max(tall_jump_timer - delta, 0.0)

func handle_fast_fall():
	if not is_on_floor() and Input.is_action_just_pressed("GroundSmash"):
		is_fast_falling = true
		velocity.y = -fast_fall_speed

func apply_gravity(delta):
	if not is_on_floor():
		var current_gravity = base_gravity
		
		if is_fast_falling:
			current_gravity = fast_fall_gravity
		elif current_state == States.JUMPING:
			if velocity.y < apex_gravity_threshold:
				current_gravity *= apex_gravity_multiplier
			else:
				current_gravity = jump_gravity
		elif current_state == States.FALLING:
			current_gravity = fall_gravity
		
		velocity.y -= current_gravity * delta
		
		if velocity.y < -max_fall_speed and not is_fast_falling:
			velocity.y = -max_fall_speed

func handle_jump():
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0):
		var jump_strength = tall_jump_force if tall_jump_timer > 0 else jump_force
		velocity.y = jump_strength
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		tall_jump_timer = 0.0

func handle_movement(delta):
	if is_fast_falling:
		# Stop horizontal movement during fast fall
		velocity.x = 0
		velocity.z = 0
		return
	
	var input_dir = Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward")
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if camera:
		direction = direction.rotated(Vector3.UP, camera.rotation.y).normalized()
	
	var target_velocity = direction * max_speed
	target_velocity.y = velocity.y
	
	var current_accel = acceleration if direction else deceleration
	if not is_on_floor():
		current_accel = air_control
	
	velocity = velocity.lerp(target_velocity, current_accel * delta)
