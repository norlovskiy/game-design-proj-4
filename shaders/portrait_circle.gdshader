shader_type canvas_item;

void fragment() {
	if (distance(UV, vec2(0.5)) > 0.49) {
		discard;
	}
}
