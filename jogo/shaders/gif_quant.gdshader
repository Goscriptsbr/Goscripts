shader_type canvas_item;
// Reduz a tela para as 128 cores da paleta (escolhidas da própria tela) com um pontilhado bem leve,
// e escreve o NÚMERO da cor no canal vermelho: o replay lê 1 byte por pixel e já vira GIF.
uniform vec3 pal[128];

float bayer(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[q.y * 4 + q.x]) + 0.5) / 16.0;
}

void fragment() {
	vec3 c = clamp(texture(TEXTURE, UV).rgb, 0.0, 1.0);
	c += (bayer(FRAGCOORD.xy) - 0.5) * 0.045;
	float best = 1e9;
	int bi = 0;
	for (int i = 0; i < 128; i++) {
		vec3 d = (c - pal[i]) * vec3(0.9, 1.2, 0.7);
		float e = dot(d, d);
		if (e < best) { best = e; bi = i; }
	}
	COLOR = vec4(float(bi) / 255.0, 0.0, 0.0, 1.0);
}
