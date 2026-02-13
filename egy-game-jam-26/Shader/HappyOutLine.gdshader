shader_type canvas_item;

// --- GLOBAL UNIFORMS ---
global uniform vec2 player_pos;
global uniform float happy_vision_radius;

// --- SETTINGS ---
uniform vec4 color : source_color = vec4(1.0);
uniform float inner_stroke_thickness : hint_range(1.0, 10.0) = 3.0; 
uniform float inner_stroke_opacity : hint_range(0.0, 1.0) = 1.0; 
uniform float frequency : hint_range(0.0, 50.0) = 20.0; 
uniform float phase_speed : hint_range(0.0, 10.0) = 6.0; 

// --- DISSOLVE SETTINGS ---
uniform sampler2D noise_texture : repeat_enable; 
uniform float dissolve_smoothness : hint_range(0.0, 0.1) = 0.05; 

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	float original_alpha = original_color.a;

	// --- 1. EDGE DETECTION (FIXED) ---
	// We loop through neighbor pixels one by one to avoid skipping spots
	float min_neighbor_alpha = 1.0;
	
	// Convert thickness to an integer loop count
	int steps = int(max(1.0, inner_stroke_thickness)); 
	
	for (int x = -steps; x <= steps; x++) {
		for (int y = -steps; y <= steps; y++) {
			// Optimization: Skip the center pixel itself
			if (x == 0 && y == 0) continue;
			
			vec2 offset = vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE;
			vec2 sample_uv = UV + offset;
			
			float sample_alpha;
			// Bounds check to ensure we don't sample garbage outside the sprite rect
			if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
				sample_alpha = 0.0; 
			} else {
				sample_alpha = texture(TEXTURE, sample_uv).a;
			}
			min_neighbor_alpha = min(min_neighbor_alpha, sample_alpha);
		}
	}
	
	float is_edge = clamp(original_alpha - min_neighbor_alpha, 0.0, 1.0);

	// --- 2. ROTATING DOTS (FIXED) ---
	vec2 center_offset = UV - vec2(0.5);
	
	// FIX: Safe atan calculation to prevent the center pixel "black hole"
	float angle = 0.0;
	if (length(center_offset) > 0.0001) {
		angle = atan(center_offset.y, center_offset.x);
	}
	
	if (angle < 0.0) { angle += 2.0 * PI; }
	
	// FIX: Round frequency to nearest whole number to prevent seam "cut" in the circle
	float clean_freq = round(frequency);
	
	float wave = 0.5 * sin(clean_freq * angle + TIME * phase_speed) + 0.5;
	float dotted_pattern = step(0.5, wave);

	// The "Far" look: Only the dotted outline
	vec4 far_effect_color = color;
	far_effect_color.a = is_edge * dotted_pattern * inner_stroke_opacity;

	// --- 3. DISSOLVE LOGIC ---
	float dist = distance(world_pos, player_pos);
	float progress = smoothstep(happy_vision_radius, happy_vision_radius + 50.0, dist);
	
	float noise_value = texture(noise_texture, UV).r;
	float dissolve_mask = smoothstep(progress - dissolve_smoothness, progress + dissolve_smoothness, noise_value);

	// --- 4. FINAL MIX ---
	COLOR = mix(far_effect_color, original_color, dissolve_mask);
	
	// Transparency Logic
	// If the dissolve mask is fully "Far" (0.0), we force the alpha to match our dotted pattern
	if (dissolve_mask < 0.1) {
		COLOR.a = far_effect_color.a;
	} else {
		// Smooth blend for the transition area
		COLOR.a = mix(far_effect_color.a, original_alpha, dissolve_mask);
	}
}