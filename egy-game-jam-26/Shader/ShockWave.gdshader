shader_type canvas_item;

// --- GLOBAL UNIFORMS ---
global uniform vec2 player_screen_pos;
global uniform float camera_zoom; 

global uniform float angry_vision_radius;
global uniform float happy_vision_radius;
global uniform float love_vision_radius;
global uniform float sad_vision_radius;

// --- SETTINGS ---
uniform float distortion_strength : hint_range(0.0, 50.0) = 10.0;
uniform float distortion_speed : hint_range(0.0, 10.0) = 3.0;
uniform float edge_softness : hint_range(0.0, 50.0) = 10.0;

// --- COLORS ---
uniform vec4 color_angry : source_color = vec4(1.0, 0.0, 0.0, 0.5);
uniform vec4 color_happy : source_color = vec4(0.0, 1.0, 0.0, 0.5);
uniform vec4 color_love : source_color  = vec4(1.0, 0.4, 0.7, 0.5);
uniform vec4 color_sad : source_color   = vec4(0.0, 0.0, 1.0, 0.5);

void fragment() {
	// 1. Calculate Distorted Distance
	float dist = distance(FRAGCOORD.xy, player_screen_pos);
	vec2 rel_pos = FRAGCOORD.xy - player_screen_pos;
	float angle = atan(rel_pos.y, rel_pos.x);
	
	float wave = sin(angle * 10.0 + TIME * distortion_speed) * distortion_strength;
	wave += cos(angle * 20.0 - TIME * (distortion_speed * 1.5)) * (distortion_strength * 0.5);
	float distorted_dist = dist + wave;
	
	// 2. Scale Radii by Zoom
	float r_angry = angry_vision_radius * camera_zoom;
	float r_happy = happy_vision_radius * camera_zoom;
	float r_sad   = sad_vision_radius   * camera_zoom;
	float r_love  = love_vision_radius  * camera_zoom;

	vec4 final_color = vec4(0.0); // Start transparent

	// --- 3. LAYERING LOGIC (The Fix) ---
	// We use independent 'if' statements (NO 'else').
	// We MUST check from LARGEST Radius to SMALLEST Radius.
	// This ensures the small circles draw ON TOP of the big ones.

	// Layer 1: Angry (Assuming this is the largest/background)
	if (distorted_dist < r_angry) {
		float edge = smoothstep(r_angry, r_angry - edge_softness, distorted_dist);
		// Mix current color (transparent) with Red
		final_color = mix(final_color, color_angry, edge);
	}

	// Layer 2: Happy (Assuming this is smaller than Angry)
	if (distorted_dist < r_happy) {
		float edge = smoothstep(r_happy, r_happy - edge_softness, distorted_dist);
		// Mix current color (Red) with Green
		final_color = mix(final_color, color_happy, edge);
	}

	// Layer 3: Sad (Assuming smaller)
	if (distorted_dist < r_sad) {
		float edge = smoothstep(r_sad, r_sad - edge_softness, distorted_dist);
		// Mix current color with Blue
		final_color = mix(final_color, color_sad, edge);
	}

	// Layer 4: Love (Assuming smallest/closest)
	if (distorted_dist < r_love) {
		float edge = smoothstep(r_love, r_love - edge_softness, distorted_dist);
		// Mix current color with Pink
		final_color = mix(final_color, color_love, edge);
	}

	COLOR = final_color;
}