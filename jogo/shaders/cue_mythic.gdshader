shader_type canvas_item;
// Tacos do mês: arte no taco inteiro, animada e com brilho em volta.
// theme: 11 neon, 12 jade, 13 supernova, 14 rosa negra, 15 anjo, 16 buraco negro, 17 zeus, 18 infinito (tacos ELITE)
// theme: 0 fênix, 1 trovão, 2 samurai, 3 lobo da lua, 4 tsunami, 5 esmeralda, 6 vulcão, 7 aurora, 8 pedro, 9 cometa, 10 imperador

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

// ---------- tacos ELITE ----------
float lemni(vec2 q, float a) {
	// distância aproximada até o símbolo do infinito (lemniscata)
	float v = dot(q, q) * dot(q, q) - a * a * (q.x * q.x - q.y * q.y);
	return abs(v) / (a * a * 2.2 * max(length(q), 0.2));
}

vec3 art2(int th, vec2 P, float t, out float e) {
	vec3 c = vec3(0.0);
	e = 0.0;
	if (th == 11) {
		// NEON CYBER: grade retrô andando, linha de varredura e falhas de tela
		c = mix(vec3(0.05, 0.0, 0.12), vec3(0.2, 0.0, 0.3), 0.5 + 0.5 * P.y);
		float gx = smoothstep(0.07, 0.0, abs(fract(P.x * 0.7 - t * 0.9) - 0.5) - 0.43);
		float gy = smoothstep(0.06, 0.0, abs(fract(P.y * 2.0 + 0.5) - 0.5) - 0.44);
		c += vec3(1.0, 0.2, 0.85) * gx * 0.9 + vec3(0.2, 0.9, 1.0) * gy * 0.55;
		vec2 sc = vec2(mod(P.x, 5.0) - 2.5, P.y + 0.15);
		float sun = smoothstep(0.75, 0.7, length(sc * vec2(0.9, 1.0))) * step(0.0, sin(P.y * 18.0 + t * 2.0) + 0.3 + P.y);
		c = mix(c, mix(vec3(1.0, 0.85, 0.2), vec3(1.0, 0.2, 0.6), 0.5 - P.y * 0.6), sun);
		float scan = smoothstep(0.08, 0.0, abs(fract(P.x * 0.05 - t * 0.35) - 0.5) - 0.46);
		float gseed = floor(t * 7.0);
		float gb = step(0.9, hash(floor(P.x * 1.3) + gseed * 3.1)) * step(abs(P.y - (hash(gseed + floor(P.x)) * 1.6 - 0.8)), 0.15);
		c = mix(c, vec3(0.3, 1.0, 1.0), gb * 0.8);
		c += vec3(1.0) * scan * 0.5;
		e = gx * 0.8 + gy * 0.4 + sun * 0.5 + gb * 0.5 + scan * 0.5;
	} else if (th == 12) {
		// SERPENTE DE JADE: mármore de jade com escamas e uma serpente dourada ondulando
		float n = fbm(P * vec2(0.5, 1.6) + vec2(0.0, t * 0.05));
		c = mix(vec3(0.01, 0.22, 0.13), vec3(0.25, 0.7, 0.45), n);
		c += vec3(0.5, 1.0, 0.75) * smoothstep(0.05, 0.0, abs(fbm(P * vec2(0.9, 2.4)) - 0.55)) * 0.35;
		vec2 sc2 = scales(P * 1.4);
		c = mix(c, vec3(0.55, 1.0, 0.75), sc2.x * 0.35);
		float y = 0.5 * sin(P.x * 0.65 - t * 1.4);
		float d = abs(P.y - y);
		float body = smoothstep(0.32, 0.24, d);
		float belly = fract(P.x * 1.6 - t * 0.89);
		vec3 sk = mix(vec3(0.75, 0.52, 0.08), vec3(1.0, 0.9, 0.45), smoothstep(0.24, 0.0, d));
		sk = mix(sk, vec3(0.1, 0.25, 0.08), smoothstep(0.1, 0.0, abs(belly - 0.5) - 0.3) * smoothstep(0.1, 0.18, d) * 0.7);
		c = mix(c, sk, body);
		float shine = smoothstep(0.06, 0.0, abs(P.y - y + 0.12)) * body;
		c += vec3(1.0, 0.95, 0.7) * shine * 0.6;
		e = body * 0.3 + shine * 0.6 + sc2.x * 0.15;
	} else if (th == 13) {
		// SUPERNOVA: núcleos explodindo, raios, ondas de choque e nuvens de gás
		c = mix(vec3(0.04, 0.0, 0.1), vec3(0.5, 0.08, 0.45), fbm(P * vec2(0.45, 1.3) + vec2(t * 0.15, 0.0)));
		c += vec3(1.0, 0.45, 0.1) * smoothstep(0.55, 0.9, fbm(P * vec2(0.7, 1.8) - vec2(t * 0.25, 0.0))) * 0.7;
		float cell = floor(P.x / 4.2);
		vec2 lc = vec2(mod(P.x, 4.2) - 2.1, P.y);
		float r = length(lc);
		float pulse = 0.75 + 0.35 * sin(t * 4.0 + cell * 2.0);
		float core = exp(-r * r * 7.0) * pulse;
		float a = atan(lc.y, lc.x);
		float rays = pow(abs(cos(a * 5.0 + t * 0.8 + cell)), 24.0) * exp(-r * 1.1) * pulse;
		float wave = smoothstep(0.08, 0.0, abs(r - fract(t * 0.45 + hash(cell)) * 2.4)) * (1.0 - fract(t * 0.45 + hash(cell)));
		c += vec3(1.0, 0.97, 0.85) * core * 1.8 + vec3(1.0, 0.7, 0.3) * rays * 1.2 + vec3(1.0, 0.6, 0.9) * wave;
		c += vec3(1.0) * twinkle(P * vec2(1.8, 2.6), 0.25, t) * 0.7;
		e = core * 1.4 + rays + wave + fbm(P) * 0.2;
	} else if (th == 14) {
		// ROSA NEGRA: veludo preto, rosas vermelhas girando devagar e ramos com espinhos
		c = mix(vec3(0.02, 0.0, 0.01), vec3(0.12, 0.01, 0.03), fbm(P * vec2(0.6, 1.8)));
		float vine = smoothstep(0.07, 0.0, abs(P.y - 0.62 * sin(P.x * 0.5 + 0.8)));
		float thorn = smoothstep(0.12, 0.0, abs(fract(P.x * 0.8) - 0.5) - 0.1) * smoothstep(0.2, 0.05, abs(P.y - 0.62 * sin(P.x * 0.5 + 0.8)));
		c = mix(c, vec3(0.05, 0.2, 0.06), max(vine, thorn * 0.6));
		float cell = floor(P.x / 2.8);
		vec2 lc = vec2(mod(P.x, 2.8) - 1.4, P.y - (hash(cell) - 0.5) * 0.4);
		float r = length(lc);
		float a = atan(lc.y, lc.x) + t * 0.3 + cell;
		float pet = 0.5 + 0.5 * sin(a * 3.0 + r * 16.0);
		float rose = smoothstep(0.72, 0.66, r);
		vec3 rc = mix(vec3(0.35, 0.0, 0.03), vec3(0.95, 0.08, 0.15), pet * (1.0 - r));
		rc += vec3(1.0, 0.4, 0.45) * pow(pet, 6.0) * (1.0 - r) * 0.4;
		c = mix(c, rc, rose);
		float dew = smoothstep(0.07, 0.0, length(lc - vec2(0.25, -0.3))) * rose;
		c += vec3(1.0) * dew * (0.6 + 0.4 * sin(t * 3.0 + cell));
		float gl = smoothstep(0.05, 0.0, abs(abs(P.y) - 0.88));
		c = mix(c, vec3(0.85, 0.65, 0.3), gl);
		e = rose * pet * 0.35 + dew + gl * 0.3;
	} else if (th == 15) {
		// ANJO CELESTIAL: nuvens brancas, penas, auréolas douradas e raios de luz
		c = mix(vec3(0.78, 0.82, 0.92), vec3(1.0, 0.99, 0.95), fbm(P * vec2(0.35, 1.2) + vec2(t * 0.12, 0.0)));
		vec2 sc2 = scales(P * vec2(1.1, 1.0));
		c = mix(c, vec3(1.0, 0.95, 0.8), sc2.x * 0.5);
		vec2 lc = vec2(mod(P.x, 3.6) - 1.8, P.y);
		float halo = smoothstep(0.08, 0.0, abs(length(lc * vec2(1.0, 2.2)) - 0.62));
		c = mix(c, vec3(1.0, 0.8, 0.25), halo);
		float rays = smoothstep(0.4, 0.0, abs(fract(P.x * 0.08 - P.y * 0.05 - t * 0.2) - 0.5) * 6.0 - 1.4);
		c += vec3(1.0, 0.93, 0.6) * rays * 0.35;
		c += vec3(1.0, 0.9, 0.5) * twinkle(P * vec2(1.6, 2.4), 0.2, t) * 0.6;
		float gl = smoothstep(0.05, 0.0, abs(abs(P.y) - 0.86));
		c = mix(c, vec3(1.0, 0.82, 0.3), gl);
		e = halo * 0.7 + rays * 0.4 + gl * 0.3 + 0.15;
	} else if (th == 16) {
		// BURACO NEGRO: disco de acreção girando, anel de fótons e estrelas sendo puxadas
		c = mix(vec3(0.01, 0.0, 0.03), vec3(0.08, 0.02, 0.16), 0.5 + 0.5 * P.y);
		c += vec3(0.8, 0.85, 1.0) * twinkle(P * vec2(2.0, 2.6), 0.25, t) * 0.6;
		vec2 lc = vec2(mod(P.x, 3.6) - 1.8, P.y) * vec2(0.8, 1.15);
		float r = length(lc);
		float a = atan(lc.y, lc.x);
		float sw = fbm(vec2(a * 1.6 + t * 2.4 - r * 4.0, r * 4.0));
		float disk = smoothstep(1.05, 0.5, r) * smoothstep(0.28, 0.38, r);
		vec3 dc = mix(vec3(0.6, 0.15, 0.9), vec3(1.0, 0.65, 0.2), sw);
		dc = mix(dc, vec3(1.0, 0.95, 0.85), smoothstep(0.7, 0.95, sw));
		c = mix(c, dc, disk * (0.55 + 0.6 * sw));
		float ring2 = smoothstep(0.04, 0.0, abs(r - 0.33));
		c += vec3(1.0, 0.85, 0.6) * ring2 * 1.2;
		c = mix(c, vec3(0.0), smoothstep(0.31, 0.28, r));
		e = disk * sw * 1.1 + ring2 * 1.2;
	} else if (th == 17) {
		// FÚRIA DE ZEUS: mármore branco com veios dourados, faixa grega e raios que estalam
		float m = fbm(P * vec2(0.55, 1.6));
		c = vec3(0.93, 0.92, 0.88) - vec3(0.25, 0.22, 0.18) * smoothstep(0.05, 0.0, abs(m - 0.5));
		c = mix(c, vec3(0.95, 0.75, 0.25), smoothstep(0.03, 0.0, abs(fbm(P * vec2(0.8, 2.0) + 4.0) - 0.5)) * 0.8);
		float bandy = abs(P.y) - 0.78;
		float mk = step(0.0, bandy) * step(0.5, fract(P.x * 1.4 + step(0.88, abs(P.y)) * 0.5));
		c = mix(c, vec3(0.85, 0.62, 0.15), step(0.0, bandy) * 0.6 + mk * 0.4);
		float seed = floor(t * 6.0);
		float on = step(0.25, hash(seed * 1.3));
		for (int k = 0; k < 2; k++) {
			float fk = float(k);
			float path = (tri(P.x * 0.25 + hash(seed + fk * 7.0) * 3.0) - 0.5) * 1.2 + (vnoise(vec2(P.x * 2.0, seed + fk * 3.0)) - 0.5) * 0.5;
			float d = abs(P.y - path);
			c += vec3(1.0, 0.98, 0.8) * smoothstep(0.1, 0.0, d) * on + vec3(1.0, 0.8, 0.2) * smoothstep(0.5, 0.0, d) * on * 0.5;
			e += smoothstep(0.35, 0.0, d) * on;
		}
		e += step(0.0, bandy) * 0.2;
	} else {
		// INFINITO: diamante com facetas de arco-íris, símbolos ∞ brilhando e brilhos
		vec2 q = P * vec2(0.9, 1.5);
		vec2 ip = floor(q);
		float d1 = 9.0;
		float d2 = 9.0;
		float id = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 g = ip + vec2(float(i), float(j));
				vec2 o = g + vec2(hash2(g), hash2(g + 5.3)) * 0.8 + 0.1;
				float dd = length(q - o);
				if (dd < d1) { d2 = d1; d1 = dd; id = hash2(g * 1.3); }
				else if (dd < d2) { d2 = dd; }
			}
		}
		vec3 hc = hue(id + t * 0.15 + P.x * 0.02);
		float sh = 0.5 + 0.5 * sin(t * 2.5 + id * 6.2831);
		c = mix(vec3(0.08, 0.08, 0.14), hc, 0.55 + 0.35 * sh);
		float edge = smoothstep(0.08, 0.0, d2 - d1);
		c = mix(c, vec3(1.0), edge * 0.85);
		c += vec3(1.0) * pow(sh, 16.0) * 0.8;
		vec2 lc = vec2(mod(P.x, 3.4) - 1.7, P.y * 1.2);
		float inf = smoothstep(0.09, 0.02, lemni(lc, 1.05));
		c = mix(c, vec3(1.0) * 1.2, inf);
		e = edge * 0.6 + pow(sh, 8.0) * 0.6 + inf * 1.2 + 0.1;
	}
	return c;
}

vec3 grip2(int th, vec2 P, float t, out float e) {
	e = 0.0;
	vec3 c;
	float dd = abs(fract(P.x * 0.5 + P.y * 0.5) - 0.5) + abs(fract(P.x * 0.5 - P.y * 0.5) - 0.5);
	if (th == 11) {
		c = vec3(0.04, 0.03, 0.08) * (0.8 + 0.4 * tri(P.x * 1.2 + P.y * 0.8));
		float st = smoothstep(0.08, 0.0, abs(fract(P.x * 0.25 - t * 0.5) - 0.5) - 0.42);
		c += mix(vec3(1.0, 0.2, 0.85), vec3(0.2, 0.9, 1.0), step(0.5, fract(P.x * 0.125 - t * 0.25))) * st;
		e = st * 0.8;
	} else if (th == 12) {
		vec2 s2 = scales(P * 1.2);
		c = mix(vec3(0.2, 0.65, 0.4), vec3(0.02, 0.2, 0.12), smoothstep(0.0, 0.6, s2.y));
		c = mix(c, vec3(1.0, 0.82, 0.3), s2.x);
		e = s2.x * 0.35;
	} else if (th == 13) {
		float n = fbm(vec2(P.x * 0.9, P.y * 1.8) + t * 0.1);
		c = vec3(0.1, 0.02, 0.14) + vec3(1.0, 0.5, 0.1) * smoothstep(0.05, 0.0, abs(n - 0.5)) * (0.8 + 0.4 * sin(t * 4.0 + P.x * 0.5));
		e = smoothstep(0.05, 0.0, abs(n - 0.5));
	} else if (th == 14) {
		c = vec3(0.05, 0.01, 0.02) * (0.6 + 0.9 * smoothstep(0.0, 0.5, dd));
		float seam = smoothstep(0.05, 0.0, abs(dd - 0.5));
		c = mix(c, vec3(0.85, 0.08, 0.15), seam);
		e = seam * 0.4;
	} else if (th == 15) {
		c = vec3(0.97, 0.96, 0.92) * (0.75 + 0.35 * smoothstep(0.0, 0.5, dd));
		float seam = smoothstep(0.05, 0.0, abs(dd - 0.5));
		float stud = smoothstep(0.14, 0.07, dd);
		c = mix(c, vec3(1.0, 0.8, 0.3), max(seam * 0.8, stud));
		e = seam * 0.2 + stud * 0.4 + 0.1;
	} else if (th == 16) {
		vec2 lc = vec2(mod(P.x, 2.0) - 1.0, P.y);
		float sp = fract(length(lc) * 3.0 - atan(lc.y, lc.x) / 6.2831 - t * 0.6);
		c = mix(vec3(0.02, 0.0, 0.05), vec3(0.4, 0.15, 0.7), smoothstep(0.3, 0.0, abs(sp - 0.5) - 0.2));
		e = smoothstep(0.1, 0.0, abs(sp - 0.5) - 0.35) * 0.5;
	} else if (th == 17) {
		float rope = fract(P.x * 0.6 + P.y * 0.45);
		c = mix(vec3(0.95, 0.94, 0.9), vec3(0.95, 0.72, 0.2), step(0.5, fract(P.x * 0.3 + P.y * 0.225)));
		c *= 0.7 + 0.3 * smoothstep(0.0, 0.5, rope) * smoothstep(1.0, 0.5, rope);
		e = 0.15;
	} else {
		float h = fract(P.x * 0.08 + P.y * 0.25 - t * 0.25);
		c = mix(vec3(0.95), hue(h), 0.75) * (0.7 + 0.3 * tri(P.x * 0.6 + P.y * 0.3));
		e = 0.45;
	}
	return c;
}

// arte principal (antebraço do taco). e = brilho próprio (não escurece com a luz)
vec3 art(int th, vec2 P, float t, out float e) {
	vec3 c = vec3(0.0);
	e = 0.0;
	if (th >= 11) { return art2(th, P, t, e); }
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
	} else if (th == 9) {
		// COMETA: espaço profundo, cometas cruzando o taco com cauda de íons azul
		c = mix(vec3(0.01, 0.01, 0.05), vec3(0.05, 0.09, 0.26), 0.5 + 0.4 * P.y + 0.2 * fbm(P * vec2(0.3, 1.0)));
		c += vec3(0.75, 0.85, 1.0) * twinkle(P * vec2(1.8, 2.6), 0.3, t) * 0.9;
		e = twinkle(P * vec2(1.8, 2.6), 0.3, t) * 0.6;
		for (int k = 0; k < 2; k++) {
			float fk = float(k);
			float hx = mod(t * (5.5 + fk * 2.0) + fk * 23.0, ulen + 18.0) - 9.0;
			float hy = sin(t * 0.7 + fk * 2.4) * 0.35 + (fk - 0.5) * 0.5;
			float dx = hx - P.x;
			float dy = P.y - hy;
			float head = exp(-(dx * dx * 2.2 + dy * dy * 26.0));
			float tail = step(0.0, dx) * exp(-dx * 0.22) * exp(-dy * dy * (14.0 + dx * 0.4 * 0.0) / (1.0 + dx * 0.12));
			float ion = step(0.0, dx) * exp(-dx * 0.1) * smoothstep(0.08, 0.0, abs(dy + sin(dx * 0.9 - t * 6.0) * 0.06 * dx * 0.2)) * 0.6;
			c += vec3(1.0, 0.98, 0.9) * head * 1.6 + vec3(0.35, 0.7, 1.0) * tail * 0.9 + vec3(0.6, 0.9, 1.0) * ion;
			e += head * 1.2 + tail * 0.8 + ion;
		}
		float rim = smoothstep(0.05, 0.0, abs(abs(P.y) - 0.86));
		c = mix(c, vec3(0.7, 0.9, 1.0), rim * 0.8);
		e += rim * 0.4;
	} else if (th == 10) {
		// IMPERADOR: veludo roxo, arabescos de ouro, rubis pulsando e coroas
		c = mix(vec3(0.12, 0.02, 0.18), vec3(0.32, 0.06, 0.42), 0.5 + 0.5 * sin(P.x * 0.6 + P.y * 1.5) * 0.4 + fbm(P * vec2(0.6, 2.0)) * 0.4);
		float sc1 = abs(P.y - 0.55 * sin(P.x * 1.15));
		float sc2 = abs(P.y + 0.55 * sin(P.x * 1.15));
		float gold = smoothstep(0.07, 0.0, min(sc1, sc2));
		vec2 cl = vec2(fract(P.x * 1.15 / 3.14159) - 0.5, P.y);
		float curl = smoothstep(0.06, 0.0, abs(length(cl * vec2(2.2, 1.0)) - 0.3));
		float ruby_d = length(vec2((fract(P.x * 1.15 / 6.28318 + 0.25) - 0.5) * 6.0, P.y * 1.4));
		float ruby = smoothstep(0.42, 0.32, ruby_d);
		float rp = 0.6 + 0.4 * sin(t * 2.5 + floor(P.x * 1.15 / 6.28318) * 1.7);
		vec3 gc = mix(vec3(0.85, 0.6, 0.15), vec3(1.0, 0.92, 0.55), 0.5 + 0.5 * sin(P.x * 2.0 - t * 2.0));
		c = mix(c, gc, max(gold, curl * 0.8));
		c = mix(c, mix(vec3(0.55, 0.0, 0.08), vec3(1.0, 0.25, 0.35), rp), ruby);
		c += vec3(1.0, 0.8, 0.85) * smoothstep(0.18, 0.0, length(vec2((fract(P.x * 1.15 / 6.28318 + 0.25) - 0.5) * 6.0 + 0.12, P.y * 1.4 + 0.12))) * ruby * 0.8;
		float sweep = smoothstep(0.5, 0.0, abs(fract(P.x * 0.04 - t * 0.25) - 0.5) * 12.0 - 2.0);
		c += vec3(1.0, 0.9, 0.6) * sweep * (gold + curl) * 0.6;
		float rim = smoothstep(0.06, 0.0, abs(abs(P.y) - 0.86));
		c = mix(c, vec3(1.0, 0.85, 0.35), rim);
		e = gold * 0.5 + curl * 0.3 + ruby * rp * 0.7 + sweep * 0.3 + rim * 0.3;
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
	if (th >= 11) { return grip2(th, P, t, e); }
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
	} else if (th == 9) {
		// cristal de gelo em hexágonos com brilho azul
		vec2 q = P * vec2(1.3, 2.0);
		vec2 h1 = mod(q, vec2(1.0, 1.732)) - vec2(0.5, 0.866);
		vec2 h2 = mod(q + vec2(0.5, 0.866), vec2(1.0, 1.732)) - vec2(0.5, 0.866);
		vec2 hh = dot(h1, h1) < dot(h2, h2) ? h1 : h2;
		float hd = max(abs(hh.x) * 0.866 + abs(hh.y) * 0.5, abs(hh.y));
		float ln = smoothstep(0.06, 0.0, abs(hd - 0.45));
		c = mix(vec3(0.08, 0.16, 0.34), vec3(0.45, 0.75, 1.0), smoothstep(0.45, 0.0, hd) * 0.6);
		float sh = 0.5 + 0.5 * sin(t * 2.0 + floor(q.x) * 1.3 + floor(q.y) * 2.1);
		c += vec3(0.6, 0.9, 1.0) * ln * (0.5 + 0.5 * sh);
		e = ln * 0.6 + sh * 0.1;
	} else if (th == 10) {
		// couro roxo capitonê com tachinhas de ouro
		float dd = abs(fract(P.x * 0.55 + P.y * 0.5) - 0.5) + abs(fract(P.x * 0.55 - P.y * 0.5) - 0.5);
		c = vec3(0.22, 0.04, 0.3) * (0.55 + 0.9 * smoothstep(0.0, 0.5, dd));
		float seam = smoothstep(0.05, 0.0, abs(dd - 0.5));
		c = mix(c, vec3(0.95, 0.75, 0.3), seam * 0.7);
		float stud = smoothstep(0.14, 0.07, dd);
		c = mix(c, vec3(1.0, 0.88, 0.45) * (0.8 + 0.4 * sin(t * 3.0 + P.x)), stud);
		e = seam * 0.3 + stud * 0.5;
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
