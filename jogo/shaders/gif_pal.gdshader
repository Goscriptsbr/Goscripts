shader_type canvas_item;
// mostra um quadro do replay: cada pixel guarda o número da cor (0..127) -> cor da paleta do quadro
uniform vec3 pal[128];
void fragment() {
	int idx = int(floor(texture(TEXTURE, UV).r * 255.0 + 0.5));
	COLOR = vec4(pal[clamp(idx, 0, 127)], 1.0);
}
