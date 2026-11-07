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

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	float a = smoothstep(1.0, 0.9, abs(yy) / h);
	float ny = clamp(yy / h, -1.0, 1.0);
	float nz = sqrt(max(1.0 - ny * ny, 0.0));
	vec3 col = vec3(0.5);
	float metal = 0.0;
	if (u < 0.012) {
		col = vec3(0.28, 0.58, 0.86);
	} else if (u < 0.038) {
		col = vec3(0.96, 0.95, 0.92);
	} else if (u < 0.52) {
		float g = hash(floor(ny * 9.0 + 20.0));
		col = shaft.rgb * (0.93 + 0.07 * g) * (0.96 + 0.04 * sin(u * 700.0 + g * 6.0));
	} else if (u < 0.536) {
		col = ring.rgb;
		metal = 1.0;
	} else if (u < 0.70) {
		col = butt.rgb;
		float f = fract((u - 0.536) / 0.056);
		float tri = 1.0 - abs(f * 2.0 - 1.0);
		float t = (u - 0.536) / 0.164;
		if (pat == 0) {
			if (abs(ny) < tri * 0.8 && t > 0.04 && t < 0.96) {
				col = accent.rgb;
			}
		} else if (pat == 1) {
			float sv = step(0.5, fract(u * 52.0 + ny * 1.4));
			col = mix(butt.rgb, accent.rgb, sv);
		} else if (pat == 2) {
			col = mix(butt.rgb, butt2.rgb, smoothstep(0.0, 1.0, t));
			if (abs(ny) < tri * 0.45 && t > 0.1 && t < 0.9) {
				col = mix(col, accent.rgb, 0.85);
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
		col = ring.rgb;
		metal = 1.0;
	} else if (u < 0.93) {
		float cx = step(0.5, fract(u * 320.0 + ny * 5.0));
		float cy = step(0.5, fract(u * 320.0 - ny * 5.0));
		col = wrap.rgb * (0.78 + 0.3 * abs(cx - cy));
	} else if (u < 0.946) {
		col = ring.rgb;
		metal = 1.0;
	} else if (u < 0.984) {
		col = butt.rgb;
		float f2 = fract((u - 0.946) / 0.019);
		if (abs(ny) < (1.0 - abs(f2 * 2.0 - 1.0)) * 0.7) {
			col = accent.rgb;
		}
	} else {
		col = vec3(0.05);
	}
	float diff = 0.42 + 0.58 * nz;
	float spec = pow(clamp(1.0 - abs(ny + 0.36) * 2.4, 0.0, 1.0), 3.0) * (0.5 + 0.4 * metal);
	float spec2 = pow(clamp(1.0 - abs(ny - 0.5) * 3.5, 0.0, 1.0), 4.0) * 0.12;
	col = col * diff + vec3(spec + spec2);
	col *= mix(0.5, 1.0, nz);
	if (shadow > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.3 * a);
	} else {
		COLOR = vec4(col, a);
	}
}
