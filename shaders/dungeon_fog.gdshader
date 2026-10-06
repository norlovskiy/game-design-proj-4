shader_type canvas_item;
// Black over every map cell the player has not explored. The sheet spans the
// whole map, so UV addresses the one-pixel-per-cell mask directly. Red is how
// revealed a cell is. Green marks door cells that meet an explored piece: the
// dark room beyond is lit there and fades to black within glow_px of the door.
// Everything else is a hard edge.

uniform sampler2D explored : filter_nearest, repeat_disable;
// Pixels per map cell.
uniform float cell_px = 32.0;
// How far the gradient reaches from a lit door cell, in pixels.
uniform float glow_px = 16.0;

void fragment() {
	ivec2 size = textureSize(explored, 0);
	vec2 at = UV * vec2(size);
	ivec2 cell = clamp(ivec2(floor(at)), ivec2(0), size - 1);
	float lit = texelFetch(explored, cell, 0).r;
	if (lit < 1.0) {
		float nearest = glow_px;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				ivec2 other = cell + ivec2(x, y);
				if (other.x < 0 || other.y < 0 || other.x >= size.x || other.y >= size.y) {
					continue;
				}
				if (texelFetch(explored, other, 0).g < 0.5) {
					continue;
				}
				vec2 low = vec2(other);
				vec2 gap = max(max(low - at, at - (low + 1.0)), 0.0);
				nearest = min(nearest, length(gap) * cell_px);
			}
		}
		lit = max(lit, 1.0 - nearest / glow_px);
	}
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - lit);
}
