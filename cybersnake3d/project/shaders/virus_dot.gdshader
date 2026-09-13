// virus_dot.gdshader — 2026 green neon swarm dot for the wave-02 monster.
//
// Unshaded emissive spatial shader. A glowing hologram dot: animated value
// noise pulse + fresnel rim fringe. Output through ALBEDO (unshaded ignores
// EMISSION) so the dots are always visible.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 dot_color : source_color = vec4(0.10, 1.0, 0.40, 1.0);
uniform float emissive_power : hint_range(0.0, 8.0) = 3.0;
uniform float rim_power : hint_range(0.0, 6.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 12.0) = 4.0;
uniform float noise_scale : hint_range(0.5, 8.0) = 2.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	// Top-down rim fringe: edges of each dot catch the hologram rim glow.
	float rim = 1.0 - clamp(abs(n.y), 0.0, 1.0);
	rim = rim * rim;

	float t = TIME;
	vec2 uv = VERTEX.xy * noise_scale + vec2(t * 1.5, t * 1.2);
	float no = noise2(uv);

	float pulse = 0.6 + 0.4 * sin(t * pulse_speed + no * 6.0);
	vec3 col = dot_color.rgb * (pulse + rim * rim_power * (0.6 + no * 0.6));
	col *= emissive_power;

	// Unshaded spatial: the visible color is ALBEDO (EMISSION is ignored).
	ALBEDO = col;
	EMISSION = vec3(0.0);
	ALPHA = 1.0;
}
