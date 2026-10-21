
shader_type canvas_item;

// Intensidad general de la luz
uniform float intensidad : hint_range(0.0, 1.0) = 0.9;

// Velocidad del brillo
uniform float velocidad_pulso : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    // Centro de la imagen
    vec2 centro = UV - vec2(0.5);

    // Distancia al centro del portal
    float distancia = length(centro * 2.0);

    // Bordes suaves y transparentes
    float resplandor = 1.0 - smoothstep(
        0.0, 1.0, distancia
    );

    // Luz que aumenta y disminuye
    float pulso = 0.75 + 0.25 * sin(
        TIME * velocidad_pulso
    );

    // Transparencia final
    float alpha = resplandor * pulso * intensidad;

    COLOR = vec4(1.0, 1.0, 1.0, alpha);
}
