shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Paño atado a la espada que ondea con el viento.
// La malla es una tira: UV.x va de 0 (el nudo) a 1 (la punta); UV.y cruza el ancho.
// El nudo no se mueve y el movimiento crece hacia la punta. Los bordes rotos se
// recortan en el fragment con ruido, así no hace falta ninguna textura.

uniform vec4 color_tela : source_color = vec4(0.32, 0.04, 0.05, 1.0);
// 0 = calma, 1 = viento normal, 3 = tormenta.
uniform float fuerza_viento : hint_range(0.0, 3.0) = 1.0;
// Qué tan rápido corre la onda de la tela.
uniform float velocidad = 4.5;
// Cada paño usa una fase distinta para que no se muevan igual.
uniform float fase = 0.0;
// Largo de la tira en metros (se usa para escalar el movimiento).
uniform float largo = 1.6;
// Cuánto cuelga la punta cuando casi no hay viento.
uniform float caida = 0.30;
// Qué tan rotos están los bordes y la punta.
uniform float desgarro : hint_range(0.0, 1.0) = 0.55;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido_valor(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	float t = UV.x;
	float anclaje = t * t; // el nudo (t = 0) casi no se mueve

	// Ráfagas lentas: el viento sube y baja de intensidad.
	float rafaga = 0.8 + 0.2 * sin(TIME * 0.7 + fase) + 0.1 * sin(TIME * 1.9 + fase * 2.0);

	// Dos ondas que viajan del nudo hacia la punta.
	float onda1 = sin(t * 8.0 - TIME * velocidad + fase);
	float onda2 = sin(t * 15.0 - TIME * velocidad * 1.6 + fase * 1.7);
	float amplitud = fuerza_viento * rafaga * anclaje * largo;

	VERTEX.z += (onda1 * 0.20 + onda2 * 0.06) * amplitud;
	VERTEX.y += cos(t * 6.0 - TIME * velocidad * 0.75 + fase) * 0.09 * amplitud;

	// Con poco viento la punta cuelga; con mucho, se estira recta.
	VERTEX.y -= caida * anclaje * largo * max(0.0, 1.3 - 0.4 * fuerza_viento);
}

void fragment() {
	float t = UV.x;
	float borde = abs(UV.y - 0.5) * 2.0; // 0 en el centro, 1 en el borde

	// La tira es angosta en el nudo, se ensancha y se afina hacia la punta.
	float ancho = mix(0.35, 1.0, smoothstep(0.0, 0.18, t));
	ancho *= mix(1.0, 0.22, pow(t, 1.4));

	// Borde irregular: más roto cuanto más cerca de la punta.
	float irregular = (ruido_valor(vec2(t * 26.0 + fase * 5.0, UV.y * 3.0)) - 0.5) * desgarro * (0.25 + t);
	if (borde > ancho + irregular) {
		discard;
	}

	// Algunos tajos que atraviesan la tela.
	float tajo = ruido_valor(vec2(t * 7.0 + fase * 3.0, UV.y * 11.0));
	if (t > 0.35 && tajo > 0.86) {
		discard;
	}

	// Un poco de trama para que no se vea plana.
	float trama = 0.8 + 0.4 * ruido_valor(vec2(t * 40.0, UV.y * 8.0));
	ALBEDO = color_tela.rgb * trama;
	ROUGHNESS = 1.0;
	// Con el sol detrás, la luz atraviesa la tela y la tiñe de rojo.
	BACKLIGHT = color_tela.rgb * 0.8;
}
