shader_type canvas_item;

// Uniforms updated by GDScript
uniform vec2 player_screen_pos;
uniform float radius;
uniform float surface_y_screen;

void fragment() {
	// 1. Calculate distance from current pixel (screen space) to player (screen space)
	float dist = distance(FRAGCOORD.xy, player_screen_pos);
	
	// Default to Solid Black (Alpha 1.0)
	float alpha = 1.0;
	
	// 2. Surface Check:
	// If the current pixel's Y is "higher" (numerically smaller) than the surface threshold,
	// we are in the sky. Make it transparent.
	if (FRAGCOORD.y < surface_y_screen) {
		alpha = 0.0;
	} 
	else {
		// 3. Zone Checks (Hard Edges)
		if (dist < radius) {
			// Inner circle: Fully visible
			alpha = 0.0;
		} else if (dist < radius + 10.0) {
			// Padding ring: 50% opacity
			alpha = 0.5;
		}
		// Else remains 1.0 (Darkness)
	}
	
	// FIX: Multiply by COLOR.a so the script's 'modulate.a' affects the transparency
	COLOR = vec4(0.0, 0.0, 0.0, alpha * COLOR.a);
}