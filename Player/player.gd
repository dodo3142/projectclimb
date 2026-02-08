extends CharacterBody3D

#region Exported Variables
@export_group("Movement")
@export var walk_speed: float = 8.0
@export var acceleration: float = 4.0
@export var deceleration: float = 6.0

@export_group("Jump")
@export var jump_force: float = 12.0
@export var jump_gravity: float = 40.0
@export var jump_apex_max_speed: float = -5.0
@export var jump_apex_gravity: float = 20.0
@export var fall_gravity: float = 80.0
@export var max_fall_speed: float = -50.0
@export_range(0, 1) var jump_cut_multiplier: float = 0.5
@export var double_jump_force: float = 25.0 # Usually slightly weaker than main jump
@export var max_jump_count: int = 2

@export_group("Wall Run")
@export var wall_run_speed: float = 10.0
@export var wall_run_gravity: float = 5.0 # Very low gravity to "stick"
@export var wall_jump_force_up: float = 12.0
@export var wall_jump_force_side: float = 10.0
@export var wall_run_angle: float = 15.0

@export_group("GroundSmash")
@export var ground_smash_gravity: float = 100.0
@export var ground_smash_max_speed: float = -100.0
@export var ground_smash_jump_force: float = 25.0 # High jump after smash
@export var ground_smash_time: float = 0.2

@export_group("Dashing")
@export var dash_speed: float = 25.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.8

@export_group("Visuals")
@export var rotation_speed: float = 10.0
@export var max_lean_angle: float = 20.0
@export var lean_speed: float = 5.0

@export_group("Timers")
@export var jump_buffer_time: float = 0.1
@export var jump_coyote_time: float = 0.1
#endregion

#region Node References
@onready var camera_joint: Node3D = $CameraJoint
@onready var current_camera: PhantomCamera3D = $CameraJoint/SpringArm3D/PhantomCamera3D
@onready var state_chart: StateChart = $StateManger
@onready var player_model: MeshInstance3D = $ModlePovit/PlayerModle
@onready var model_pivot: Node3D = $ModlePovit

# Raycasts (Required for Wall Run)
@onready var ray_left: RayCast3D = %WallRayLeft
@onready var ray_right: RayCast3D = %WallRayRight

# Debug UI
@onready var speed_number: Label = $Debug/DebugText/VBoxContainer/HBoxContainer/SpeedNumber
@onready var velocity_number: Label = $Debug/DebugText/VBoxContainer/HBoxContainer2/VelocityNumber

# Timers
@onready var jump_coyote_timer: Timer = $Timers/JumpCoyote
@onready var jump_buffer_timer: Timer = $Timers/JumpBuffer
@onready var dash_timer: Timer = $Timers/Dashing
@onready var dash_cooldown_timer: Timer = $Timers/DashCooldown
@onready var ground_smashing_timer: Timer = $Timers/GroundSmashing
# Create Super Jump timer in code so it doesn't clutter editor
@onready var super_jump_window: Timer = Timer.new() 
#endregion

#region Internal Variables
var input_direction: Vector3 = Vector3.ZERO
var last_input_direction: Vector3 = Vector3.FORWARD
var rotation_direction: float
var previously_floored: bool = false
var current_jump_count: int = 0


# Wall Run Variables
var Is_wallrunning : bool = false
var current_wall_side: int = 0 # 1 = Left, -1 = Right
var wall_normal: Vector3 = Vector3.ZERO
var wall_forward_direction: Vector3 = Vector3.ZERO
#endregion

func _ready() -> void:
	SimpleGrass.set_interactive(true)
	add_child(super_jump_window) # Add the manual timer to scene
	setup_timers()

func setup_timers() -> void:
	jump_buffer_timer.wait_time = jump_buffer_time
	jump_coyote_timer.wait_time = jump_coyote_time
	ground_smashing_timer.wait_time = ground_smash_time
	dash_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	super_jump_window.wait_time = 0.2
	super_jump_window.one_shot = true
	
	dash_timer.timeout.connect(func(): state_chart.send_event("DashFinished"))
	ground_smashing_timer.timeout.connect(func(): state_chart.send_event("SmashFinished"))
	jump_coyote_timer.timeout.connect(func(): if current_jump_count == 0: current_jump_count = 1)

# 1. INPUT HANDLING
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Jump"):
		jump_buffer_timer.start()
		if is_on_floor() or current_jump_count < max_jump_count:
			state_chart.send_event("JumpPressed")
		
	if event.is_action_released("Jump"):
		state_chart.send_event("JumpReleased")
		
	if event.is_action_pressed("Dash") and dash_cooldown_timer.is_stopped():
		state_chart.send_event("DashPressed")

	if event.is_action_pressed("GroundSmash") and not is_on_floor():
		state_chart.send_event("SmashPressed")

# 2. PHYSICS LOOP
func _physics_process(delta: float) -> void:
	SimpleGrass.set_player_position(global_position)
	update_input_direction()
	
	if not Is_wallrunning:
		$Raycasts.global_rotation.y = $CameraJoint.global_rotation.y
	
	# Coyote Time Logic
	if is_on_floor():
		jump_coyote_timer.stop()
		previously_floored = true
	elif previously_floored and velocity.y <= 0:
		jump_coyote_timer.start()
		previously_floored = false

	# --- STATE MACHINE LOGIC ---
	if is_on_floor():
		state_chart.send_event("Grounded")
	# Check for Wall Run (Airborne + Moving + Touching Wall)
	elif check_wall_run():
		state_chart.send_event("WallRunStarted")
	else:
		state_chart.send_event("Airborne")
		
	if input_direction.length_squared() > 0.01:
		state_chart.send_event("Moving")
	else:
		state_chart.send_event("Stopped")

	move_and_slide()

# 3. VISUALS
func _process(delta: float) -> void:
	handle_visual_effects(delta)
	debug()

#region Physics Helpers
func update_input_direction() -> void:
	var input_2d = Input.get_vector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward")
	var dir = Vector3(input_2d.x, 0, input_2d.y)
	if dir.length_squared() > 0.01:
		dir = dir.rotated(Vector3.UP, camera_joint.rotation.y).normalized()
		input_direction = dir
		last_input_direction = dir
	else:
		input_direction = Vector3.ZERO

func check_wall_run() -> bool:
	if ray_left.is_colliding():
		current_wall_side = 1
		wall_normal = ray_left.get_collision_normal()
		return true
	elif ray_right.is_colliding():
		current_wall_side = -1
		wall_normal = ray_right.get_collision_normal()
		return true
	return false

func apply_movement(delta: float, speed: float, accel: float, decel: float) -> void:
	var target_vel = input_direction * speed
	var temp_vel = velocity
	temp_vel.y = 0 
	
	if input_direction.length_squared() > 0.01:
		temp_vel = temp_vel.move_toward(target_vel, accel * delta)
	else:
		temp_vel = temp_vel.move_toward(Vector3.ZERO, decel * delta)
	
	velocity.x = temp_vel.x
	velocity.z = temp_vel.z

func apply_gravity(delta: float, gravity_amount: float) -> void:
	velocity.y -= gravity_amount * delta
#endregion

#region State Callbacks

# --- GROUNDED ---
func _on_grounded_state_physics_processing(delta: float) -> void:
	current_jump_count = 0 # Reset jumps
	
	if jump_buffer_timer.time_left > 0:
		state_chart.send_event("JumpPressed")

func _on_idle_state_physics_processing(delta: float) -> void:
	apply_movement(delta, 0, acceleration, deceleration)

func _on_walking_state_physics_processing(delta: float) -> void:
	apply_movement(delta, walk_speed, acceleration, deceleration)

# --- JUMPING ---
func _on_jump_state_entered() -> void:
	current_jump_count += 1
	
	if is_on_floor() or jump_coyote_timer.time_left > 0:
		# SUPER JUMP CHECK
		if not super_jump_window.is_stopped():
			velocity.y = ground_smash_jump_force # High Jump
		else:
			velocity.y = jump_force # Normal Jump
	else:
		velocity.y = double_jump_force 
	jump_buffer_timer.stop()
	player_model.scale = Vector3(0.5, 1.5, 0.5) 

func _on_jump_state_physics_processing(delta: float) -> void:
	apply_movement(delta, walk_speed, acceleration, deceleration)
	apply_gravity(delta, jump_gravity)
	
	if velocity.y < 0:
		state_chart.send_event("JumpApexReached")

func _on_jump_event_received(event: StringName) -> void:
	if event == "JumpReleased":
		if velocity.y > 0:
			velocity.y *= jump_cut_multiplier

# --- FALLING ---
func _on_falling_state_entered() -> void:
	pass

func _on_falling_state_physics_processing(delta: float) -> void:
	apply_movement(delta, walk_speed, acceleration, deceleration)
	
	# FIX: Only use floaty gravity near the peak (between 2.0 and -5.0)
	# If we are moving UP fast (like after a Wall Jump), use normal gravity.
	
	if velocity.y > 0.0: 
		# Moving up fast? Use normal jump gravity (Heavy)
		apply_gravity(delta, jump_gravity) 
		
	elif velocity.y > jump_apex_max_speed: 
		# Near the top (Floaty)
		apply_gravity(delta, jump_apex_gravity) 
		
	else:
		# Falling down fast (Heavy)
		apply_gravity(delta, fall_gravity)
	
	velocity.y = max(velocity.y, max_fall_speed)

# --- DASHING (Simple Movement) ---
func _on_dashing_state_entered() -> void:
	dash_timer.start()
	dash_cooldown_timer.start()
	velocity = last_input_direction * dash_speed
	velocity.y = 0 

func _on_dashing_state_physics_processing(delta: float) -> void:
	# No gravity, no friction, just slide
	pass

# --- WALL RUNNING (New) ---
func _on_wall_run_state_entered() -> void:
	Is_wallrunning = true
	velocity.y = 0 
	jump_buffer_timer.stop()
	var tangent = Vector3.UP.cross(wall_normal)
	
	# 2. Compare it to where the player is currently looking
	# We use the model's forward vector (-transform.basis.z)
	var player_facing = -player_model.global_transform.basis.z
	
	# The Dot Product tells us if two vectors point in similar directions.
	# If dot < 0, they are pointing away from each other (Opposite).
	if tangent.dot(player_facing) < 0:
		tangent = -tangent
		
	# 3. Store this smart direction
	wall_forward_direction = tangent.normalized()

func _on_wall_run_state_physics_processing(delta: float) -> void:
	# We use the stored direction, ignoring your joystick
	var target_x = wall_forward_direction.x * wall_run_speed
	var target_z = wall_forward_direction.z * wall_run_speed
	
	velocity.x = move_toward(velocity.x, target_x, acceleration * delta * 2)
	velocity.z = move_toward(velocity.z, target_z, acceleration * delta * 2)
	
	# 2. Gravity (Glide)
	velocity.y -= wall_run_gravity * delta
	if velocity.y > 0: velocity.y = 0
	
	# 3. Visuals (Tilt)
	
	
	# 4. Rotate Model to face the run direction
	var run_angle = atan2(-wall_forward_direction.x, -wall_forward_direction.z)
	player_model.rotation.y = lerp_angle(player_model.rotation.y, run_angle, 10 * delta)
	
	# 5. Jump Check
	if jump_buffer_timer.time_left > 0:
		state_chart.send_event("WallJump")

func _on_wall_run_state_exited() -> void:
	Is_wallrunning = false
	model_pivot.rotation.z = 0
	current_jump_count = 0

# --- WALL JUMP (New) ---
func _on_wall_jump_state_entered() -> void:
	current_jump_count += 1
	# Calculate Jump Direction (Up + Away from Wall)
	var jump_dir = (Vector3.UP * wall_jump_force_up) + (wall_normal * wall_jump_force_side)
	velocity = jump_dir
	jump_buffer_timer.stop()
	
	# Lock movement briefly so you don't steer back into wall
	await get_tree().create_timer(0.2).timeout
	state_chart.send_event("WallJumpFinished")

# --- GROUND SMASH ---
func _on_ground_smashing_state_entered() -> void:
	velocity = Vector3.ZERO 

func _on_ground_smashing_state_physics_processing(delta: float) -> void:
	if velocity.y > jump_apex_max_speed:
		velocity.y -= jump_apex_gravity * delta
	elif velocity.y <= jump_apex_max_speed and velocity.y > ground_smash_max_speed:
		velocity.y -= ground_smash_gravity * delta
	else:
		velocity.y = ground_smash_max_speed

func _on_ground_smashing_state_exited() -> void:
	ground_smashing_timer.start()
	super_jump_window.start() # Activate Super Jump window
#endregion

#region Visuals & Debug
func handle_visual_effects(delta: float) -> void:
	%MovingParticles.emitting = is_on_floor() and velocity.length_squared() > 1.0
	
	# Scale Return
	player_model.scale = player_model.scale.lerp(Vector3.ONE, delta * 10)
	
	# Rotation (Only if not wall running to prevent fighting the tilt)
	# (We check !check_wall_run() implicitly because wall run state handles its own rotation)
	if not check_wall_run() and Vector2(velocity.z, velocity.x).length() > 0.1:
		rotation_direction = Vector2(-last_input_direction.z, -last_input_direction.x).angle()
		player_model.rotation.y = lerp_angle(player_model.rotation.y, rotation_direction, delta * rotation_speed)
	
	# Leaning
	var local_vel = global_transform.basis.inverse() * velocity
	local_vel.y = 0
	var target_lean = Vector3.ZERO
	if local_vel.length() > 0.1:
		local_vel = local_vel.normalized()
		target_lean.x = -local_vel.z * max_lean_angle
		target_lean.z = -local_vel.x * max_lean_angle
	
	if is_on_floor():
		model_pivot.rotation_degrees.x = lerp(model_pivot.rotation_degrees.x, -target_lean.x, lean_speed * delta)
		model_pivot.rotation_degrees.z = lerp(model_pivot.rotation_degrees.z, target_lean.z, lean_speed * delta)
	# Note: We don't reset tilt here if WallRunning, as that state handles Z tilt.

func debug() -> void:
	DebugDraw3D.draw_arrow(position, position + (velocity * 0.2), Color(0.0, 0.831, 0.841), 0.1)
	speed_number.text = str(Vector2(velocity.x,velocity.z).length()).pad_decimals(2)
	velocity_number.text = str(velocity)
#endregion
