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
@export var jump_buffer_time: float = 0.1      # Time input is saved before hitting ground
@export var variable_jump_cut: float = 0.5    # Multiplier when releasing jump button early
@export var hang_time_threshold: float = 50.0 # Velocity range to trigger "Apex" gravity
@export var hang_time_gravity_mult: float = 0.5 # Gravity multiplier at the apex

@export_category("Abilities")
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export_range(0.0, 1.0) var sad_glide_gravity: float = 0.1 # 10% of normal gravity when holding dash
@export var happy_explosion_height: float = 300.0 # How high the "Happy" explosion jumps
@export var smash_speed: float = 1500.0 # Speed for Love Ground Smash

# --- INTERNAL VARIABLES ---

# Calculated Gravity Variables
var jump_gravity: float
var fall_gravity: float

# Timers
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var happy_charge_timer: float = 0.0 

# State Machine
enum State { IDLE, RUN, JUMP, FALL, DASH, SMASH }
var current_state: int = State.FALL
var can_dash: bool = true

enum Personality {SAD, ANGRY, HAPPY, LOVE}
var current_personality : int = Personality.SAD
var tween: Tween

@onready var player_visual: Node2D = $PlayerVisual
@onready var face: AnimatedSprite2D = %Face
@onready var anim: AnimationPlayer = $Anim

const MULTI_PARTICLE_EXAMPLE_2 = preload("uid://duqam6ffexoc8")


func _ready() -> void:
	# Initialize first personality
	apply_personality(current_personality)
	
	jump_gravity = (2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
	fall_gravity = (2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)

func _physics_process(delta: float) -> void:
	update_shader()
	handle_personality_switching()
	
	# 1. Update Timers
	if not is_on_floor():
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time
		can_dash = true 
		
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# 2. Handle Continuous Happy Mechanics
	if current_personality == Personality.HAPPY:
		handle_happy_charge_mechanics(delta)
	else:
		reset_visual_offsets()

	# 3. State Machine Logic
	match current_state:
		State.IDLE:
			handle_movement(delta)
			apply_gravity(delta)
			check_jump_start()
			handle_ability_input() 
			check_fall_transition()
			if velocity.x != 0: change_state(State.RUN)

		State.RUN:
			handle_movement(delta)
			apply_gravity(delta)
			check_jump_start()
			handle_ability_input()
			check_fall_transition()
			if velocity.x == 0: change_state(State.IDLE)

		State.JUMP:
			handle_movement(delta)
			apply_gravity(delta)
			handle_ability_input()
			handle_variable_jump_height()
			
			if velocity.y > 0: change_state(State.FALL)
			elif is_on_floor(): change_state(State.IDLE)

		State.FALL:
			handle_movement(delta)
			apply_gravity(delta)
			check_jump_start() 
			handle_ability_input()
			if is_on_floor(): change_state(State.IDLE)

		State.DASH:
			dash_timer -= delta
			if dash_timer <= 0:
				change_state(State.FALL)

		State.SMASH:
			velocity.y = smash_speed
			if is_on_floor():
				perform_smash_impact()
				change_state(State.IDLE)

	move_and_slide()

# --- LOGIC HELPERS ---

func change_state(new_state: int) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		State.IDLE:
			anim.play("Idle")
		State.RUN:
			anim.play("Running")
		State.JUMP:
			anim.play("Jumping")
		State.FALL:
			anim.play("Falling")
		State.DASH:
			pass
		State.SMASH:
			anim.play("Falling") 

func handle_movement(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		if direction > 0:
			player_visual.scale.x = abs(player_visual.scale.x)
		else:
			player_visual.scale.x = -abs(player_visual.scale.x)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func apply_gravity(delta: float) -> void:
	var applied_gravity = 0.0
	
	if abs(velocity.y) < hang_time_threshold:
		applied_gravity = jump_gravity * hang_time_gravity_mult
	elif velocity.y < 0:
		applied_gravity = jump_gravity
	else:
		applied_gravity = fall_gravity

	# --- SAD ABILITY: FLOATING ---
	if current_personality == Personality.SAD and velocity.y > 0 and Input.is_action_pressed("dash"):
		applied_gravity *= sad_glide_gravity

	velocity.y += applied_gravity * delta

func check_jump_start() -> void:
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0):
		perform_jump()

func perform_jump() -> void:
	velocity.y = -sqrt(2.0 * jump_gravity * jump_height)
	jump_buffer_timer = 0 
	coyote_timer = 0      
	change_state(State.JUMP)

func handle_variable_jump_height() -> void:
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= variable_jump_cut

# --- ABILITY HANDLER ---
func handle_ability_input() -> void:
	if Input.is_action_just_pressed("dash"):
		match current_personality:
			Personality.ANGRY:
				if can_dash and dash_cooldown_timer <= 0:
					start_dash()
			Personality.LOVE:
				perform_love_ability()
			_:
				pass

func handle_happy_charge_mechanics(delta: float) -> void:
	if Input.is_action_pressed("dash"):
		happy_charge_timer += delta
		var intensity = clamp(happy_charge_timer / 2.0, 0.0, 1.0)
		var shake_amount = intensity * 5.0
		player_visual.position = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		
		var blink_speed = 10.0 + (intensity * 40.0)
		var blink_val = (sin(happy_charge_timer * blink_speed) + 1.0) / 2.0
		if $PlayerVisual/Head:
			$PlayerVisual/Head.modulate = Color.WHITE.lerp(Color(4, 4, 4, 1), blink_val * intensity)
		
	elif Input.is_action_just_released("dash"):
		perform_happy_explosion()
		reset_visual_offsets()
	else:
		reset_visual_offsets()

func reset_visual_offsets() -> void:
	happy_charge_timer = 0.0
	player_visual.position = Vector2.ZERO
	if $PlayerVisual/Head:
		$PlayerVisual/Head.modulate = Color.WHITE

func start_dash() -> void:
	var dash_dir = Input.get_axis("move_left", "move_right")
	if dash_dir == 0:
		dash_dir = 1 if velocity.x >= 0 else -1
	velocity.y = 0 
	velocity.x = dash_dir * dash_speed
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	can_dash = false 
	change_state(State.DASH)

func perform_happy_explosion() -> void:
	var intensity = clamp(happy_charge_timer / 2.0, 0.2, 1.0)
	var explosion = MULTI_PARTICLE_EXAMPLE_2.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	
	var jump_force = -sqrt(2.0 * jump_gravity * happy_explosion_height)
	velocity.y = jump_force * intensity
	change_state(State.JUMP)
	print("Happy BOOM!")

func perform_love_ability() -> void:
	if not is_on_floor():
		velocity.x = 0
		velocity.y = smash_speed
		change_state(State.SMASH)

func perform_smash_impact() -> void:
	var impact = MULTI_PARTICLE_EXAMPLE_2.instantiate()
	get_parent().add_child(impact)
	impact.global_position = global_position

func check_fall_transition() -> void:
	if not is_on_floor() and velocity.y > 0 and current_state != State.SMASH:
		change_state(State.FALL)

# --- SWITCHING LOGIC ---

func handle_personality_switching() -> void:
	# 1. WHEEL MENU
	if Input.is_action_just_pressed("Change"):
		Engine.time_scale = 0.2
		$CanvasLayer/SelectionWheel.show()
	
	elif Input.is_action_just_released("Change"):
		Engine.time_scale = 1
		
		# UPDATED LOGIC:
		# Store the result in a variable first so we don't call the function twice
		var selected_personality = $CanvasLayer/SelectionWheel.get_selection()
		
		# Only apply if the selection is valid (not -1)
		if selected_personality != -1:
			apply_personality(selected_personality)

	# 2. KEYBOARD NUMBERS (1, 2, 3, 4)
	if Input.is_key_pressed(KEY_1): apply_personality(Personality.SAD)
	if Input.is_key_pressed(KEY_2): apply_personality(Personality.ANGRY)
	if Input.is_key_pressed(KEY_3): apply_personality(Personality.HAPPY)
	if Input.is_key_pressed(KEY_4): apply_personality(Personality.LOVE)

	# 3. CONTROLLER SHOULDERS (Cycle Next/Prev)
	if Input.is_action_just_pressed("swap_next"):
		var next = (current_personality + 1) % 4
		apply_personality(next)
		
	if Input.is_action_just_pressed("swap_prev"):
		var prev = (current_personality - 1 + 4) % 4
		apply_personality(prev)

# Helper to centralize switching logic
func apply_personality(new_personality: int) -> void:
	if current_personality == new_personality and not Engine.get_process_frames() > 0:
		return
		
	current_personality = new_personality
	GameManger.ChangePersonality(current_personality)
	face.frame = current_personality
	reset_visual_offsets()

func update_shader():
	RenderingServer.global_shader_parameter_set("player_pos", global_position)
	var screen_pos = get_global_transform_with_canvas().origin
	RenderingServer.global_shader_parameter_set("player_screen_pos", screen_pos)
	var current_zoom = 1.0
	var cam = get_viewport().get_camera_2d()
	if cam:
		current_zoom = cam.zoom.x
		
	RenderingServer.global_shader_parameter_set("camera_zoom", current_zoom)
