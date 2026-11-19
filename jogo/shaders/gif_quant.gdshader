shader_type canvas_item;
// Reduz a tela para 128 cores (4 tons de vermelho x 8 de verde x 4 de azul) com pontilhado,
// e escreve o NÚMERO da cor no canal vermelho: o replay lê 1 byte por pixel e já vira GIF.

float bayer(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void fragment() {
	vec3 c = clamp(texture(TEXTURE, UV).rgb, 0.0, 1.0);
	float b = bayer(FRAGCOORD.xy);
	float r = clamp(floor(c.r * 3.0 + b), 0.0, 3.0);
	float g = clamp(floor(c.g * 7.0 + b), 0.0, 7.0);
	float bl = clamp(floor(c.b * 3.0 + b), 0.0, 3.0);
	float idx = r * 32.0 + g * 4.0 + bl;
	COLOR = vec4(idx / 255.0, 0.0, 0.0, 1.0);
}
