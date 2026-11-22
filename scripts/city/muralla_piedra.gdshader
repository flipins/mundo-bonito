shader_type spatial;
render_mode cull_disabled;

uniform vec4 color_a : source_color = vec4(0.72, 0.62, 0.47, 1.0);
uniform vec4 color_b : source_color = vec4(0.55, 0.46, 0.35, 1.0);
uniform vec4 color_junta : source_color = vec4(0.25, 0.20, 0.15, 1.0);
uniform vec2 tamano_ladrillo = vec2(1.8, 0.8);
uniform float grosor_junta : hint_range(0.02, 0.4) = 0.14;
uniform float relieve : hint_range(0.0, 3.0) = 1.4;

varying vec3 pos_local;
varying vec3 nor_local;

float azar(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1, 0)), f.x),
			   mix(azar(i + vec2(0, 1)), azar(i + vec2(1, 1)), f.x), f.y);
}

// Altura de la piedra en uv (metros). Devuelve h y escribe id y junta.
float piedra(vec2 uv, out vec2 id, out float junta) {
	float fila = floor(uv.y / tamano_ladrillo.y);
	// Cada hilera tiene piedras de largo distinto y desfase propio.
	float largo = tamano_ladrillo.x * (0.7 + 0.7 * azar(vec2(fila, 3.0)));
	vec2 celda = vec2(uv.x / largo + azar(vec2(fila, 9.0)) * 10.0, uv.y / tamano_ladrillo.y);
	id = floor(celda);
	vec2 f = fract(celda);
	float d = min(min(f.x, 1.0 - f.x) * largo, min(f.y, 1.0 - f.y) * tamano_ladrillo.y);
	junta = 1.0 - smoothstep(grosor_junta * 0.5, grosor_junta, d);
	float borde = smoothstep(0.0, 0.28, d);                 // bordes redondeados
	float abultado = 0.65 + 0.35 * azar(id + 41.0);         // cada piedra sobresale distinto
	return borde * abultado + 0.25 * ruido(uv * 5.0) + 0.1 * ruido(uv * 17.0);
}

void vertex() {
	pos_local = VERTEX;
	nor_local = NORMAL;
}

void fragment() {
	vec3 n = normalize(nor_local);
	vec3 an = abs(n);
	vec2 uv; vec3 U; vec3 V;
	if (an.y > 0.7)      { uv = pos_local.xz; U = vec3(1, 0, 0); V = vec3(0, 0, 1); }
	else if (an.x > an.z){ uv = pos_local.zy; U = vec3(0, 0, 1); V = vec3(0, 1, 0); }
	else                 { uv = pos_local.xy; U = vec3(1, 0, 0); V = vec3(0, 1, 0); }

	vec2 id; float junta;
	float h = piedra(uv, id, junta);

	// Relieve: gradiente de altura -> normal inclinada.
	vec2 id2; float j2;
	float e = 0.04;
	float dhu = (piedra(uv + vec2(e, 0), id2, j2) - h) / e;
	float dhv = (piedra(uv + vec2(0, e), id2, j2) - h) / e;
	vec3 n_local = normalize(n - (dhu * U + dhv * V) * 0.12 * relieve);
	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * n_local));

	// Color: variación por piedra, por zona y manchas verticales de suciedad.
	float v1 = azar(id);
	float zona = ruido(uv * 0.35);
	vec3 col = mix(color_a.rgb, color_b.rgb, clamp(v1 * 0.6 + zona * 0.6 - 0.15, 0.0, 1.0));
	col *= 0.85 + 0.3 * azar(id + 17.0);
	col *= 1.0 - 0.25 * ruido(vec2(uv.x * 1.3, uv.y * 0.07));   // chorreaduras
	col *= mix(0.6, 1.0, smoothstep(0.1, 0.6, h));               // grietas oscuras
	col = mix(col, color_junta.rgb, junta);

	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
}