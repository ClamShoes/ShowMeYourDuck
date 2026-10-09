shader_type canvas_item;

// Dissolve-burn for discarded cards. Value noise is computed here (no NoiseTexture) so it
// works in the Compatibility / web renderer.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.92, 0.45, 1.0);
uniform vec4 char_color : source_color = vec4(0.16, 0.08, 0.03, 1.0);
uniform float edge_width = 0.07;
uniform vec2 cells = vec2(5.0, 7.0);
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float n = vnoise(UV * cells) * 0.65 + vnoise(UV * cells * 2.7) * 0.35;
	// Flames start at the bottom edge and climb.
	n = n * 0.7 + (1.0 - UV.y) * 0.3;
	float p = progress * 1.25 - 0.12;
	if (n < p) {
		discard;
	}
	float edge = 1.0 - smoothstep(p, p + edge_width, n);
	float scorch = 1.0 - smoothstep(p + edge_width, p + edge_width * 3.5, n);
	vec3 col = mix(c.rgb, char_color.rgb, scorch * 0.85);
	col = mix(col, mix(edge_color.rgb, core_color.rgb, edge * edge), edge);
	COLOR = vec4(col, c.a * COLOR.a);
}
