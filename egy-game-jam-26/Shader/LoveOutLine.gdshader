shader_type canvas_item;

// --- GLOBAL UNIFORMS ---
global uniform vec2 player_pos;
global uniform float love_vision_radius;

// --- SETTINGS ---
uniform vec4 color : source_color = vec4(1.0);
uniform float inner_stroke_thickness : hint_range(0.0, 10.0) = 3.0; 
uniform float inner_stroke_opacity : hint_range(0.0, 1.0) = 1.0; 
uniform float frequency : hint_range(0.0, 50.0) = 20.0; 
uniform float phase_speed : hint_range(0.0, 10.0) = 6.0; 

// --- DISSOLVE SETTINGS ---
uniform sampler2D noise_texture : repeat_enable; // The pattern for dissolving
uniform float dissolve_smoothness : hint_range(0.0, 0.1) = 0.05; // Softens the pixel edges slightly

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	float original_alpha = original_color.a;

	// --- 1. EDGE DETECTION (With Bounds Check) ---
	float radius = inner_stroke_thickness * TEXTURE_PIXEL_SIZE.x;
	float min_neighbor_alpha = 1.0;
	
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * radius;
			vec2 sample_uv = UV + offset;
			
			float sample_alpha;
			if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
				sample_alpha = 0.0; // Outside image = Transparent
			} else {
				sample_alpha = texture(TEXTURE, sample_uv).a;
			}
			min_neighbor_alpha = min(min_neighbor_alpha, sample_alpha);
		}
	}
	
	float is_edge = clamp(original_alpha - min_neighbor_alpha, 0.0, 1.0);

	// --- 2. ROTATING DOTS ---
	vec2 center_offset = UV - vec2(0.5);
	float angle = atan(center_offset.y, center_offset.x);
	if (angle < 0.0) { angle += 2.0 * PI; }
	
	float wave = 0.5 * sin(frequency * angle + TIME * phase_speed) + 0.5;
	float dotted_pattern = step(0.5, wave);

	// The "Far" look: Only the dotted outline
	vec4 far_effect_color = color;
	far_effect_color.a = is_edge * dotted_pattern * inner_stroke_opacity;

	// --- 3. DISSOLVE LOGIC ---
	// Calculate progress based on distance (0.0 = Near, 1.0 = Far)
	float dist = distance(world_pos, player_pos);
	float progress = smoothstep(love_vision_radius, love_vision_radius + 50.0, dist);
	
	// Read the noise pattern
	float noise_value = texture(noise_texture, UV).r;
	
	// Compare Noise vs Progress to create the dissolve cut
	// smoothstep here creates a tiny buffer so pixels don't flicker aggressively
	float dissolve_mask = smoothstep(progress - dissolve_smoothness, progress + dissolve_smoothness, noise_value);

	// --- 4. FINAL MIX ---
	// If dissolve_mask is 1.0 -> We are "Safe" (Show Sprite)
	// If dissolve_mask is 0.0 -> We are "Dissolved" (Show Outline)
	
	COLOR = mix(far_effect_color, original_color, dissolve_mask);
	
	// Transparency Fix: 
	// If we are showing the Outline (mask is low), we must respect the outline's alpha (holes between dots)
	if (dissolve_mask < 0.5) {
		COLOR.a = far_effect_color.a;
	}
}