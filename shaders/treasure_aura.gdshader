shader_type canvas_item;
render_mode blend_add;

// A pulsing, slowly turning glow drawn on a square behind the treasure.

uniform vec4 glow_color : source_color = vec4(0.5, 0.82, 1.0, 1.0);
uniform float pulse_speed = 2.2;
uniform float strength = 1.6;
// Blocks across the square, so the glow keeps the game's pixel look.
uniform float pixels = 56.0;

void fragment() {
	vec2 p = (floor(UV * pixels) + 0.5) / pixels * 2.0 - 1.0;
	float falloff = clamp(1.0 - length(p), 0.0, 1.0);
	float pulse = 0.72 + 0.28 * sin(TIME * pulse_speed);
	float rays = 0.5 + 0.5 * sin(atan(p.y, p.x) * 8.0 + TIME * 0.9);
	float glow = falloff * pulse * mix(0.55, 1.0, rays) * strength;
	COLOR = vec4(glow_color.rgb, glow * glow_color.a);
}
