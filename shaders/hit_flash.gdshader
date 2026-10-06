shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(0.58, 0.84, 1.0), frost_amount);
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash_amount);
}
