extends Control

const SPRITE_SIZE = Vector2(128 * 2, 90 * 2)

@export var bkg_color : Color
@export var line_color : Color
@export var highlight_color: Color

@export var outer_radius : int = 256
@export var inner_raduis : int = 64
@export var line_width : int = 4

@export var options: Array[WheelOption]

# Controller Settings
@export var joystick_deadzone: float = 0.2

# Selection is -1 if mouse is in the center (dead zone)
var selection = -1

# Track which input device was last used
var is_using_gamepad = false

var IS_open = false

func get_selection() -> int:
	hide()
	$Close.play()
	IS_open = false
	return selection

func open() -> void:
	show()
	$Open.play()
	IS_open = true

# Detect if the user is moving the mouse or the controller
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.velocity.length() > 0:
		is_using_gamepad = false
	elif event is InputEventJoypadMotion and abs(event.axis_value) > joystick_deadzone:
		is_using_gamepad = true

func _process(delta: float) -> void:
	if not IS_open: return
	# Store the selection BEFORE we update it
	var previous_selection = selection

	# --- EXISTING LOGIC START ---
	# 1. CONTROLLER MODE
	if is_using_gamepad:
		var controller_dir = Input.get_vector("select_left", "select_right", "select_up", "select_down")
		
		if controller_dir.length() > joystick_deadzone:
			var controller_rads = fposmod(controller_dir.angle() * -1, TAU)
			# Create a temp variable so we don't overwrite 'selection' immediately if we needed to do math
			var new_sel = int((controller_rads / TAU) * len(options))
			selection = clampi(new_sel, 0, len(options) - 1)
			
	# 2. MOUSE MODE
	else:
		var mouse_pos = get_local_mouse_position()
		var mouse_radius = mouse_pos.length()
		
		# If mouse is in center, deselect
		if mouse_radius < inner_raduis:
			selection = -1
		else:
			# Calculate angle
			var mouse_rads = fposmod(mouse_pos.angle() * -1, TAU)
			var new_sel = int((mouse_rads / TAU) * len(options))
			selection = clampi(new_sel, 0, len(options) - 1)
	# --- EXISTING LOGIC END ---
	
	# 3. SOUND LOGIC
	# If the selection changed this frame...
	if selection != previous_selection:
		# And we didn't just move to the "dead zone" (-1)...
		if selection != -1:
			# Play the sound!
			$Hover.stop() 
			$Hover.play() 
	
	queue_redraw()

func _draw() -> void:
	var offset = SPRITE_SIZE / -2
	var count = len(options)
	
	# 1. Draw Background
	draw_circle(Vector2.ZERO, outer_radius, bkg_color)
	draw_arc(Vector2.ZERO, inner_raduis, 0, TAU, 256, line_color, line_width, true)
	
	if count > 0:
		# 2. Draw Lines
		for i in range(count):
			var rads = TAU * i / count
			var point = Vector2.from_angle(rads)
			draw_line(
				point * inner_raduis,
				point * outer_radius,
				line_color,
				line_width,
				true
			)
			
		# 3. Draw Options
		for i in range(count):
			var start_rads = (TAU * i) / count
			var end_rads = (TAU * (i + 1)) / count
			var mid_rads = (start_rads + end_rads) / 2.0 * -1
			var raduis_mid = (inner_raduis + outer_radius) / 2
			
			# Draw Highlight
			if selection == i:
				var points_per_arc = 32
				var points_inner = PackedVector2Array()
				var points_outer = PackedVector2Array()
				
				for j in range(points_per_arc + 1):
					var angle = start_rads + j * (end_rads - start_rads) / points_per_arc
					points_inner.append(inner_raduis * Vector2.from_angle(TAU - angle))
					points_outer.append(outer_radius * Vector2.from_angle(TAU - angle))
				
				points_outer.reverse()
				draw_polygon(
					points_inner + points_outer,
					PackedColorArray([highlight_color])
				)
			
			# Draw Icon
			if options[i].atlas:
				var draw_pos = raduis_mid * Vector2.from_angle(mid_rads) + offset
				draw_texture_rect_region(
					options[i].atlas,
					Rect2(draw_pos, SPRITE_SIZE),
					options[i].region
				)
