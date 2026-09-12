shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 bg_color : source_color = vec4(0.02, 0.02, 0.05, 1.0);
uniform vec4 line_color : source_color = vec4(0.0, 0.7, 1.0, 0.12);
uniform float grid_size : hint_range(0.5, 4.0) = 1.0;
uniform float line_width : hint_range(0.005, 0.1) = 0.02;
uniform float scroll_speed : hint_range(0.0, 5.0) = 0.3;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.3;
uniform float grid_cells = 40.0;

void fragment() {
	vec2 world_uv = UV * grid_cells;
	world_uv.y += TIME * scroll_speed;

	vec2 grid = abs(fract(world_uv / grid_size) - 0.5);
	float d = min(grid.x, grid.y);
	float line = 1.0 - smoothstep(0.0, line_width, d);

	float pulse = 1.0 + pulse_amount * sin(TIME * pulse_speed);
	vec3 glow = line_color.rgb * line * pulse;

	ALBEDO = bg_color.rgb + glow;
	EMISSION = glow * 2.0;
}
