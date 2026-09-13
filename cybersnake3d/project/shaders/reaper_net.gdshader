// reaper_net.gdshader — 2026 neon wireframe net for the wave-03 Net Reaper.
//
// Unshaded emissive spatial shader. Draws a procedural lat-long neon wireframe
// net on a sphere (fragment math on NORMAL), plus a faint fresnel glow and a
// traveling pulse. Output through ALBEDO so it stays visible unshaded.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 net_color : source_color = vec4(0.0, 1.0, 0.8, 1.0);
uniform float emissive_power : hint_range(0.0, 8.0) = 3.0;
uniform float line_width : hint_range(0.0, 1.0) = 0.06;
uniform float pulse_speed : hint_range(0.0, 12.0) = 4.0;
uniform float grid_u : hint_range(1.0, 32.0) = 10.0;

void fragment() {
	float t = TIME;
	vec3 n = normalize(NORMAL);

	// Spherical coords of the normal -> lat-long wireframe net.
	float theta = acos(clamp(n.y, -1.0, 1.0));
	float phi = atan(n.z, n.x);
	float u = theta / PI * grid_u;
	float v = phi / TAU * grid_u;
	float uf = fract(u);
	float vf = fract(v);
	float line = min(uf, 1.0 - uf);
	float line2 = min(vf, 1.0 - vf);
	float grid = 1.0 - smoothstep(line_width * 0.5, line_width, line);
	grid += 1.0 - smoothstep(line_width * 0.5, line_width, line2);

	float pulse = 0.6 + 0.4 * sin(t * pulse_speed);
	vec3 col = net_color.rgb * (grid * pulse) * emissive_power;

	// Faint fresnel rim glow on the net surface.
	float rim = 1.0 - clamp(abs(n.y), 0.0, 1.0);
	col += net_color.rgb * rim * rim * pulse * 0.5;

	ALBEDO = col;
	EMISSION = vec3(0.0);
	ALPHA = 1.0;
}
