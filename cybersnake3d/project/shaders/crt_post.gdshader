// crt_post.gdshader — Full-screen neon CRT post-process (3D)
//
// Applied to a fullscreen ColorRect in a CanvasLayer above the HUD.
// Samples the viewport backbuffer (which already includes the 3D world),
// then applies scanlines, chromatic aberration, and a vignette.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.25;
uniform float aberration_strength : hint_range(0.0, 0.1) = 0.02;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform float scanline_freq = 480.0;

void fragment() {
	vec2 uv = UV;
	vec2 dir = uv - vec2(0.5);

	// Chromatic aberration: sample R and B slightly offset from the center.
	vec3 col;
	col.r = texture(screen_texture, uv + dir * aberration_strength).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - dir * aberration_strength).b;

	// Scanlines along the vertical axis.
	float scan = sin(uv.y * scanline_freq * 3.14159);
	col *= 1.0 - scanline_strength * abs(scan);

	// Vignette.
	float v = length(dir);
	col *= 1.0 - vignette_strength * v * v;

	COLOR = vec4(col, 1.0);
}
