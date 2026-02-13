shader_type canvas_item;

// --- GLOBAL UNIFORMS ---
// We now expect this to be Normalized (0.0 to 1.0) from the GDScript
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
	// --- 1. COORDINATE FIX ---
	// Convert the Normalized Position (0.0-1.0) back to actual Window Pixels
	// SCREEN_PIXEL_SIZE is (1/width, 1/height), so dividing by it gives us (width, height)
	vec2 player_window_pos = player_screen_pos / SCREEN_PIXEL_SIZE;

	// Now calculate distance using the corrected position
	float dist = distance(FRAGCOORD.xy, player_window_pos);
	vec2 rel_pos = FRAGCOORD.xy - player_window_pos;
	
	// --- 2. DISTORTION LOGIC ---
	// (Check safe atan to avoid center glitch)
	float angle = 0.0;
	if (length(rel_pos) > 0.001) {
		angle = atan(rel_pos.y, rel_pos.x);
	}
	
	float wave = sin(angle * 10.0 + TIME * distortion_speed) * distortion_strength;
	wave += cos(angle * 20.0 - TIME * (distortion_speed * 1.5)) * (distortion_strength * 0.5);
	
	float distorted_dist = dist + wave;
	distorted_dist = max(distorted_dist, 0.0);
	
	// --- 3. SCALE RADII ---
	// Note: If you want the circles to scale with the window size (not just camera zoom),
	// you might need to multiply by a window scale factor here too. 
	// For now, we stick to camera_zoom.
	float r_angry = angry_vision_radius * camera_zoom;
	float r_happy = happy_vision_radius * camera_zoom;
	float r_sad   = sad_vision_radius   * camera_zoom;
	float r_love  = love_vision_radius  * camera_zoom;

	vec4 final_color = vec4(0.0); 

	// --- 4. LAYERING LOGIC ---
	// Layer 1: Angry
	if (distorted_dist < r_angry) {
		float edge = smoothstep(r_angry, r_angry - edge_softness, distorted_dist);
		final_color = mix(final_color, color_angry, edge);
	}

	// Layer 2: Happy
	if (distorted_dist < r_happy) {
		float edge = smoothstep(r_happy, r_happy - edge_softness, distorted_dist);
		final_color = mix(final_color, color_happy, edge);
	}

	// Layer 3: Sad
	if (distorted_dist < r_sad) {
		float edge = smoothstep(r_sad, r_sad - edge_softness, distorted_dist);
		final_color = mix(final_color, color_sad, edge);
	}

	// Layer 4: Love
	if (distorted_dist < r_love) {
		float edge = smoothstep(r_love, r_love - edge_softness, distorted_dist);
		final_color = mix(final_color, color_love, edge);
	}

	COLOR = final_color;
}