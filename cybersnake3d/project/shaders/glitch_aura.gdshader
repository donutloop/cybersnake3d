// glitch_aura.gdshader — 2026 additive flame/distortion aura for the Tier-1 monster.
//
// Unshaded additive spatial shader. Radial falloff plus animated value noise
// gives a flickering, crackling hologram aura around the demon core.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 flame_color : source_color = vec4(1.0, 0.35, 0.10, 1.0);
uniform float intensity : hint_range(0.0, 8.0) = 2.0;
uniform float noise_scale : hint_range(0.5, 20.0) = 6.0;
uniform float speed : hint_range(0.0, 8.0) = 2.0;

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
	float t = TIME;
	vec2 pos = VERTEX.xy * noise_scale;

	// Animated noise field (time offsets the sample space).
	vec2 uv = vec2(pos.x, pos.y + t * speed * 1.5);
	vec2 uv2 = vec2(pos.x - t * speed, pos.y * 0.5);
	float n = noise2(uv);
	float n2 = noise2(uv2);
	float field = n * 0.7 + n2 * 0.3;

	// Radial falloff so the aura hugs the core and fades at the edge.
	float radius = length(VERTEX.xy);
	float edge = smoothstep(1.0, 0.1, radius);

	float flicker = 0.5 + 0.5 * sin(t * 20.0 + field * 30.0);
	float alpha = clamp(edge * (0.25 + field * 0.75) * flicker, 0.0, 1.0);

	ALBEDO = flame_color.rgb * intensity;
	ALPHA = alpha;
	EMISSION = vec3(0.0);
}
