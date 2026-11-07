shader_type canvas_item;

uniform vec4 c_light : source_color = vec4(0.12, 0.6, 0.3, 1.0);
uniform vec4 c_dark : source_color = vec4(0.03, 0.3, 0.16, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 accent2 : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int pat = 0;
uniform vec2 size = vec2(1012.0, 512.0);

// hash sem sin(): fica igual no celular (o sin com números grandes dá blocos em GPU de celular)
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash2(vec2 p) { return vec2(hash(p), hash(p + vec2(17.3, 91.7))); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = r * p * 2.03 + vec2(11.7, 3.1);
		a *= 0.5;
	}
	return s;
}
// estrela redonda e suave numa grade
float stars(vec2 px, float cell, float dens) {
	vec2 g = px / cell;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	if (h > dens) return 0.0;
	vec2 o = (hash2(id + 5.0) - 0.5) * 0.7;
	float r = length(f - o) * cell;
	float sz = 0.6 + 1.6 * hash(id + 9.0);
	return smoothstep(sz, 0.0, r) + smoothstep(sz * 4.0, 0.0, r) * 0.15;
}

void fragment() {
	vec2 px = UV * size;
	vec2 q = px - size * 0.5;
	float d = length((UV - 0.5) * vec2(1.0, 1.55));
	float light = smoothstep(0.95, 0.0, d);
	vec3 base = mix(c_dark.rgb, c_light.rgb, light);
	vec3 col = base;
	float edge = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	if (pat == 1) {
		// neon: grade fina e discreta que some no centro + contorno luminoso
		float cell = 64.0;
		vec2 gq = abs(fract(q / cell + 0.5) - 0.5) * cell;
		float m = min(gq.x, gq.y);
		float fade = 0.35 + 0.65 * smoothstep(0.15, 0.75, d);
		col += accent.rgb * smoothstep(1.2, 0.0, m) * 0.22 * fade;
		col += accent.rgb * smoothstep(1.4, 0.0, abs(edge - 14.0)) * 0.45;
		col += accent.rgb * smoothstep(40.0, 0.0, edge) * 0.10;
		col += accent.rgb * smoothstep(1.6, 0.0, abs(length(q) - 110.0)) * 0.22;
	} else if (pat == 2) {
		// galáxia: nebulosa suave + estrelas redondas
		float n = fbm(px * 0.0045 + vec2(3.0, 1.0));
		float n2 = fbm(px * 0.006 + vec2(31.0, 7.0) + n * 1.5);
		col = mix(col, accent.rgb * 0.55, smoothstep(0.45, 0.8, n) * 0.45);
		col = mix(col, accent2.rgb * 0.45, smoothstep(0.55, 0.85, n2) * 0.35);
		col += vec3(1.0) * stars(px, 22.0, 0.22) * 0.55;
		col += mix(vec3(1.0), accent2.rgb, 0.5) * stars(px + 7.0, 61.0, 0.35) * 0.8;
	} else if (pat == 3) {
		// Brasil: losango com borda fina, círculo azul com faixa
		vec2 r = abs(q) / vec2(400.0, 196.0);
		float s = r.x + r.y;
		col = mix(col, accent.rgb * 0.75, smoothstep(1.0, 0.99, s) * 0.32);
		col = mix(col, accent.rgb, smoothstep(0.012, 0.0, abs(s - 1.0)) * 0.55);
		float rr = length(q);
		float cc = smoothstep(96.0, 94.5, rr);
		col = mix(col, accent2.rgb * (0.75 + 0.25 * smoothstep(96.0, 0.0, rr)), cc * 0.75);
		float band = smoothstep(4.5, 3.0, abs(q.y - 18.0 + q.x * q.x * 0.0012)) * cc;
		col = mix(col, vec3(0.92), band * 0.7);
	} else if (pat == 4) {
		// camuflada: manchas orgânicas de borda suave e pouco contraste
		vec2 w = px * 0.007 + vec2(fbm(px * 0.004), fbm(px * 0.004 + 9.0)) * 1.2;
		float n1 = fbm(w);
		float n2 = fbm(w * 1.3 + vec2(40.0, 17.0));
		float n3 = fbm(w * 1.6 + vec2(9.0, 63.0));
		col = mix(col, accent.rgb * (0.75 + 0.35 * light), smoothstep(0.52, 0.56, n1) * 0.7);
		col = mix(col, accent2.rgb * (0.85 + 0.3 * light), smoothstep(0.55, 0.59, n2) * 0.75);
		col = mix(col, base * 0.7, smoothstep(0.6, 0.64, n3) * 0.6);
	} else if (pat == 5) {
		// inferno: pano escuro com brasa no centro e chamas suaves só nas bordas compridas
		float fy = min(px.y, size.y - px.y);
		float side = px.y < size.y * 0.5 ? 1.0 : -1.0;
		vec2 fp = vec2(px.x * 0.012, fy * 0.02 * side);
		float wv = fbm(fp + vec2(0.0, fbm(fp * 1.7) * 1.4));
		float h = 70.0 + 55.0 * wv;
		float fl = smoothstep(h, 0.0, fy);
		fl = pow(fl, 1.4);
		vec3 hot = mix(accent2.rgb, accent.rgb, smoothstep(0.35, 0.9, fl));
		hot = mix(hot, vec3(1.0, 0.92, 0.65), smoothstep(0.85, 1.0, fl) * 0.6);
		col = mix(col, hot, smoothstep(0.05, 0.6, fl) * 0.8);
		col += accent2.rgb * smoothstep(0.85, 0.0, d) * 0.08;
		float em = stars(px + vec2(0.0, 3.0), 34.0, 0.1) * smoothstep(170.0, 40.0, fy);
		col += accent.rgb * em * 0.7;
	} else if (pat == 6) {
		// gelo: cristais grandes e quase invisíveis + geada nas bordas
		vec2 g = px / 150.0;
		vec2 ig = floor(g);
		vec2 fg = fract(g);
		float d1 = 9.0;
		float d2 = 9.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 o = vec2(float(i), float(j));
				vec2 pnt = o + 0.15 + 0.7 * hash2(ig + o);
				float dd = length(pnt - fg);
				if (dd < d1) {
					d2 = d1;
					d1 = dd;
				} else if (dd < d2) {
					d2 = dd;
				}
			}
		}
		float crack = smoothstep(0.018, 0.0, d2 - d1);
		col = mix(col, accent.rgb, crack * 0.16);
		float frost = fbm(px * 0.02);
		float fr = smoothstep(90.0, 0.0, edge + (frost - 0.5) * 60.0);
		col = mix(col, accent.rgb, fr * 0.55);
		col += vec3(0.06) * (fbm(px * 0.008) - 0.5);
		col += accent2.rgb * stars(px, 40.0, 0.12) * 0.35 * (0.3 + fr);
	} else if (pat == 7) {
		// ouro real / campeão: treliça fina e medalhão
		float u = (q.x + q.y) / 72.0;
		float v = (q.x - q.y) / 72.0;
		float dl = min(abs(fract(u + 0.5) - 0.5), abs(fract(v + 0.5) - 0.5)) * 72.0;
		col += accent.rgb * smoothstep(1.0, 0.2, dl) * 0.16 * smoothstep(0.1, 0.6, d);
		float rr = length(q);
		col += accent.rgb * smoothstep(1.8, 0.4, abs(rr - 92.0)) * 0.6;
		col += accent.rgb * smoothstep(1.2, 0.3, abs(rr - 82.0)) * 0.35;
		col += accent.rgb * smoothstep(1.5, 0.3, abs(edge - 18.0)) * 0.45;
	} else if (pat == 8) {
		// pôr do sol: céu em degradê, sol baixo com halo e reflexo na água
		float hy = UV.y;
		vec3 sky = mix(accent.rgb, accent2.rgb, smoothstep(0.0, 0.62, hy));
		sky = mix(sky, c_dark.rgb, smoothstep(0.62, 1.0, hy));
		col = mix(col, sky, 0.78);
		vec2 sp = vec2(size.x * 0.5, size.y * 0.58);
		float sd = length(px - sp);
		col += vec3(1.0, 0.85, 0.5) * smoothstep(70.0, 62.0, sd) * 0.55 * step(px.y, sp.y + 2.0);
		col += accent.rgb * smoothstep(260.0, 0.0, sd) * 0.22;
		float rip = smoothstep(0.62, 0.66, hy) * (0.5 + 0.5 * sin(px.y * 0.9 + fbm(px * 0.03) * 6.0));
		col += vec3(1.0, 0.8, 0.45) * rip * smoothstep(110.0, 0.0, abs(px.x - sp.x)) * 0.25;
	} else if (pat == 9) {
		// oceano profundo: cáusticas suaves de luz na água
		vec2 w = px * 0.007;
		float c1 = fbm(w + vec2(fbm(w * 1.2 + 2.0), fbm(w * 1.2 + 7.0)) * 1.2);
		float c2 = abs(sin(c1 * 8.0));
		float caus = smoothstep(0.55, 1.0, 1.0 - c2) * 0.22;
		col = mix(col, accent2.rgb * 0.7, smoothstep(0.3, 0.8, c1) * 0.35);
		col += accent.rgb * caus * (0.35 + 0.65 * light);
		col += accent.rgb * stars(px, 46.0, 0.08) * 0.25;
	} else if (pat == 10) {
		// carbono: trama de fibra em sarja, fina e escura, com brilho no centro
		vec2 g = floor(px / 9.0);
		float tw = mod(g.x + g.y, 4.0) < 2.0 ? 1.0 : 0.0;
		vec2 f = fract(px / 9.0);
		float sh = tw > 0.5 ? smoothstep(0.0, 1.0, f.x) : smoothstep(0.0, 1.0, f.y);
		col *= 0.86 + 0.22 * sh;
		col += accent.rgb * smoothstep(0.9, 0.0, d) * 0.07;
		col += accent.rgb * smoothstep(1.4, 0.3, abs(edge - 16.0)) * 0.5;
	}
	// textura de pano: fina e suave (sem chiado)
	float mid = vnoise(px * 0.35) - 0.5;
	float coarse = fbm(px * 0.02) - 0.5;
	float weave = sin(px.x * 2.2) * sin(px.y * 2.2) * 0.008;
	col *= 1.0 + mid * 0.035 + coarse * 0.06 + weave;
	// sombra das tabelas
	col *= 0.82 + 0.18 * smoothstep(0.0, 26.0, edge);
	COLOR = vec4(col, 1.0);
}
