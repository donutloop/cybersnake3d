// glitch_drone.gdshader — 2026 neon-hologram core for the Tier-1 monster.
//
// Unshaded emissive spatial shader. Procedural glitch bands, animated value
// noise shimmer, top-down rim fringe, and scanline shimmer. Uses object-space
// VERTEX coordinates so it stays robust even on .obj meshes without UVs.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.05, 0.15, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.30, 0.10, 1.0);
uniform float emissive_power : hint_range(0.0, 16.0) = 4.0;
uniform float rim_power : hint_range(0.0, 8.0) = 2.0;
uniform float glitch_amount : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_freq : hint_range(1.0, 120.0) = 42.0;
uniform float noise_scale : hint_range(0.5, 12.0) = 3.5;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

// Smooth value noise (bilinear hash interpolation).
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
	// Top-down rim fringe: faces point up at the camera, so edges (low n.y)
	// catch the hologram rim glow.
	float rim = 1.0 - clamp(abs(n.y), 0.0, 1.0);
	rim = rim * rim * rim;

	float t = TIME;
	vec2 p = VERTEX.xy;

	// Horizontal glitch bands sliding down the face.
	float bands = step(0.5, fract(p.y * 6.0 + t * 4.0));

	// Animated value-noise shimmer (two layered fields).
	vec2 uv = p * noise_scale + vec2(t * 1.5, t * 2.0);
	float n1 = noise2(uv);
	vec2 uv2 = p * noise_scale * 0.5 + vec2(-t * 0.7, t * 1.1);
	float n2 = noise2(uv2);
	float shimmer = n1 * 0.6 + n2 * 0.4;

	float pulse = 0.55 + 0.45 * sin(t * 6.0 + n1 * 10.0);
	float scan = 0.5 + 0.5 * sin(p.y * scanline_freq * 3.14159);

	vec3 col = core_color.rgb * pulse * (1.0 + glitch_amount * 2.0);
	col += rim_color.rgb * rim * rim_power * (1.0 + shimmer) * scan;

	// Glitch displacement: copy a shifted, hotter color field over the core.
	vec3 shifted = core_color.rgb * pulse * (1.0 + glitch_amount * 3.0);
	col = mix(col, shifted, glitch_amount * 0.5);

	col *= emissive_power;

	// Unshaded spatial: the visible color is ALBEDO (EMISSION is ignored
	// without lighting), so output the hologram glow through ALBEDO.
	ALBEDO = col;
	EMISSION = vec3(0.0);
	ALPHA = 1.0;
}
