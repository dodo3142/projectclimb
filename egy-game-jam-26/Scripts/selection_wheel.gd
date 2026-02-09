@tool
extends Control

const SPRITE_SIZE = Vector2(128 * 2,90 * 2)

@export var bkg_color : Color
@export var line_color : Color
@export var highlight_color: Color

@export var outer_radius : int = 256
@export var inner_raduis : int = 64
@export var line_width : int = 4

@export var options: Array[WheelOption]

# Selection is -1 if mouse is in the center (dead zone)
var selection = -1

func close() -> int:
	hide()
	return selection

func _draw() -> void:
	var offset = SPRITE_SIZE / -2
	var count = len(options)
	
	# 1. Draw Background Geometry
	draw_circle(Vector2.ZERO, outer_radius, bkg_color)
	draw_arc(Vector2.ZERO, inner_raduis, 0, TAU, 256, line_color, line_width, true)
	
	if count > 0:
		# 2. Draw Separator Lines
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
			
		# 3. Draw Options (Highlight + Icon)
		for i in range(count):
			var start_rads = (TAU * i) / count
			var end_rads = (TAU * (i + 1)) / count
			var mid_rads = (start_rads + end_rads) / 2.0 * -1
			var raduis_mid = (inner_raduis + outer_radius) / 2
			
			# Draw Highlight Wedge if selected
			if selection == i:
				var points_per_arc = 32
				var points_inner = PackedVector2Array()
				var points_outer = PackedVector2Array()
				
				for j in range(points_per_arc + 1):
					var angle = start_rads + j * (end_rads - start_rads) / points_per_arc
					# Note: original code inverted angle for drawing (TAU - angle)
					points_inner.append(inner_raduis * Vector2.from_angle(TAU - angle))
					points_outer.append(outer_radius * Vector2.from_angle(TAU - angle))
				
				points_outer.reverse()
				draw_polygon(
					points_inner + points_outer,
					PackedColorArray([highlight_color])
				)
			
			# Draw Icon
			var draw_pos = raduis_mid * Vector2.from_angle(mid_rads) + offset
			draw_texture_rect_region(
				options[i].atlas,
				Rect2(draw_pos, SPRITE_SIZE),
				options[i].region
			)

func _process(delta: float) -> void:
	var mouse_pos = get_local_mouse_position()
	var mouse_radius = mouse_pos.length()
	
	# Check if mouse is in the center "dead zone"
	if mouse_radius < inner_raduis:
		selection = -1
	else:
		# Calculate angle (0 to TAU)
		var mouse_rads = fposmod(mouse_pos.angle() * -1, TAU)
		# Map angle to an index between 0 and options.size()
		selection = int((mouse_rads / TAU) * len(options))
		# Clamp just in case floating point math goes slightly over
		selection = clampi(selection, 0, len(options) - 1)
	
	queue_redraw()
