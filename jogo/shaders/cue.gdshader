shader_type canvas_item;

uniform vec4 shaft : source_color = vec4(0.93, 0.82, 0.61, 1.0);
uniform vec4 butt : source_color = vec4(0.35, 0.18, 0.08, 1.0);
uniform vec4 accent : source_color = vec4(0.9, 0.85, 0.68, 1.0);
uniform vec4 ring : source_color = vec4(0.79, 0.64, 0.29, 1.0);
uniform vec4 wrap : source_color = vec4(0.1, 0.08, 0.06, 1.0);
uniform vec4 butt2 : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int pat = 0;
uniform int shine = 0;
uniform float shadow = 0.0;

// hash sem sin(): fica igual no celular
float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash(float x) {
	return hash2(vec2(x, x * 0.37 + 11.3));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float u = UV.x;
	float yy = (UV.y - 0.5) * 2.0;
	float h = u < 0.52 ? mix(0.40, 0.62, u / 0.52) : mix(0.62, 1.0, (u - 0.52) / 0.48);
	// ponta de couro e batente de borracha arredondados
	h *= sqrt(clamp(1.0 - pow(max(0.006 - u, 0.0) / 0.006, 2.0) * 0.6, 0.0, 1.0));
	h *= sqrt(clamp(1.0 - pow(max(u - 0.991, 0.0) / 0.009, 2.0) * 0.75, 0.0, 1.0));
	float a = smoothstep(1.0, 0.9, abs(yy) / h);
	float ny = clamp(yy / h, -1.0, 1.0);
	float nz = sqrt(max(1.0 - ny * ny, 0.0));
	vec3 col = vec3(0.5);
	float metal = 0.0;
	float gloss = 0.55;
	// veio comprido da madeira (vara e cabo)
	float grain = vnoise(vec2(u * 26.0, ny * 5.0)) * 0.6 + vnoise(vec2(u * 9.0, ny * 11.0 + 4.0)) * 0.4;
	if (u < 0.012) {
		// sola de couro com giz azul
		col = mix(vec3(0.24, 0.52, 0.84), vec3(0.4, 0.68, 0.94), smoothstep(0.0, 0.008, u));
		col = mix(col, vec3(0.3, 0.2, 0.13), smoothstep(0.008, 0.0115, u));
		gloss = 0.08;
	} else if (u < 0.038) {
		// virola de marfim
		col = vec3(0.97, 0.955, 0.91) * (0.94 + 0.06 * smoothstep(0.012, 0.03, u));
		col *= 1.0 - 0.35 * smoothstep(0.0355, 0.038, u);
		gloss = 0.75;
	} else if (u < 0.52) {
		col = shaft.rgb * (0.9 + 0.13 * grain);
		col *= 0.97 + 0.03 * vnoise(vec2(u * 140.0, ny * 2.5));
	} else if (u < 0.536) {
		float rp = (u - 0.52) / 0.016;
		col = ring.rgb * (0.6 + 0.42 * sin(rp * 3.1416)) * (1.0 - 0.45 * step(0.44, abs(rp - 0.5)));
		metal = 1.0;
	} else if (u < 0.70) {
		col = butt.rgb;
		gloss = 0.8;
		float f = fract((u - 0.536) / 0.056);
		float tri = 1.0 - abs(f * 2.0 - 1.0);
		float t = (u - 0.536) / 0.164;
		if (pat == 0) {
			col *= 0.88 + 0.2 * grain;
			if (t > 0.04 && t < 0.96) {
				// pontas embutidas com filete metálico em volta
				if (abs(ny) < tri * 0.8) {
					col = accent.rgb * (0.94 + 0.08 * grain);
				} else if (abs(ny) < tri * 0.8 + 0.1) {
					col = ring.rgb * 0.85;
				}
			}
		} else if (pat == 1) {
			float sv = step(0.5, fract(u * 52.0 + ny * 1.4));
			col = mix(butt.rgb, accent.rgb, sv);
		} else if (pat == 2) {
			col = mix(butt.rgb, butt2.rgb, smoothstep(0.0, 1.0, t));
			col *= 0.9 + 0.16 * grain;
			if (t > 0.1 && t < 0.9) {
				if (abs(ny) < tri * 0.45) {
					col = mix(col, accent.rgb, 0.85);
				} else if (abs(ny) < tri * 0.45 + 0.09) {
					col = mix(col, ring.rgb, 0.7);
				}
			}
		} else if (pat == 3) {
			float cx2 = step(0.5, fract(u * 240.0 + ny * 6.0));
			float cy2 = step(0.5, fract(u * 240.0 - ny * 6.0));
			col = mix(butt.rgb, butt2.rgb, abs(cx2 - cy2));
		} else if (pat == 4) {
			col = mix(butt.rgb, butt2.rgb, t);
			float hs = hash(floor(u * 300.0) * 7.0 + floor(ny * 9.0));
			if (hs > 0.94) {
				col = vec3(1.0);
			}
		} else if (pat == 5) {
			float sp = fract(u * 34.0 + asin(clamp(ny, -1.0, 1.0)) * 0.64);
			col = mix(butt.rgb, butt2.rgb, smoothstep(0.42, 0.5, sp) - smoothstep(0.92, 1.0, sp));
			col = mix(col, accent.rgb, smoothstep(0.03, 0.0, abs(sp - 0.46)) * 0.6);
		} else if (pat == 6) {
			vec2 q = vec2(u * 190.0, ny * 5.0);
			float dd = abs(fract(q.x + q.y * 0.5) - 0.5) + abs(fract(q.x - q.y * 0.5) - 0.5);
			col = mix(butt.rgb, butt2.rgb, step(0.62, dd));
			col += accent.rgb * smoothstep(0.04, 0.0, abs(dd - 0.62)) * 0.55;
			col += vec3(0.08) * hash2(floor(q * 1.0));
		} else if (pat == 7) {
			float n = vnoise(vec2(u * 70.0, ny * 4.0)) * 0.65 + vnoise(vec2(u * 160.0, ny * 9.0)) * 0.35;
			float crack = smoothstep(0.05, 0.0, abs(n - 0.5));
			col = butt.rgb + butt2.rgb * crack * 1.9;
			col += butt2.rgb * 0.12 * smoothstep(0.6, 1.0, n);
		} else {
			vec3 rb = 0.55 + 0.45 * cos(6.2831 * (t * 1.2 + vec3(0.0, 0.33, 0.67)));
			col = mix(butt.rgb, rb, 0.78);
			col += vec3(0.5) * smoothstep(0.1, 0.0, abs(fract(u * 22.0 - ny * 0.8) - 0.5)) * 0.18;
		}
		float g2 = hash(floor(ny * 14.0 + 50.0));
		col *= 0.95 + 0.05 * g2;
		if (shine == 1) {
			col += vec3(1.0, 0.95, 0.8) * smoothstep(0.1, 0.0, abs(fract(t * 1.0 - TIME * 0.45) - 0.5)) * 0.38;
		}
	} else if (u < 0.716) {
		float rp2 = (u - 0.70) / 0.016;
		col = ring.rgb * (0.6 + 0.42 * sin(rp2 * 3.1416)) * (1.0 - 0.45 * step(0.44, abs(rp2 - 0.5)));
		metal = 1.0;
	} else if (u < 0.93) {
		// empunhadura de linho: fios torcidos com pintas claras
		float th = fract(u * 118.0 + ny * 0.35);
		float cord = smoothstep(0.0, 0.45, th) * smoothstep(1.0, 0.55, th);
		col = wrap.rgb * (0.7 + 0.55 * cord) + vec3(0.035) * cord;
		float fl = hash2(vec2(floor(u * 118.0 + ny * 0.35), floor(ny * 7.0)));
		col = mix(col, mix(wrap.rgb, vec3(0.8, 0.78, 0.72), 0.5), step(0.88, fl) * cord * 0.4);
		gloss = 0.1;
	} else if (u < 0.946) {
		float rp3 = (u - 0.93) / 0.016;
		col = ring.rgb * (0.6 + 0.42 * sin(rp3 * 3.1416)) * (1.0 - 0.45 * step(0.44, abs(rp3 - 0.5)));
		metal = 1.0;
	} else if (u < 0.984) {
		col = butt.rgb * (0.88 + 0.2 * grain);
		float f2 = fract((u - 0.946) / 0.019);
		float tri2 = (1.0 - abs(f2 * 2.0 - 1.0)) * 0.7;
		if (abs(ny) < tri2) {
			col = accent.rgb;
		} else if (abs(ny) < tri2 + 0.1) {
			col = ring.rgb * 0.85;
		}
		gloss = 0.8;
	} else {
		// batente de borracha
		col = vec3(0.07, 0.07, 0.075) + vec3(0.05) * smoothstep(0.984, 0.99, u) * smoothstep(1.0, 0.99, u);
		gloss = 0.2;
	}
	float diff = 0.36 + 0.64 * nz;
	float spec = pow(clamp(1.0 - abs(ny + 0.38) * 2.6, 0.0, 1.0), 4.0) * (gloss + 0.55 * metal);
	float spec2 = pow(clamp(1.0 - abs(ny - 0.5) * 3.5, 0.0, 1.0), 4.0) * 0.14 * (0.3 + gloss);
	col = col * diff + vec3(spec + spec2);
	col *= mix(0.5, 1.0, nz);
	if (shadow > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.3 * a);
	} else {
		COLOR = vec4(col, a);
	}
}
