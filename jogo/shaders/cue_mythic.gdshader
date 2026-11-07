shader_type canvas_item;
// Tacos do mês: arte no taco inteiro, animada e com brilho em volta.
// theme: 0 fênix, 1 trovão, 2 samurai, 3 lobo da lua, 4 tsunami, 5 esmeralda, 6 vulcão, 7 aurora

uniform int theme = 0;
uniform float pad = 2.2;     // altura do retângulo / altura do corpo do taco (sobra = brilho)
uniform float ulen = 66.0;   // comprimento do taco / meia-altura, para os desenhos não ficarem esticados
uniform vec4 glow : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 shaft : source_color = vec4(0.95, 0.88, 0.7, 1.0);
uniform vec4 ring : source_color = vec4(0.95, 0.78, 0.3, 1.0);

float hash(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.6 + vnoise(p * 2.1 + 7.3) * 0.28 + vnoise(p * 4.3 + 3.1) * 0.12; }
float tri(float x) { return abs(fract(x) - 0.5) * 2.0; }
vec3 hue(float h) { return 0.5 + 0.5 * cos(6.2831 * (h + vec3(0.0, 0.33, 0.67))); }

float twinkle(vec2 p, float dens, float t) {
	vec2 c = floor(p);
	float h = hash2(c);
	if (h < 1.0 - dens) { return 0.0; }
	vec2 o = vec2(hash2(c + 3.1), hash2(c + 7.7)) * 0.6 + 0.2;
	vec2 d = abs(fract(p) - o);
	float s = 0.5 + 0.5 * sin(t * 3.0 + h * 40.0);
	float star = max(smoothstep(0.09, 0.0, d.x) * smoothstep(0.35, 0.0, d.y), smoothstep(0.09, 0.0, d.y) * smoothstep(0.35, 0.0, d.x));
	return star * s + smoothstep(0.18, 0.0, length(d)) * s;
}

// dígito de 7 segmentos (p em [-0.5,0.5]x[-0.8,0.8])
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
float digit(vec2 p, int d) {
	// segmentos: a topo, b dir-cima, c dir-baixo, d base, e esq-baixo, f esq-cima, g meio
	int m[10] = int[](63, 6, 91, 79, 102, 109, 125, 7, 127, 111);
	int k = m[d];
	float r = 9.0;
	vec2 qA = vec2(-0.32, 0.62);
	vec2 qB = vec2(0.32, 0.62);
	vec2 qC = vec2(0.32, 0.0);
	vec2 qD = vec2(0.32, -0.62);
	vec2 qE = vec2(-0.32, -0.62);
	vec2 qF = vec2(-0.32, 0.0);
	if ((k & 1) != 0) { r = min(r, seg(p, qA, qB)); }
	if ((k & 2) != 0) { r = min(r, seg(p, qB, qC)); }
	if ((k & 4) != 0) { r = min(r, seg(p, qC, qD)); }
	if ((k & 8) != 0) { r = min(r, seg(p, qD, qE)); }
	if ((k & 16) != 0) { r = min(r, seg(p, qE, qF)); }
	if ((k & 32) != 0) { r = min(r, seg(p, qF, qA)); }
	if ((k & 64) != 0) { r = min(r, seg(p, qF, qC)); }
	return r;
}
float symbol(vec2 p, int s) {
	if (s == 0) { return min(seg(p, vec2(-0.32, 0.0), vec2(0.32, 0.0)), seg(p, vec2(0.0, -0.32), vec2(0.0, 0.32))); }
	if (s == 1) { return min(seg(p, vec2(-0.28, -0.28), vec2(0.28, 0.28)), seg(p, vec2(-0.28, 0.28), vec2(0.28, -0.28))); }
	if (s == 2) { return min(seg(p, vec2(-0.32, 0.14), vec2(0.32, 0.14)), seg(p, vec2(-0.32, -0.14), vec2(0.32, -0.14))); }
	// pi
	return min(seg(p, vec2(-0.4, 0.5), vec2(0.4, 0.5)), min(seg(p, vec2(-0.18, 0.5), vec2(-0.24, -0.6)), seg(p, vec2(0.2, 0.5), vec2(0.22, -0.6))));
}

// escamas (penas / cobra): retorna x = borda, y = posição dentro da escama
vec2 scales(vec2 p) {
	vec2 q = vec2(p.x * 1.1, p.y * 1.5);
	float row = floor(q.y);
	q.x += mod(row, 2.0) * 0.5;
	vec2 f = fract(q) - vec2(0.5, 0.0);
	float r = length(f);
	return vec2(smoothstep(0.08, 0.0, abs(r - 0.55)), r);
}

// arte principal (antebraço do taco). e = brilho próprio (não escurece com a luz)
vec3 art(int th, vec2 P, float t, out float e) {
	vec3 c = vec3(0.0);
	e = 0.0;
	if (th == 0) {
		float n = fbm(vec2(P.x * 0.55 + t * 2.0, P.y * 1.4));
		float fl = smoothstep(0.3, 0.8, n + (1.0 - abs(P.y)) * 0.3);
		c = mix(vec3(0.32, 0.02, 0.01), vec3(1.0, 0.42, 0.04), fl);
		c = mix(c, vec3(1.0, 0.9, 0.5), smoothstep(0.72, 0.95, n));
		float fx = fract(P.x * 0.3 + abs(P.y) * 0.32);
		float edge = smoothstep(0.07, 0.0, abs(fx - 0.5));
		float vein = smoothstep(0.07, 0.0, abs(P.y)) * 0.8;
		c = mix(c, vec3(1.0, 0.82, 0.32), max(edge, vein));
		e = fl * 0.55 + edge * 0.7;
	} else if (th == 1) {
		float cl = fbm(vec2(P.x * 0.4 - t * 0.7, P.y * 1.3));
		c = mix(vec3(0.03, 0.03, 0.12), vec3(0.2, 0.18, 0.46), cl);
		float seed = floor(t * 5.0);
		float on = step(0.3, hash(seed * 1.7));
		for (int k = 0; k < 2; k++) {
			float fk = float(k);
			float path = (tri(P.x * 0.22 + hash(seed + fk * 9.0) * 3.0) - 0.5) * 1.3 + (vnoise(vec2(P.x * 1.6, seed + fk * 5.0)) - 0.5) * 0.45;
			float d = abs(P.y - path);
			c += vec3(0.85, 0.9, 1.0) * smoothstep(0.12, 0.0, d) * on + vec3(0.25, 0.35, 1.0) * smoothstep(0.55, 0.0, d) * on * 0.55;
			e += smoothstep(0.3, 0.0, d) * on;
		}
		float zz = abs(abs(P.y) - 0.82 - 0.09 * (tri(P.x * 0.6) - 0.5));
		float gold = smoothstep(0.06, 0.0, zz);
		c = mix(c, vec3(1.0, 0.85, 0.35), gold);
		e += gold * 0.4;
	} else if (th == 2) {
		c = mix(vec3(0.03, 0.015, 0.015), vec3(0.6, 0.02, 0.06), smoothstep(-0.25, 0.25, sin(P.x * 0.4) * 0.7 - P.y));
		float cell = floor(P.x / 2.6);
		vec2 lc = vec2(mod(P.x, 2.6) - 1.3, P.y - (hash(cell) - 0.5) * 0.5);
		float ang = t * 0.4 + cell;
		lc = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * lc;
		float r = length(lc);
		float a = atan(lc.y, lc.x);
		float pr = 0.75 * (0.5 + 0.5 * abs(cos(2.5 * a)));
		float m = smoothstep(pr, pr - 0.07, r);
		c = mix(c, mix(vec3(1.0, 0.86, 0.92), vec3(1.0, 0.45, 0.66), r / max(pr, 0.01)), m);
		c = mix(c, vec3(1.0, 0.85, 0.2), smoothstep(0.16, 0.1, r));
		float gl = smoothstep(0.05, 0.0, abs(abs(P.y) - 0.88));
		c = mix(c, vec3(1.0, 0.8, 0.3), gl);
		e = m * 0.25 + gl * 0.4;
	} else if (th == 3) {
		c = mix(vec3(0.02, 0.04, 0.13), vec3(0.1, 0.16, 0.4), 0.5 + 0.5 * P.y);
		c += vec3(0.85, 0.9, 1.0) * twinkle(P * vec2(1.4, 2.2), 0.35, t);
		vec2 mc = vec2(mod(P.x, 3.4) - 1.7, P.y);
		float moon = smoothstep(0.62, 0.56, length(mc)) * smoothstep(0.42, 0.5, length(mc - vec2(0.26, -0.16)));
		float halo = smoothstep(1.1, 0.5, length(mc)) * 0.35;
		c = mix(c, vec3(0.93, 0.95, 1.0), moon);
		c += vec3(0.4, 0.55, 1.0) * halo;
		float fil = smoothstep(0.06, 0.0, abs(P.y - 0.8 * sin(P.x * 0.95 + 1.0))) * (1.0 - smoothstep(0.5, 0.9, length(mc)) * 1.0);
		c = mix(c, vec3(0.8, 0.86, 0.98), fil * 0.8);
		e = moon * 0.7 + halo + fil * 0.3 + twinkle(P * vec2(1.4, 2.2), 0.35, t);
	} else if (th == 4) {
		float w = sin(P.x * 0.7 - t * 1.6 + sin(P.x * 0.27) * 2.0) * 0.55;
		float cr = P.y - w;
		c = mix(vec3(0.0, 0.1, 0.32), vec3(0.0, 0.62, 0.78), smoothstep(-1.2, 0.6, cr));
		c += vec3(0.85, 1.0, 1.0) * smoothstep(0.08, 0.0, abs(fract(cr * 2.5 - t * 0.6) - 0.5) - 0.38) * 0.35;
		vec2 sc = vec2(mod(P.x, 3.0) - 1.5, P.y);
		float r = length(sc);
		float a = atan(sc.y, sc.x);
		float sp = abs(fract(r * 2.6 - a / 6.2831 - t * 0.5) - 0.5);
		float curl = smoothstep(0.14, 0.04, sp) * smoothstep(0.92, 0.75, r);
		c = mix(c, vec3(0.92, 1.0, 1.0), curl);
		e = curl * 0.5;
	} else if (th == 5) {
		vec2 q = P * vec2(0.9, 1.5);
		vec2 ip = floor(q);
		float d1 = 9.0;
		float d2 = 9.0;
		float id = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 g = ip + vec2(float(i), float(j));
				vec2 o = g + vec2(hash2(g), hash2(g + 5.3)) * 0.8 + 0.1;
				float d = length(q - o);
				if (d < d1) { d2 = d1; d1 = d; id = hash2(g * 1.3); }
				else if (d < d2) { d2 = d; }
			}
		}
		float sh = 0.5 + 0.5 * sin(t * 2.2 + id * 6.2831);
		c = vec3(0.02, 0.42, 0.2) * (0.55 + 0.9 * sh) + vec3(0.1, 0.5, 0.3) * pow(sh, 6.0);
		float edge = smoothstep(0.09, 0.0, d2 - d1);
		c = mix(c, vec3(1.0, 0.83, 0.3), edge);
		c += vec3(1.0) * pow(sh, 18.0) * 0.8;
		e = edge * 0.5 + pow(sh, 8.0) * 0.6;
	} else if (th == 6) {
		c = vec3(0.05, 0.03, 0.03);
		float n = fbm(vec2(P.x * 0.7 + t * 0.25, P.y * 1.6));
		float crack = smoothstep(0.06, 0.0, abs(n - 0.5)) * (0.7 + 0.3 * sin(t * 3.0 + P.x));
		float flow = smoothstep(0.62, 0.85, fbm(vec2(P.x * 0.45 - t * 0.9, P.y * 0.9)));
		c += vec3(1.0, 0.32, 0.02) * crack * 1.6 + vec3(1.0, 0.62, 0.12) * flow;
		e = crack * 1.2 + flow;
	} else if (th == 8) {
		// lousa com números de pi e operações que deslizam
		c = mix(vec3(0.03, 0.12, 0.1), vec3(0.05, 0.2, 0.17), vnoise(P * vec2(1.5, 3.0)) * 0.6);
		float gx = smoothstep(0.05, 0.0, abs(fract(P.x * 1.0) - 0.5) - 0.45) + smoothstep(0.05, 0.0, abs(fract(P.y * 1.5) - 0.5) - 0.45);
		c += vec3(0.2, 0.5, 0.45) * gx * 0.12;
		float xx = P.x * 0.9 - t * 0.9;
		float cell = floor(xx);
		vec2 lp = vec2(fract(xx) - 0.5, P.y / 1.1) * vec2(1.25, 1.0);
		float pidig[20] = float[](3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0, 5.0, 3.0, 5.0, 8.0, 9.0, 7.0, 9.0, 3.0, 2.0, 3.0, 8.0, 4.0);
		int idx = int(mod(cell, 20.0));
		float hs = hash(cell * 1.7);
		float dd;
		if (hs > 0.78) {
			dd = symbol(lp * 1.15, int(mod(cell, 4.0)));
		} else {
			dd = digit(lp, int(pidig[idx]));
		}
		float ink = smoothstep(0.11, 0.05, dd);
		float halo = smoothstep(0.35, 0.0, dd);
		vec3 ic = hs > 0.78 ? vec3(1.0, 0.85, 0.3) : (mod(cell, 3.0) == 0.0 ? vec3(0.4, 1.0, 1.0) : vec3(0.95, 0.98, 1.0));
		c = mix(c, ic, ink);
		c += ic * halo * 0.25;
		e = ink * 0.8 + halo * 0.3;
	} else {
		c = vec3(0.01, 0.02, 0.07);
		vec3 cc[3] = vec3[](vec3(0.15, 1.0, 0.6), vec3(0.2, 0.75, 1.0), vec3(0.75, 0.35, 1.0));
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float yk = sin(P.x * 0.3 + t * 0.9 + fk * 2.1) * 0.55 + sin(P.x * 0.11 - t * 0.4 + fk) * 0.25;
			float band = exp(-pow((P.y - yk) * 3.2, 2.0));
			c += cc[k] * band * 0.95;
			e += band * 0.6;
		}
		c += vec3(1.0) * twinkle(P * vec2(1.6, 2.4), 0.3, t) * 0.8;
	}
	return c;
}

// empunhadura (onde a mão segura)
vec3 grip(int th, vec2 P, float t, out float e) {
	e = 0.0;
	vec3 c;
	if (th == 0 || th == 3) {
		vec2 s = scales(P);
		vec3 a = th == 0 ? vec3(0.55, 0.05, 0.02) : vec3(0.06, 0.1, 0.25);
		vec3 b = th == 0 ? vec3(1.0, 0.5, 0.08) : vec3(0.55, 0.65, 0.9);
		vec3 ed = th == 0 ? vec3(1.0, 0.82, 0.3) : vec3(0.85, 0.9, 1.0);
		c = mix(b, a, smoothstep(0.0, 0.6, s.y));
		c = mix(c, ed, s.x);
		e = s.x * 0.35;
	} else if (th == 1) {
		float dd = abs(fract(P.x * 0.45 + P.y * 0.5) - 0.5) + abs(fract(P.x * 0.45 - P.y * 0.5) - 0.5);
		c = vec3(0.05, 0.05, 0.16) * (0.8 + 0.5 * smoothstep(0.3, 0.6, dd));
		float st = smoothstep(0.07, 0.0, abs(P.y - (tri(P.x * 0.7) - 0.5) * 0.6));
		c = mix(c, vec3(1.0, 0.85, 0.35), st);
		e = st * 0.5;
	} else if (th == 2) {
		float dd = abs(fract(P.x * 0.38 + P.y * 0.5) - 0.5) + abs(fract(P.x * 0.38 - P.y * 0.5) - 0.5);
		float silk = smoothstep(0.26, 0.32, dd);
		vec3 skin = vec3(0.92, 0.9, 0.84) * (0.85 + 0.15 * hash2(floor(P * 6.0)));
		c = mix(skin, vec3(0.62, 0.03, 0.07) * (0.8 + 0.4 * tri(P.x * 0.38 + P.y * 0.5)), silk);
	} else if (th == 4) {
		float rope = fract(P.x * 0.6 + P.y * 0.45 - t * 0.3);
		c = mix(vec3(0.0, 0.35, 0.55), vec3(0.6, 0.95, 1.0), smoothstep(0.1, 0.5, rope) * smoothstep(0.95, 0.6, rope));
		e = 0.1;
	} else if (th == 5) {
		float dd = abs(fract(P.x * 0.5 + P.y * 0.5) - 0.5) + abs(fract(P.x * 0.5 - P.y * 0.5) - 0.5);
		c = vec3(0.02, 0.32, 0.16) * (0.7 + 0.6 * dd);
		float gl = smoothstep(0.08, 0.0, abs(dd - 0.5));
		c = mix(c, vec3(1.0, 0.82, 0.3), gl);
		float gem = smoothstep(0.16, 0.08, dd) * (0.6 + 0.4 * sin(t * 3.0 + P.x));
		c = mix(c, vec3(0.6, 1.0, 0.8), gem);
		e = gl * 0.3 + gem * 0.6;
	} else if (th == 6) {
		float n = fbm(vec2(P.x * 0.9, P.y * 1.8));
		c = vec3(0.07, 0.04, 0.035) + vec3(1.0, 0.35, 0.03) * smoothstep(0.05, 0.0, abs(n - 0.5)) * (0.8 + 0.4 * sin(t * 4.0 + P.x * 0.5));
		e = smoothstep(0.05, 0.0, abs(n - 0.5));
	} else if (th == 8) {
		vec2 g = abs(fract(P * vec2(1.6, 2.2)) - 0.5);
		float ln = smoothstep(0.06, 0.0, min(g.x, g.y) - 0.0);
		vec2 g2 = abs(fract(P * vec2(0.4, 0.55)) - 0.5);
		float ln2 = smoothstep(0.03, 0.0, min(g2.x, g2.y));
		c = vec3(0.93, 0.95, 1.0) * 0.9;
		c = mix(c, vec3(0.3, 0.55, 0.95), ln * 0.45 + ln2 * 0.6);
		float wave = smoothstep(0.08, 0.0, abs(P.y - 0.6 * sin(P.x * 0.9 - t * 1.5)));
		c = mix(c, vec3(0.95, 0.25, 0.35), wave);
		e = wave * 0.4;
	} else {
		float h = fract(P.x * 0.04 + P.y * 0.25 + t * 0.12);
		c = mix(vec3(0.9, 0.92, 1.0), hue(h), 0.55) * (0.75 + 0.25 * tri(P.x * 0.5 + P.y * 0.3));
		e = 0.25;
	}
	return c;
}

void fragment() {
	float t = TIME;
	float u = UV.x;
	float yy = (UV.y - 0.5) * 2.0 * pad;
	float h = u < 0.52 ? mix(0.40, 0.62, u / 0.52) : mix(0.62, 1.0, (u - 0.52) / 0.48);
	float ny = clamp(yy / h, -1.0, 1.0);
	float body = smoothstep(1.0, 0.9, abs(yy) / h);
	float nz = sqrt(max(1.0 - ny * ny, 0.0));
	vec2 P = vec2(u * ulen, ny);
	vec3 col;
	float e = 0.0;
	float metal = 0.0;
	if (u < 0.012) {
		col = vec3(0.28, 0.58, 0.86);
	} else if (u < 0.038) {
		col = vec3(0.97, 0.96, 0.93);
	} else if (u < 0.52) {
		float g = hash(floor(ny * 9.0 + 20.0));
		col = shaft.rgb * (0.94 + 0.06 * g);
		// espiral de energia subindo pela haste
		float fade = smoothstep(0.08, 0.5, u);
		float hel = smoothstep(0.1, 0.0, abs(fract(P.x * 0.12 + asin(ny) * 0.16 - t * 0.35) - 0.5) - 0.4) * fade;
		col = mix(col, glow.rgb, hel * 0.75);
		e += hel * 0.6;
		// a arte do antebraço invade a haste e vai sumindo em direção à ponta
		float am = smoothstep(0.30, 0.50, u);
		float ea;
		vec3 ac = art(theme, P, t, ea);
		col = mix(col, ac, am * 0.92);
		e += ea * am;
	} else if (u < 0.536 || (u >= 0.70 && u < 0.716) || (u >= 0.93 && u < 0.946)) {
		col = ring.rgb;
		metal = 1.0;
		float gl = smoothstep(0.12, 0.0, abs(fract(ny * 0.4 + u * 9.0 - t * 0.8) - 0.5) - 0.38);
		col += vec3(1.0) * gl * 0.6;
	} else if (u < 0.70) {
		col = art(theme, P, t, e);
	} else if (u < 0.93) {
		col = grip(theme, P, t, e);
	} else if (u < 0.984) {
		col = art(theme, P + vec2(5.0, 0.0), t, e);
		float gem = smoothstep(0.5, 0.35, length(vec2((u - 0.965) * ulen, ny)));
		col = mix(col, glow.rgb * 1.3, gem);
		e += gem;
	} else {
		col = vec3(0.04);
		e = 0.2;
	}
	// pulso de luz que percorre o taco inteiro
	float pulse = smoothstep(0.035, 0.0, abs(u - (fract(t * 0.32) * 1.3 - 0.15)));
	float diff = 0.45 + 0.55 * nz;
	float spec = pow(clamp(1.0 - abs(ny + 0.36) * 2.4, 0.0, 1.0), 3.0) * (0.45 + 0.4 * metal);
	float spec2 = pow(clamp(1.0 - abs(ny - 0.5) * 3.5, 0.0, 1.0), 4.0) * 0.12;
	vec3 lit = col * diff * mix(0.55, 1.0, nz) + vec3(spec + spec2);
	lit = mix(lit, col, clamp(e, 0.0, 1.0) * 0.6) + glow.rgb * pulse * 0.6;
	// aura em volta do taco
	float d = max(abs(yy) - h, 0.0);
	float gp = 0.75 + 0.25 * sin(t * 3.0 + u * 18.0);
	float aura = exp(-d * 2.6) * gp * smoothstep(0.25, 0.6, u) * 0.6;
	aura += exp(-d * 4.0) * pulse * 0.6;
	float sp = twinkle(vec2(u * ulen * 0.9, yy * 2.2), 0.08, t) * smoothstep(0.3, 0.6, u) * step(h, abs(yy));
	vec3 acol = glow.rgb + vec3(sp);
	float aa = clamp(aura + sp, 0.0, 1.0) * (1.0 - body);
	COLOR = vec4(mix(acol, lit, body), max(body, aa));
}
