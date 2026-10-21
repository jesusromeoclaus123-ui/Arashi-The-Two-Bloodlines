
shader_type canvas_item;

uniform vec4 color_distancia : source_color = vec4(0.78, 0.52, 0.33, 1.0);
uniform float intensidad : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 textura = texture(TEXTURE, UV);

	vec3 color_final = mix(
		textura.rgb,
		color_distancia.rgb,
		intensidad
	);

	COLOR = vec4(color_final, textura.a);
}
