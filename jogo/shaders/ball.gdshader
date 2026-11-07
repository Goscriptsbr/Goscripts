shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float striped = 0.0;
uniform float is_cue = 0.0;
uniform float number = 0.0;
uniform vec3 rx = vec3(1.0, 0.0, 0.0);
uniform vec3 ry = vec3(0.0, 1.0, 0.0);
uniform vec3 rz = vec3(0.0, 0.0, 1.0);
uniform sampler2D atlas : filter_linear;
uniform float pad = 1.45;

void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0 * pad;
	float r2 = dot(q, q);
	if (r2 > 1.0) {
		float sd = length(q - vec2(0.10, 0.17));
		COLOR = vec4(0.0, 0.0, 0.0, smoothstep(1.3, 0.85, sd) * 0.5);
	} else {
		float z = sqrt(1.0 - r2);
		vec3 v = vec3(q, z);
		vec3 l = transpose(mat3(rx, ry, rz)) * v;
		vec3 white = vec3(0.97, 0.96, 0.91);
		vec3 albedo = base_color.rgb;
		if (is_cue > 0.5) {
			albedo = white;
		} else {
			if (striped > 0.5) {
				albedo = abs(l.y) < 0.52 ? base_color.rgb : white;
			}
			float side = l.z >= 0.0 ? 1.0 : -1.0;
			vec2 sp = vec2(l.x * side, l.y);
			float dsp = length(sp);
			float spot = smoothstep(0.50, 0.46, dsp);
			if (spot > 0.0) {
				vec2 uvd = sp / 0.92 + vec2(0.5);
				float col = mod(number, 4.0);
				float row = floor(number / 4.0);
				float da = texture(atlas, (vec2(col, row) + clamp(uvd, 0.0, 1.0)) / 4.0).a;
				vec3 spotc = mix(white, vec3(0.04), da);
				albedo = mix(albedo, spotc, spot);
			}
		}
		vec3 L = normalize(vec3(-0.45, -0.55, 0.7));
		float diff = max(dot(v, L), 0.0);
		vec3 col = albedo * (0.34 + 0.8 * diff);
		vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
		float spec = pow(max(dot(v, H), 0.0), 56.0);
		col += vec3(1.0) * spec * 0.7;
		col += vec3(0.9, 0.95, 1.0) * pow(max(dot(v, normalize(vec3(0.5, 0.6, 0.62))), 0.0), 30.0) * 0.12;
		col *= mix(0.6, 1.0, smoothstep(0.0, 0.5, z));
		COLOR = vec4(col, smoothstep(1.0, 0.96, sqrt(r2)));
	}
}
