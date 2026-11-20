shader_type canvas_item;
// mostra um quadro do replay: cada pixel guarda o número da cor (0..127) -> cor de verdade
void fragment() {
	float idx = floor(texture(TEXTURE, UV).r * 255.0 + 0.5);
	float r = floor(idx / 32.0);
	float g = mod(floor(idx / 4.0), 8.0);
	float b = mod(idx, 4.0);
	COLOR = vec4(r / 3.0, g / 7.0, b / 3.0, 1.0);
}
