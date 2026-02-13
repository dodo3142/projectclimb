extends Control

const SPRITE_SIZE = Vector2(128 * 2, 90 * 2) # Adjusted based on typical sprite needs

@export_group("Appearance")
@export var bkg_color : Color = Color(0, 0, 0, 0.5)
@export var line_color : Color = Color.WHITE
@export var highlight_color: Color = Color(1, 1, 1, 0.3)

@export_subgroup("Special Colors")
## These colors will be used for the first 4 options in the wheel.
@export var segment_colors: Array[Color] = [
	Color.RED, 
	Color.GREEN, 
	Color.BLUE, 
	Color.YELLOW
]

@export_group("Dimensions")
@export var outer_radius : int = 256
@export var inner_raduis : int = 64
@export var line_width : int = 4

@export_group("Data")
@export var options: Array[WheelOption] # Ensure WheelOption is a valid class/resource

@export_group("Input")
@export var joystick_deadzone: float = 0.2

# Internal State
var selection = -1
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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.velocity.length() > 0:
		is_using_gamepad = false
	elif event is InputEventJoypadMotion and abs(event.axis_value) > joystick_deadzone:
		is_using_gamepad = true

func _process(delta: float) -> void:
	if not IS_open: return
	
	var previous_selection = selection
	var count = len(options)
	if count == 0: return

	# 1. CONTROLLER INPUT
	if is_using_gamepad:
		var controller_dir = Input.get_vector("select_left", "select_right", "select_up", "select_down")
		if controller_dir.length() > joystick_deadzone:
			var controller_rads = fposmod(controller_dir.angle() * -1, TAU)
			var new_sel = int((controller_rads / TAU) * count)
			selection = clampi(new_sel, 0, count - 1)
			
	# 2. MOUSE INPUT
	else:
		var mouse_pos = get_local_mouse_position()
		if mouse_pos.length() < inner_raduis:
			selection = -1
		else:
			var mouse_rads = fposmod(mouse_pos.angle() * -1, TAU)
			var new_sel = int((mouse_rads / TAU) * count)
			selection = clampi(new_sel, 0, count - 1)
	
	# 3. SOUND & REDRAW
	if selection != previous_selection:
		if selection != -1:
			$Hover.stop()
			$Hover.play()
		queue_redraw()

func _draw() -> void:
	var offset = SPRITE_SIZE / -2
	var count = len(options)
	
	# --- DRAW BASE BACKGROUND ---
	draw_circle(Vector2.ZERO, float(outer_radius), bkg_color)
	
	if count > 0:
		for i in range(count):
			var start_rads = (TAU * i) / count
			var end_rads = (TAU * (i + 1)) / count
			var mid_rads = (start_rads + end_rads) / 2.0
			
			# --- DETERMINE COLOR ---
			var draw_color = Color(0,0,0,0) # Default transparent
			
			# Logic for the first 4 items (using Inspector colors)
			if i < 4 and i < segment_colors.size():
				draw_color = segment_colors[i]
				# If selected, make it brighter so we know it's active
				if selection == i:
					draw_color = draw_color.lightened(0.4)
			
			# Logic for other items (5+)
			elif selection == i:
				draw_color = highlight_color

			# --- DRAW SECTOR (If visible) ---
			if draw_color.a > 0:
				var points_per_arc = 32
				var points_inner = PackedVector2Array()
				var points_outer = PackedVector2Array()
				
				for j in range(points_per_arc + 1):
					var angle = start_rads + j * (end_rads - start_rads) / points_per_arc
					# Convert angle to vector (using TAU - angle to match coordinate system)
					var angle_vec = Vector2.from_angle(TAU - angle)
					points_inner.append(inner_raduis * angle_vec)
					points_outer.append(outer_radius * angle_vec)
				
				points_outer.reverse()
				draw_polygon(points_inner + points_outer, PackedColorArray([draw_color]))

			# --- DRAW SEPARATOR LINES ---
			var line_angle_vec = Vector2.from_angle(TAU - start_rads)
			draw_line(
				line_angle_vec * inner_raduis,
				line_angle_vec * outer_radius,
				line_color,
				float(line_width),
				true
			)

			# --- DRAW ICONS ---
			if options[i].atlas:
				var draw_pos = ((inner_raduis + outer_radius) / 2.0) * Vector2.from_angle(TAU - mid_rads) + offset
				draw_texture_rect_region(
					options[i].atlas,
					Rect2(draw_pos, SPRITE_SIZE),
					options[i].region
				)

	# --- DRAW INNER HOLE STROKE ---
	draw_arc(Vector2.ZERO, float(inner_raduis), 0, TAU, 128, line_color, float(line_width), true)
