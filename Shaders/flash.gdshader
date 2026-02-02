shader_type canvas_item;
render_mode blend_add; // Key change: Additive blending adds light rather than replacing pixels

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
vec4 tex_color = texture(TEXTURE, UV);

// Multiply the texture color by the flash intensity.
// We use the texture's rgb so dark spots (cracks) stay dark and don't glow white.
// This prevents the "solid white silhouette" look.
vec3 light_add = tex_color.rgb * flash_color.rgb * flash_intensity;

COLOR = vec4(light_add, tex_color.a);
}