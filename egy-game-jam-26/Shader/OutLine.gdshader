void fragment() {
	vec4 sprite_color = texture(TEXTURE, UV);
	float alpha = sprite_color.a;
	
	// Set width based on texture size
	vec2 size = TEXTURE_PIXEL_SIZE * width;
	
	// Check neighbors (standard edge detection)
	float n = texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
	float s = texture(TEXTURE, UV + vec2(0.0, size.y)).a;
	float e = texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
	float w = texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
	
	// --- FIX: Check if we are touching the literal edge of the image file ---
	// If UV is 0.0 or 1.0, we are at the edge. We check if we are within 'width' distance of the edge.
	bool border_l = UV.x < size.x;
	bool border_r = UV.x > 1.0 - size.x;
	bool border_t = UV.y < size.y;
	bool border_b = UV.y > 1.0 - size.y;
	bool on_texture_border = border_l || border_r || border_t || border_b;

	// --- INSET LOGIC ---
	// Instead of looking for transparent neighbors, we look for:
	// "I am solid (alpha=1), but my neighbor is transparent OR I am at the texture border"
	float neighbor_sum = n + s + e + w;
	
	// If I have 4 solid neighbors, sum is 4.0. If 4.0, I am NOT an edge.
	// If I have < 4.0, I am next to transparency, so I AM an edge.
	// We also force edge if on_texture_border is true.
	float is_edge = 0.0;
	
	if (alpha > 0.0) {
		// If neighbors are missing (< 4) OR we hit the file wall
		if (neighbor_sum < 4.0 || on_texture_border) {
			is_edge = 1.0;
		}
	}
	
	// --- DOT PATTERN ---
	// Same as before
	float dot_x = step(dot_spacing, mod(world_pos.x, dot_size) / dot_size);
	float dot_y = step(dot_spacing, mod(world_pos.y, dot_size) / dot_size);
	float is_dot = dot_x * dot_y;

	vec4 final_outline = outline_color;
	final_outline.a = is_edge * is_dot; // Only show outline on edges

	// --- DISTANCE MIX ---
	float dist = distance(world_pos, player_pos);
	float mask = smoothstep(vision_radius, vision_radius + 50.0, dist);
	
	// Mix Logic:
	// If mask=0 (Close): Show normal sprite
	// If mask=1 (Far): Show ONLY the outline (turn the inside transparent)
	
	vec4 result_color;
	if (mask < 0.5) {
		// Near: Draw sprite normally
		result_color = sprite_color; 
	} else {
		// Far: Draw only the dotted outline
		result_color = final_outline;
	}
	
	// Smooth Blend
	COLOR = mix(sprite_color, final_outline, mask);
	
	// Final clean up: If we are far and not on an outline, make it fully transparent
	if (mask > 0.9 && final_outline.a == 0.0) {
		COLOR.a = 0.0;
	}
}