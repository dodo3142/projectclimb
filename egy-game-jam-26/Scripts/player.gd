extends CharacterBody2D

# --- CONFIGURATION ---

@export_category("Movement")
@export var speed: float = 300.0
@export var acceleration: float = 1800.0
@export var friction: float = 2000.0

@export_category("Jump Physics")
@export var jump_height: float = 120.0
@export var jump_time_to_peak: float = 0.4
@export var jump_time_to_descent: float = 0.3

@export_category("Jump Feel")
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.1
@export var variable_jump_cut: float = 0.5
@export var hang_time_threshold: float = 50.0
@export var hang_time_gravity_mult: float = 0.5

@export_category("Wall Physics")
@export var wall_slide_speed: float = 150.0
@export var wall_jump_push_back: float = 400.0
@export var wall_jump_force: float = -400.0

@export_category("Abilities")
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.5
@export var dash_buffer_time: float = 0.15 
@export_range(0.0, 1.0) var sad_glide_gravity: float = 0.1
@export var happy_explosion_height: float = 300.0
@export var smash_speed: float = 1500.0

# --- INTERNAL VARIABLES ---

var jump_gravity: float
var fall_gravity: float

# Timers
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_buffer_timer: float = 0.0 
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var happy_charge_timer: float = 0.0 

# State Machine
enum State { IDLE, RUN, JUMP, FALL, DASH, SMASH, WALL_SLIDE }
var current_state: int = State.FALL
var can_dash: bool = true

enum Personality {SAD, ANGRY, HAPPY, LOVE}
var current_personality : int = Personality.SAD

# NODE REFERENCES
@onready var player_visual: Node2D = $PlayerVisual
@onready var face: AnimatedSprite2D = %Face
@onready var anim: AnimationPlayer = $Anim

# RAYCAST REFERENCES (Make sure these match your node names!)
@onready var wall_check_right: RayCast2D = $WallCheckRight
@onready var wall_check_left: RayCast2D = $WallCheckLeft

const MULTI_PARTICLE_EXAMPLE_2 = preload("uid://duqam6ffexoc8")


func _ready() -> void:
	apply_personality(current_personality)
	GameManger.ChangePersonality(current_personality)
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
		
	# Input Buffering
	if Input.is_action_just_pressed("jump"): jump_buffer_timer = jump_buffer_time
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
		
	if Input.is_action_just_pressed("dash"): dash_buffer_timer = dash_buffer_time
	if dash_buffer_timer > 0: dash_buffer_timer -= delta
		
	if dash_cooldown_timer > 0: dash_cooldown_timer -= delta

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
			if current_state != State.IDLE: return
			
			check_fall_transition()
			if current_state != State.IDLE: return
			if velocity.x != 0: change_state(State.RUN)

		State.RUN:
			handle_movement(delta)
			apply_gravity(delta)
			check_jump_start()
			handle_ability_input()
			if current_state != State.RUN: return

			check_fall_transition()
			if velocity.x == 0: change_state(State.IDLE)

		State.JUMP:
			handle_movement(delta)
			apply_gravity(delta)
			handle_ability_input()
			if current_state != State.JUMP: return
			
			handle_variable_jump_height()
			check_wall_slide_transition()
			if current_state != State.JUMP: return
			
			if velocity.y > 0: 
				change_state(State.FALL)
			# FIX: Only go to IDLE if on floor AND NOT moving up
			elif is_on_floor() and velocity.y >= 0: 
				change_state(State.IDLE)

		State.FALL:
			handle_movement(delta)
			apply_gravity(delta)
			check_jump_start() 
			handle_ability_input()
			if current_state != State.FALL: return

			check_wall_slide_transition() 
			if is_on_floor(): change_state(State.IDLE)
		
		State.WALL_SLIDE:
			can_dash = true 
			
			handle_wall_slide_movement(delta)
			handle_ability_input()
			if current_state != State.WALL_SLIDE: return

			if is_on_floor():
				change_state(State.IDLE)
			
			# FIX: Check Rays instead of is_on_wall()
			elif get_wall_direction() == 0:
				change_state(State.FALL)
				
			elif Input.is_action_just_pressed("jump"):
				perform_wall_jump()

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

# NEW HELPER: Returns 1 (Right), -1 (Left), or 0 (None)
func get_wall_direction() -> int:
	if wall_check_right.is_colliding():
		return 1
	elif wall_check_left.is_colliding():
		return -1
	return 0

func change_state(new_state: int) -> void:
	if current_state == new_state: return
	current_state = new_state
	
	match current_state:
		State.IDLE: anim.play("Idle")
		State.RUN: anim.play("Running")
		State.JUMP: 
			anim.play("Jumping")
			$Audios/Jump.play()
		State.FALL: anim.play("Falling")
		State.WALL_SLIDE: 
			if anim.has_animation("WallSlide"): anim.play("WallSlide")
			else: anim.play("Falling")
		State.SMASH: anim.play("Falling")
		State.DASH: anim.play("Dash")

func handle_movement(delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		if direction > 0: player_visual.scale.x = abs(player_visual.scale.x)
		else: player_visual.scale.x = -abs(player_visual.scale.x)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func check_wall_slide_transition() -> void:
	# Only enter wall slide if we are falling (velocity.y > 0)
	if velocity.y > 0 and not is_on_floor():
		if get_wall_direction() != 0:
			change_state(State.WALL_SLIDE)

func handle_wall_slide_movement(delta: float) -> void:
	# Just apply slow gravity. We don't need to force velocity.x anymore because Rays do the work.
	velocity.y = min(velocity.y + fall_gravity * delta, wall_slide_speed)
	
	# Optional: Allow slight movement off the wall? 
	# Usually best to lock X movement or dampen it heavily
	velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	# Face away from the wall
	var wall_dir = get_wall_direction()
	if wall_dir == 1: # Wall is Right
		player_visual.scale.x = -abs(player_visual.scale.x)
	elif wall_dir == -1: # Wall is Left
		player_visual.scale.x = abs(player_visual.scale.x)

func perform_wall_jump() -> void:
	var wall_dir = get_wall_direction()
	
	# If we somehow lost the wall for a microsecond, try to guess based on visual
	if wall_dir == 0:
		wall_dir = 1 if player_visual.scale.x > 0 else -1
	
	# Jump AWAY from wall (-wall_dir)
	velocity.x = -wall_dir * wall_jump_push_back
	velocity.y = wall_jump_force
	
	# Flip character visual
	player_visual.scale.x = -player_visual.scale.x
		
	change_state(State.JUMP)

func apply_gravity(delta: float) -> void:
	var applied_gravity = 0.0
	if abs(velocity.y) < hang_time_threshold: applied_gravity = jump_gravity * hang_time_gravity_mult
	elif velocity.y < 0: applied_gravity = jump_gravity
	else: applied_gravity = fall_gravity

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

func handle_ability_input() -> void:
	if dash_buffer_timer > 0:
		match current_personality:
			Personality.ANGRY:
				if can_dash and dash_cooldown_timer <= 0:
					start_dash()
			Personality.LOVE:
				perform_love_ability()
			_:
				pass

func start_dash() -> void:
	var dash_dir = Input.get_axis("move_left", "move_right")
	
	# If no input, dash in facing direction
	if dash_dir == 0:
		dash_dir = 1 if player_visual.scale.x > 0 else -1

	# If on wall, FORCE dash away from wall regardless of input
	if current_state == State.WALL_SLIDE:
		dash_dir = -get_wall_direction()

	velocity.y = 0 
	velocity.x = dash_dir * dash_speed
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_buffer_timer = 0 
	can_dash = false 
	change_state(State.DASH)

func perform_love_ability() -> void:
	velocity.x = 0
	velocity.y = smash_speed
	dash_buffer_timer = 0
	change_state(State.SMASH)

func handle_happy_charge_mechanics(delta: float) -> void:
	if Input.is_action_pressed("dash"):
		happy_charge_timer += delta
		var intensity = clamp(happy_charge_timer / 2.0, 0.0, 1.0)
		var shake_amount = intensity * 5.0
		
		# Shake Position
		player_visual.position = Vector2(
			randf_range(-shake_amount, shake_amount), 
			randf_range(-shake_amount, shake_amount)
		)
		
		# --- FLASHING MATH ---
		# 1. Calculate a speed that gets faster as you charge
		var flash_speed = 15.0 + (intensity * 30.0)
		
		# 2. Create a value that bounces between 0.0 and 1.0 using Sine wave
		var flash_val = (sin(happy_charge_timer * flash_speed) + 1.0) / 2.0
		
		if $PlayerVisual/Head:
			# 3. Blink between Normal (White) and Bright Yellow
			# We use 'flash_val' to bounce back and forth
			var flash_color = Color.WHITE.lerp(Color(2, 2, 0, 1), flash_val) 
			
			# 4. Add global brightness based on charge intensity
			$PlayerVisual/Head.modulate = flash_color * (1.0 + intensity)

	elif Input.is_action_just_released("dash"):
		perform_happy_explosion()
		reset_visual_offsets()
	else:
		reset_visual_offsets()

func perform_happy_explosion() -> void:
	var intensity = clamp(happy_charge_timer / 2.0, 0.2, 1.0)
	var explosion = MULTI_PARTICLE_EXAMPLE_2.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	velocity.y = -sqrt(2.0 * jump_gravity * happy_explosion_height) * intensity
	change_state(State.JUMP)

func reset_visual_offsets() -> void:
	happy_charge_timer = 0.0
	player_visual.position = Vector2.ZERO
	if $PlayerVisual/Head: $PlayerVisual/Head.modulate = Color.WHITE

func perform_smash_impact() -> void:
	var impact = MULTI_PARTICLE_EXAMPLE_2.instantiate()
	get_parent().add_child(impact)
	impact.global_position = global_position

func check_fall_transition() -> void:
	if not is_on_floor() and velocity.y > 0 and current_state != State.SMASH:
		change_state(State.FALL)

# --- SWITCHING LOGIC ---

func handle_personality_switching() -> void:
	if Input.is_action_just_pressed("Change"):
		Engine.time_scale = 0.2
		$CanvasLayer/SelectionWheel.open()
	elif Input.is_action_just_released("Change"):
		Engine.time_scale = 1
		var selected_personality = $CanvasLayer/SelectionWheel.get_selection()
		if selected_personality != -1: apply_personality(selected_personality)

	if Input.is_key_pressed(KEY_1): apply_personality(Personality.SAD)
	if Input.is_key_pressed(KEY_2): apply_personality(Personality.ANGRY)
	if Input.is_key_pressed(KEY_3): apply_personality(Personality.HAPPY)
	if Input.is_key_pressed(KEY_4): apply_personality(Personality.LOVE)

	if Input.is_action_just_pressed("swap_next"): apply_personality((current_personality + 1) % 4)
	if Input.is_action_just_pressed("swap_prev"): apply_personality((current_personality - 1 + 4) % 4)

func apply_personality(new_personality: int) -> void:
	if current_personality != new_personality:
		$Audios/ChangePersonality.play()
	if current_personality == new_personality and not Engine.get_process_frames() > 0: return
	current_personality = new_personality
	GameManger.ChangePersonality(current_personality)
	face.frame = current_personality
	reset_visual_offsets()

func update_shader():
	RenderingServer.global_shader_parameter_set("player_pos", global_position)
	var screen_pos = get_global_transform_with_canvas().origin
	RenderingServer.global_shader_parameter_set("player_screen_pos", screen_pos)
	var cam = get_viewport().get_camera_2d()
	var current_zoom = cam.zoom.x if cam else 1.0
	RenderingServer.global_shader_parameter_set("camera_zoom", current_zoom)
