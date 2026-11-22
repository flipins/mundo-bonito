shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 color_bahia : source_color = vec4(0.12, 0.51, 0.47, 1.0);
uniform vec4 color_mar : source_color = vec4(0.035, 0.23, 0.34, 1.0);
uniform vec4 color_espuma : source_color = vec4(0.83, 0.91, 0.84, 1.0);
uniform float oleaje : hint_range(0.0, 2.0) = 1.0;
uniform float mar_de_fondo : hint_range(0.0, 2.0) = 1.0;
uniform float rizos : hint_range(0.0, 2.0) = 1.0;
// Óptica del agua. Las distancias del generador están expresadas en metros.
uniform sampler2D escena_opaca : hint_screen_texture, repeat_disable, filter_linear;
uniform float refraccion : hint_range(0.0, 1.5) = 0.65;
uniform float claridad : hint_range(0.4, 2.5) = 1.0;
uniform float espuma_costera : hint_range(0.0, 1.5) = 0.88;
uniform float causticas : hint_range(0.0, 1.0) = 0.42;
// Nuevos: detalle para la vista cercana.
uniform float detalle_cercano : hint_range(0.0, 2.0) = 1.0;
uniform float dispersion : hint_range(0.0, 1.0) = 0.35;
uniform float traslucidez : hint_range(0.0, 1.0) = 0.5;
// Ancho (en metros de profundidad) del degradado donde el agua toca la orilla.
uniform float suavizado_costa : hint_range(0.02, 1.5) = 0.35;
uniform vec2 tamano;
uniform float centro_x;
uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;
varying vec2 costa_xz;
varying float distancia_dique;

// Redistribuye los vértices del plano alrededor del puerto conservando sus extremos.
float concentrar(float u, float minimo, float maximo, float puerto) {
	float centro = clamp(puerto, minimo, maximo);
	return centro + sign(u) * mix(abs(u), u * u, 0.85) *
		(u < 0.0 ? centro - minimo : maximo - centro);
}

float curva(vec2 p, vec2 a, vec2 control, vec2 b) {
	float distancia = 10000.0;
	vec2 previo = a;
	for (int i = 1; i <= 8; i++) {
		float t = float(i) / 8.0;
		vec2 actual = mix(mix(a, control, t), mix(control, b, t), t);
		vec2 tramo = actual - previo;
		vec2 delta = p - previo;
		distancia = min(distancia, length(delta - tramo * clamp(dot(delta, tramo) / dot(tramo, tramo), 0.0, 1.0)));
		previo = actual;
	}
	return distancia;
}

float exterior(vec2 p) {
	return smoothstep(0.86, 1.16, length((p - vec2(104.0, 5.0)) / vec2(93.0, 88.0)));
}

// Devuelve altura y ambas derivadas para que el brillo siga el oleaje.
vec3 onda(vec2 p, vec2 k, float fase, float amplitud) {
	float angulo = dot(p, k) + TIME * fase;
	return amplitud * vec3(sin(angulo), k * cos(angulo));
}

vec2 deriva(vec2 p) {
	return p + vec2(3.6 * sin(p.y * 0.041 + TIME * 0.17),
		4.1 * sin(p.x * 0.035 - p.y * 0.019 - TIME * 0.13));
}

float azar(vec2 celda) {
	vec3 h = fract(vec3(celda.xyx) * vec3(0.1031, 0.1137, 0.1379));
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0,0.0)), f.x),
		mix(azar(i + vec2(0.0,1.0)), azar(i + vec2(1.0)), f.x), f.y);
}

// Ruido de valor con derivadas analíticas: (valor, d/dx, d/dy).
vec3 ruido_d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = azar(i);
	float b = azar(i + vec2(1.0, 0.0));
	float c = azar(i + vec2(0.0, 1.0));
	float d = azar(i + vec2(1.0, 1.0));
	float k = a - b - c + d;
	float v = a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y;
	vec2 dv = du * vec2((b - a) + k * u.y, (c - a) + k * u.x);
	return vec3(v, dv);
}

// Pendiente de rizado turbulento. Cada octava se apaga cuando su longitud de onda
// se acerca al tamaño del píxel, así no aparece aliasing a distancia.
vec2 pendiente_detalle(vec2 p, float huella) {
	vec2 s = vec2(0.0);
	vec2 q = deriva(p);
	float freq = 0.85;
	float amp = 0.075;
	vec2 dir = vec2(0.8, 0.6);
	for (int i = 0; i < 4; i++) {
		float fade = 1.0 - smoothstep(0.30, 0.90, huella * freq);
		if (fade > 0.001) {
			vec2 pp = q * freq + vec2(float(i) * 13.7, float(i) * 7.1)
				+ dir * TIME * (0.35 + 0.25 * float(i));
			vec3 n = ruido_d(pp);
			s += fade * amp * freq * (n.yz - vec2(0.5));
		}
		// Cada octava avanza en una dirección distinta, como el viento real.
		dir = vec2(dir.x * 0.6 - dir.y * 0.8, dir.x * 0.8 + dir.y * 0.6);
		freq *= 2.07;
		amp *= 0.42;
	}
	return s;
}

vec3 oleaje_largo(vec2 p) {
	vec2 q = deriva(p);
	float grupo = ruido(p * 0.014 + vec2(TIME * 0.047, -TIME * 0.016));
	vec3 fondo = onda(q, vec2(0.069, -0.032), 0.83, 1.15)
		+ onda(q, vec2(0.041, 0.087), 0.95, 0.56);
	return oleaje * mar_de_fondo * exterior(p) * mix(0.25, 1.25, grupo) * fondo
		+ oleaje * mix(0.38, 1.0, exterior(p)) *
		(onda(q, vec2(0.16, 0.05), 0.86, 0.45) +
		onda(q, vec2(-0.09, 0.21), 1.06, 0.22) +
		onda(q, vec2(0.23, -0.14), 1.22, 0.11));
}
// Una cresta estrecha y un seno ancho rompen la simetría de las ondas.
vec3 perfil_cresta(vec3 paquete, float mar) {
	float h = paquete.x;
	float escala = 0.12 * mar;
	float forma = sqrt(1.0 + h * h);
	float realce = escala * (forma - 1.0);
	return vec3(h + realce, paquete.yz * (1.0 + escala * h / forma));
}

// Reconstrucción en espacio de vista para separar fondo, superficie y primer plano.
vec3 posicion_opaca(vec2 uv, mat4 proyeccion_inversa, float plano_lejano) {
	float muestra = texture(profundidad, uv).r;
	float z = mix(plano_lejano, 1.0, muestra);
	vec4 punto = proyeccion_inversa * vec4(uv * 2.0 - 1.0, z, 1.0);
	return punto.xyz / max(punto.w, 0.000001);
}

// La distorsión disminuye junto al borde de la pantalla.
float margen_pantalla(vec2 uv) {
	vec2 borde = min(uv, vec2(1.0) - uv);
	return smoothstep(0.005, 0.055, min(borde.x, borde.y));
}

// La luz roja desaparece antes que la verde o la azul bajo el agua.
vec3 transmision(float recorrido, float abrigo) {
	vec3 bahia = vec3(0.36, 0.145, 0.125);
	vec3 oceano = vec3(0.30, 0.118, 0.072);
	vec3 absorcion = mix(oceano, bahia, abrigo);
	return exp(-absorcion * min(recorrido, 90.0) / claridad);
}

// Dos trenes cruzados concentran la luz sobre la arena sumergida.
float luz_fondo(vec2 suelo, float profundidad_vertical, float huella) {
	float visible = smoothstep(0.08, 0.55, profundidad_vertical)
		* (1.0 - smoothstep(2.0, 7.0, profundidad_vertical))
		* (1.0 - smoothstep(0.12, 0.9, huella));
	vec2 q = suelo * 1.35;
	q += vec2(
		sin(q.y * 0.63 + TIME * 0.38),
		cos(q.x * 0.49 - TIME * 0.30)
	);
	float a = sin(q.x + 0.52 * q.y - TIME * 0.91);
	float b = sin(q.y - 0.68 * q.x + TIME * 0.74);
	float linea = 1.0 - smoothstep(0.04, 0.32, abs(a + b * 0.75));
	return linea * visible * causticas;
}

// Espuma delgada que avanza y se deshace sobre los bajos.
float espuma_playa(vec2 p, float calado, float manchas, float huella) {
	float llegada = 0.5 + 0.5 * sin(
		TIME * 0.86 + p.y * 0.078 + manchas * 2.6
	);
	float frente = 0.20 + 0.68 * llegada;
	float ancho = 0.12 + 0.26 * llegada + min(huella, 0.4);
	float cinta = 1.0 - smoothstep(0.0, ancho, abs(calado - frente));
	float residuo = (1.0 - smoothstep(0.08, 1.45, calado)) * 0.45;
	return max(cinta * llegada, residuo) * smoothstep(0.24, 0.70, manchas);
}

// La piedra retiene restos de espuma entre dos impactos sucesivos.
float espuma_piedra(vec2 p, float distancia, float manchas, float mar) {
	float pulso = 0.5 + 0.5 * sin(TIME * 1.12 + p.y * 0.19 + manchas * 3.0);
	float alcance = mix(3.6, 7.0, pulso);
	float adhesion = 1.0 - smoothstep(2.1, alcance, distancia);
	float huecos = smoothstep(0.28, 0.73, manchas + pulso * 0.09);
	return adhesion * huecos * mix(0.52, 1.0, mar);
}

// Ondulación difractada en las puntas de los rompeolas.
// El frente curvado se debilita hacia el interior del puerto.
// La fase se deforma con ruido para que no se vean anillos concéntricos perfectos.
vec3 onda_en_faro(vec2 p, vec2 faro, float desfase) {
	vec2 separacion = p - faro;
	float radio = length(separacion);
	vec2 direccion = separacion / max(radio, 0.25);
	float entrada = smoothstep(2.0, 7.0, radio);
	float salida = 1.0 - smoothstep(15.0, 57.0, radio);
	float abrigo = 1.0 - smoothstep(3.0, 25.0, separacion.x);
	float amplitud = oleaje * 0.085 * entrada * salida * abrigo;
	float fase = 0.68 * radio - TIME * 1.65 + desfase
		+ 2.6 * ruido(p * 0.06 + vec2(TIME * 0.03, 0.0));
	return vec3(
		amplitud * sin(fase),
		amplitud * 0.68 * direccion * cos(fase)
	);
}

vec3 oleaje_puerto(vec2 p) {
	vec3 principal = perfil_cresta(oleaje_largo(p), exterior(p));
	if (p.x > 133.0 && p.x < 251.0 && abs(p.y) < 89.0) {
		principal += onda_en_faro(p, vec2(193.0, -20.0), 0.7);
		principal += onda_en_faro(p, vec2(193.0, 29.0), 2.9);
	}
	return principal;
}

// Fragmentos de espuma arrastrados desde las crestas al caer la ola.
float estela_cresta(vec2 p, float altura, float pendiente, float cobertura) {
	vec2 viento_local = vec2(0.82, 0.36);
	vec2 eje_lateral = vec2(-viento_local.y, viento_local.x);
	vec2 bandas = vec2(
		dot(p, viento_local) * 0.16 + TIME * 0.23,
		dot(p, eje_lateral) * 0.54
	);
	float fibras = ruido(bandas);
	float rotura = smoothstep(0.74, 1.36, altura);
	float labio = smoothstep(0.03, 0.24, pendiente);
	float vacios = smoothstep(0.37, 0.74, cobertura + fibras * 0.16);
	return rotura * labio * fibras * vacios;
}

// Burbujas finas: sólo se resuelven a corta distancia y sólo dentro de espuma densa.
float poros_espuma(vec2 p, float huella, float manchas) {
	float visible = 1.0 - smoothstep(0.05, 0.22, huella);
	if (visible < 0.001) {
		return 1.0;
	}
	vec2 uv = p * 2.4;
	uv += vec2(TIME * 0.29, manchas * 1.6);
	vec2 celda = floor(uv);
	vec2 borde = fract(uv) - 0.5;
	vec2 centro = 0.32 * (vec2(azar(celda), azar(celda + 11.3)) - 0.5);
	float radio = mix(0.07, 0.23, azar(celda - 7.8));
	float disco = 1.0 - smoothstep(radio * 0.45, radio, length(borde - centro));
	return 1.0 - visible * disco * 0.32;
}

void vertex() {
	vec2 u = VERTEX.xz * 2.0 / tamano;
	VERTEX.x = concentrar(u.x, -tamano.x * 0.5, tamano.x * 0.5, 144.0 - centro_x);
	VERTEX.z = concentrar(u.y, -tamano.y * 0.5, tamano.y * 0.5, 0.0);
	costa_xz = VERTEX.xz + vec2(centro_x, 0.0);
	VERTEX.y += oleaje_puerto(costa_xz).x;
	distancia_dique = min(
		curva(costa_xz, vec2(98,-75), vec2(178,-93), vec2(193,-20)),
		curva(costa_xz, vec2(111,91), vec2(180,102), vec2(193,29)));
}

void fragment() {
	vec2 p = costa_xz;
	float mar = exterior(p);
	vec3 ondas = oleaje_puerto(p);
	float distancia = length(VERTEX);
	float huella = max(length(dFdx(p)), length(dFdy(p)));
	float detalle = (1.0 - smoothstep(0.20, 1.35, huella)) * (1.0 - smoothstep(48.0, 220.0, distancia));
	vec2 q = deriva(p);
	float viento = ruido(p * 0.093 + vec2(TIME * 0.18, -TIME * 0.07));
	vec2 r = q + vec2(sin(q.y * 0.32 + TIME * 0.41), cos(q.x * 0.26 - TIME * 0.34));
	ondas += detalle * rizos * oleaje * mix(0.24, 1.0, viento) *
		(onda(r, vec2(1.24, 0.71), 1.73, 0.052) + onda(r, vec2(-0.81, 1.46), 1.92, 0.043)
		+ onda(r, vec2(0.27, -2.18), 2.27, 0.021));
	float micro = 1.0 - smoothstep(0.045, 0.35, huella);
	ondas += micro * detalle * viento * rizos * oleaje * (onda(r, vec2(4.8, -3.4), 3.32, 0.013)
		+ onda(r, vec2(-2.6, -5.7), 3.88, 0.009));
	// Rizado turbulento no periódico: rompe el patrón de senos y da carácter de agua real.
	ondas.yz += detalle_cercano * rizos * oleaje * mix(0.5, 1.0, viento)
		* (1.0 - smoothstep(80.0, 300.0, distancia))
		* pendiente_detalle(p, huella);
	float lejania = max(smoothstep(100.0, 520.0, distancia), smoothstep(1.2, 8.0, huella));
	ondas.yz *= mix(1.0, 0.15, lejania);
	NORMAL = normalize(mat3(VIEW_MATRIX * MODEL_MATRIX) * vec3(-ondas.y, 1.0, -ondas.z));
	// Profundidad vertical para la espuma y distancia óptica para la absorción.
	vec3 opaco = posicion_opaca(SCREEN_UV, INV_PROJECTION_MATRIX, CLIP_SPACE_FAR);
	vec3 espesor_mundo = mat3(INV_VIEW_MATRIX) * (VERTEX - opaco);
	// La profundidad pierde precisión con la distancia: se descuenta para no inventar espuma lejana.
	float calado = max(0.0, espesor_mundo.y - distancia * 0.0015);
	float recorrido = clamp(length(VERTEX - opaco), 0.0, 90.0);

	// Usa la inclinación de las ondas relativa al plano del agua.
	vec3 arriba = normalize(mat3(VIEW_MATRIX * MODEL_MATRIX) * vec3(0.0, 1.0, 0.0));
	vec2 desviacion = (NORMAL - arriba).xy;
	float intensidad = refraccion * margen_pantalla(SCREEN_UV);
	intensidad *= smoothstep(0.0, 1.7, calado);
	intensidad *= 1.0 - smoothstep(16.0, 32.0, recorrido);
	vec2 uv_fondo = clamp(
		SCREEN_UV - desviacion * intensidad * 0.022,
		vec2(0.001),
		vec2(0.999)
	);
	vec3 candidato = posicion_opaca(uv_fondo, INV_PROJECTION_MATRIX, CLIP_SPACE_FAR);
	// Evita arrastrar la silueta del personaje o del muelle sobre el agua.
	if (candidato.z >= VERTEX.z - 0.025) {
		uv_fondo = SCREEN_UV;
		candidato = opaco;
	}

	// Dispersión cromática leve: cada canal se refracta un poco distinto.
	vec2 desplazamiento = uv_fondo - SCREEN_UV;
	vec3 arena;
	arena.r = texture(escena_opaca, clamp(SCREEN_UV + desplazamiento * (1.0 - 0.18 * dispersion), vec2(0.001), vec2(0.999))).r;
	arena.g = texture(escena_opaca, uv_fondo).g;
	arena.b = texture(escena_opaca, clamp(SCREEN_UV + desplazamiento * (1.0 + 0.18 * dispersion), vec2(0.001), vec2(0.999))).b;
	vec2 suelo = (INV_VIEW_MATRIX * vec4(candidato, 1.0)).xz;
	if (calado < 7.0 && causticas > 0.0) {
		arena *= 1.0 + luz_fondo(suelo, calado, huella);
	}
	vec3 paso = transmision(recorrido, 1.0 - mar);
	float incidencia = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 0.0204 + 0.9796 * pow(1.0 - incidencia, 5.0);
	vec3 transmitido = paso * (1.0 - fresnel);

	// El color se hace más profundo con la trayectoria recorrida por la luz.
	float tinte_profundo = 1.0 - exp(-calado * 0.105);
	vec3 volumen = mix(
		color_bahia.rgb,
		color_mar.rgb,
		tinte_profundo * mix(0.60, 1.0, mar)
	);
	vec2 corriente = p * 0.42 + vec2(TIME * 0.34, -TIME * 0.17);
	float manchas = 0.66 * ruido(corriente) + 0.34 * ruido(corriente * 2.67);
	float playa = espuma_playa(p, calado, manchas, huella);
	// Vaivén de la orilla: el agua sube y baja por la arena al ritmo de las olas.
	float vaiven = 0.5 + 0.5 * sin(TIME * 0.86 + p.y * 0.078 + manchas * 2.6);
	// Línea fina de espuma justo donde el agua toca el terreno.
	float linea_orilla = (1.0 - smoothstep(0.0, 0.05 + 0.10 * vaiven, calado))
		* smoothstep(0.18, 0.55, manchas);
	playa = max(playa, linea_orilla * (0.55 + 0.45 * vaiven));
	playa *= 1.0 - smoothstep(70.0, 220.0, distancia);
	float piedra = espuma_piedra(p, distancia_dique, manchas, mar);
	float cresta = smoothstep(1.00, 1.85, ondas.x);
	float rotura = smoothstep(0.48, 0.77, manchas) * cresta * mar;
	rotura = max(rotura, mar * estela_cresta(p, ondas.x, length(ondas.yz), manchas));
	float espuma = clamp(
		max(max(playa, piedra) * espuma_costera, rotura * 0.48),
		0.0, 1.0
	);
	if (espuma > 0.001) {
		// Los poros sólo se notan en espuma densa; en la delgada dejaban puntos oscuros.
		espuma *= mix(1.0, poros_espuma(p, huella, manchas), smoothstep(0.45, 0.85, espuma));
	}
	vec3 sal = color_espuma.rgb * mix(0.75, 1.0, manchas);
	ALBEDO = mix(volumen * (1.0 - paso), sal, espuma);
	EMISSION = arena * transmitido * (1.0 - espuma);

	// Translucidez: las crestas dejan pasar luz y se ven más turquesa, sobre todo de lado.
	float cresta_luz = smoothstep(0.15, 1.30, ondas.x) + 0.5 * smoothstep(0.10, 0.45, length(ondas.yz));
	EMISSION += color_bahia.rgb * 0.11 * traslucidez * clamp(cresta_luz, 0.0, 1.0)
		* (0.4 + 0.6 * (1.0 - incidencia)) * (1.0 - espuma) * mix(0.5, 1.0, mar);

	ROUGHNESS = mix(0.16 + 0.20 * lejania + 0.065 * viento, 0.69, espuma);
	SPECULAR = 0.36;
	// Degradado en la orilla: el agua se vuelve transparente donde apenas hay profundidad,
	// y la arena de fondo (ya incluida en EMISSION) se mezcla con la del framebuffer.
	float borde = suavizado_costa * (0.6 + 0.8 * vaiven);
	float opacidad_costa = smoothstep(0.0, borde, calado);
	ALPHA = clamp(max(opacidad_costa, espuma * 0.9), 0.0, 1.0);
}