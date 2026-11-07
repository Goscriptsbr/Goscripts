shader_type canvas_item;

uniform float reveal = 1.0;
uniform float shine = -1.0;
uniform float alpha = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float edge = smoothstep(reveal, reveal - 0.14, UV.x);
	float diag = UV.x + UV.y * 0.32;
	float band = smoothstep(0.075, 0.0, abs(diag - shine));
	c.rgb += vec3(0.85, 1.0, 1.0) * band * c.a * 0.95;
	c.a *= edge * alpha;
	COLOR = c;
}
