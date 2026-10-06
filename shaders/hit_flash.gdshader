shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;
// A thin outline in the sprite's own pixels, so enemies stand out against
// dark rooms. Drawn on transparent pixels that touch the sprite.
uniform vec4 outline_color : source_color = vec4(0.9, 0.1, 0.1, 1.0);
uniform float outline_width = 1.0;

void fragment() {
	float edge = 0.0;
	if (COLOR.a < 0.5) {
		vec2 step = TEXTURE_PIXEL_SIZE * outline_width;
		edge = max(
			max(texture(TEXTURE, UV + vec2(step.x, 0.0)).a, texture(TEXTURE, UV - vec2(step.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, step.y)).a, texture(TEXTURE, UV - vec2(0.0, step.y)).a));
	}
	COLOR.rgb = mix(COLOR.rgb, vec3(0.58, 0.84, 1.0), frost_amount);
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash_amount);
	if (edge > 0.5) {
		COLOR = vec4(outline_color.rgb, outline_color.a * edge);
	}
}
