shader_type canvas_item;

uniform vec4 c1 : source_color = vec4(0.45, 0.25, 0.1, 1.0);
uniform vec4 c2 : source_color = vec4(0.2, 0.1, 0.04, 1.0);
uniform vec2 size = vec2(1104.0, 604.0);

// hash sem sin(): fica igual no celular
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 px = UV * size;
	vec2 q = px - size * 0.5;
	vec2 de = size * 0.5 - abs(q);
	// cada lado da moldura tem os veios no seu comprimento, com emenda em 45 graus nos cantos
	bool side = de.x < de.y;
	float along = side ? q.y : q.x;
	float across = side ? de.x : de.y;
	float seed = side ? (q.x < 0.0 ? 17.0 : 43.0) : (q.y < 0.0 ? 71.0 : 97.0);
	// veios da madeira: anéis compridos e ondulados + fibras finas + poros
	float w1 = vnoise(vec2(along * 0.007 + seed, across * 0.16));
	float w2 = vnoise(vec2(along * 0.022 + seed, across * 0.5 + 9.0));
	float rings = sin(across * 1.25 + w1 * 9.0 + w2 * 2.5) * 0.5 + 0.5;
	rings = smoothstep(0.1, 0.9, rings);
	float fib = vnoise(vec2(along * 0.06 + seed, across * 2.6));
	float pore = vnoise(vec2(along * 0.45 + seed, across * 3.4));
	float tone = vnoise(vec2(along * 0.0035 + seed, 0.5));
	float g = 0.56 * rings + 0.3 * fib + 0.14 * tone;
	vec3 col = mix(c2.rgb, c1.rgb, g);
	col = mix(col, c1.rgb * 1.22, smoothstep(0.55, 1.0, tone) * 0.22);
	col *= 0.93 + 0.07 * smoothstep(0.25, 0.6, pore);
	// perfil da moldura: borda de fora arredondada, verniz e friso de latão perto da tabela
	col *= mix(0.42, 1.0, smoothstep(0.0, 7.0, across));
	col += vec3(0.2, 0.14, 0.07) * smoothstep(3.0, 6.0, across) * smoothstep(10.0, 6.0, across) * 0.55;
	float gl = exp(-pow((across - 13.5) / 4.2, 2.0));
	col += vec3(0.3, 0.23, 0.14) * gl * (0.3 + 0.4 * vnoise(vec2(along * 0.012 + seed, 2.0)));
	float brass = smoothstep(1.4, 0.5, abs(across - 21.6));
	vec3 bc = vec3(0.86, 0.68, 0.32) * (0.72 + 0.5 * smoothstep(0.7, 0.0, abs(across - 21.2)));
	col = mix(col, bc, brass * 0.92);
	col *= mix(1.0, 0.5, smoothstep(23.0, 27.0, across));
	// emenda dos cantos
	float mit = abs(de.x - de.y);
	col *= 1.0 - 0.4 * smoothstep(1.3, 0.0, mit) * step(max(de.x, de.y), 60.0);
	// luz vindo de cima
	col *= 0.84 + 0.26 * (1.0 - UV.y);
	vec2 p = abs(q) - size * 0.5 + vec2(30.0);
	float dd = length(max(p, vec2(0.0))) - 30.0;
	COLOR = vec4(col, smoothstep(1.0, -1.0, dd));
}
