shader_type canvas_item;

uniform vec4 c1 : source_color = vec4(0.45, 0.25, 0.1, 1.0);
uniform vec4 c2 : source_color = vec4(0.2, 0.1, 0.04, 1.0);
uniform vec2 size = vec2(1104.0, 604.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 px = UV * size;
	float warp = vnoise(vec2(px.x * 0.006, px.y * 0.12)) * 7.0;
	float g = sin(px.y * 0.55 + warp + vnoise(px * vec2(0.01, 0.2)) * 5.0) * 0.5 + 0.5;
	float g2 = vnoise(vec2(px.x * 0.015, px.y * 0.8));
	vec3 col = mix(c2.rgb, c1.rgb, 0.5 * g + 0.5 * g2);
	float e = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	col *= mix(0.5, 1.0, smoothstep(0.0, 12.0, e));
	col += vec3(0.1, 0.07, 0.03) * smoothstep(5.0, 0.0, abs(e - 14.0));
	col *= 0.86 + 0.24 * (1.0 - UV.y);
	vec2 p = abs(px - size * 0.5) - size * 0.5 + vec2(30.0);
	float dd = length(max(p, vec2(0.0))) - 30.0;
	COLOR = vec4(col, smoothstep(1.0, -1.0, dd));
}
