shader_type spatial;
render_mode cull_back;

// Un solo material para todo el terreno (sin transparencia ni overlay).
// COLOR.r = oclusión ambiental falsa, COLOR.g = curvatura (viene del script).

// --- Arena (toma la textura de tu material de arena) ---
uniform sampler2D textura_arena : source_color, filter_linear_mipmap, repeat_enable;
uniform bool usar_textura_arena = false;
uniform vec4 color_arena : source_color = vec4(0.76, 0.64, 0.46, 1.0);
uniform vec2 escala_uv_arena = vec2(1.0, 1.0);

// --- Roca terracota ---
uniform vec4 roca_sombra : source_color = vec4(0.36, 0.17, 0.10, 1.0);
uniform vec4 roca_media  : source_color = vec4(0.66, 0.36, 0.20, 1.0);
uniform vec4 roca_sol    : source_color = vec4(0.82, 0.50, 0.29, 1.0);

uniform float altura_inicio_roca = 3.0;
uniform float intensidad_relieve : hint_range(0.0, 3.0) = 1.0;
uniform float amplitud_relieve = 8.0;
uniform float escala_horizontal = 0.09;   // más alto = surcos más finos
uniform float escala_vertical = 0.03;     // más bajo = surcos más largos hacia abajo
uniform float distancia_relieve = 220.0;
uniform float fuerza_oclusion : hint_range(0.0, 1.0) = 0.7;

// --- Texturas de roca (opcionales; las asigna el script) ---
uniform sampler2D textura_roca : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_roca : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool usar_textura_roca = false;
uniform bool usar_normal_roca = false;
uniform float escala_textura_roca = 0.07;
uniform float mezcla_color_textura : hint_range(0.0, 1.0) = 0.5;
uniform float fuerza_normal_roca : hint_range(0.0, 2.0) = 1.0;

// --- Texturas de suelo (opcionales): A = tierra/escombros, B = arena texturizada ---
uniform sampler2D textura_suelo_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_suelo_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_suelo_b : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_suelo_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool usar_suelo_a = false;
uniform bool usar_normal_suelo_a = false;
uniform bool usar_suelo_b = false;
uniform bool usar_normal_suelo_b = false;
uniform float escala_suelo_a = 0.15;
uniform float escala_suelo_b = 0.10;
uniform float mezcla_color_suelo : hint_range(0.0, 1.0) = 0.5;
uniform float fuerza_normal_suelo : hint_range(0.0, 2.0) = 1.0;
uniform float cobertura_suelo_b : hint_range(0.0, 1.0) = 0.6;
// Cuánto del suelo plano lleva textura B siempre (evita zonas lisas sin textura).
uniform float cobertura_suelo_base : hint_range(0.0, 1.0) = 0.8;

varying vec3 posicion_local;
varying vec3 normal_local;

float azar(vec2 celda) {
	vec3 p = fract(vec3(celda.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec2 p) {
	vec2 celda = floor(p);
	vec2 f = fract(p);
	vec2 curva = f * f * (3.0 - 2.0 * f);
	float inferior = mix(azar(celda), azar(celda + vec2(1.0, 0.0)), curva.x);
	float superior = mix(azar(celda + vec2(0.0, 1.0)), azar(celda + vec2(1.0, 1.0)), curva.x);
	return mix(inferior, superior, curva.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * ruido(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v / 0.875;
}

float cresta(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		float n = 1.0 - abs(2.0 * ruido(p) - 1.0);
		v += a * n * n;
		p = p * 2.03 + vec2(5.9, 13.3);
		a *= 0.5;
	}
	return v / 0.875;
}

// Triplanar: surcos verticales en las paredes, grano horizontal arriba.
float relieve(vec3 p, vec3 w) {
	float hx = cresta(vec2(p.z * escala_horizontal, p.y * escala_vertical));
	float hz = cresta(vec2(p.x * escala_horizontal, p.y * escala_vertical) + 7.7);
	float hy = cresta(p.xz * 0.06 + 3.1);
	return hx * w.x + hz * w.z + hy * w.y;
}

// Color triplanar (sin estirarse en las paredes).
vec3 tri_color(vec3 p, vec3 w, float escala) {
	vec3 q = p * escala;
	return texture(textura_roca, q.zy).rgb * w.x
		+ texture(textura_roca, q.xz).rgb * w.y
		+ texture(textura_roca, q.xy).rgb * w.z;
}

// Normal map triplanar (mezcla UDN). Espera normal map estilo OpenGL.
vec3 tri_normal(vec3 p, vec3 w, vec3 n, float escala, float fuerza) {
	vec3 q = p * escala;
	vec3 tx = texture(normal_roca, q.zy).xyz * 2.0 - 1.0;
	vec3 ty = texture(normal_roca, q.xz).xyz * 2.0 - 1.0;
	vec3 tz = texture(normal_roca, q.xy).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy * fuerza + n.zy, n.x);
	ty = vec3(ty.xy * fuerza + n.xz, n.y);
	tz = vec3(tz.xy * fuerza + n.xy, n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

vec3 tri_color_s(sampler2D tex, vec3 p, vec3 w, float escala) {
	vec3 q = p * escala;
	return texture(tex, q.zy).rgb * w.x
		+ texture(tex, q.xz).rgb * w.y
		+ texture(tex, q.xy).rgb * w.z;
}

vec3 tri_normal_s(sampler2D tex, vec3 p, vec3 w, vec3 n, float escala, float fuerza) {
	vec3 q = p * escala;
	vec3 tx = texture(tex, q.zy).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex, q.xz).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex, q.xy).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy * fuerza + n.zy, n.x);
	ty = vec3(ty.xy * fuerza + n.xz, n.y);
	tz = vec3(tz.xy * fuerza + n.xy, n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void vertex() {
	posicion_local = VERTEX;
	normal_local = NORMAL;
}

void fragment() {
	vec3 n0 = normalize(normal_local);
	float pend = 1.0 - clamp(n0.y, 0.0, 1.0);
	float ao = COLOR.r;
	float curv = COLOR.g;

	// --- Arena base ---
	vec3 arena = color_arena.rgb;
	if (usar_textura_arena) {
		arena *= texture(textura_arena, UV * escala_uv_arena).rgb;
	}

	float mancha = fbm(posicion_local.xz * 0.02 + vec2(posicion_local.y * 0.012));
	float sobre_base = smoothstep(
		altura_inicio_roca,
		altura_inicio_roca + 12.0,
		posicion_local.y + (mancha - 0.5) * 8.0
	);

	// --- Dónde hay roca: laderas empinadas y crestas.
	// La arena se queda en lo plano y se acumula en los barrancos. ---
	// La curvatura manda: la arena se acumula en barrancos y repisas, y el ruido
	// solo rompe un poco el borde (antes salían parches al azar).
	float umbral = pend + (mancha - 0.5) * 0.07 - (0.5 - curv) * 0.30;
	float roca = smoothstep(0.07, 0.26, umbral) * sobre_base;
	roca = max(roca, smoothstep(0.62, 0.80, curv) * sobre_base * 0.7);

	vec3 w = pow(abs(n0), vec3(4.0));
	w /= (w.x + w.y + w.z);

	// --- Suelos con textura: cubren también lo plano ---
	// A (tierra/escombros): al pie de las laderas y en parches.
	// B (arena texturizada): base de todas las llanuras, con intensidad variable.
	float parche = fbm(posicion_local.xz * 0.012 + vec2(31.7, 8.4));
	float parche2 = fbm(posicion_local.xz * 0.035 + vec2(3.3, 19.1));

	// Variación de tono a gran escala para romper la uniformidad de la arena.
	arena *= 0.90 + 0.20 * parche;

	float pie = smoothstep(0.02, 0.10, pend) * (1.0 - roca);
	float mask_a = clamp(pie * 0.9 + smoothstep(0.52, 0.72, parche) * 0.8, 0.0, 1.0) * (1.0 - roca);
	float umbral_b = mix(0.62, 0.42, cobertura_suelo_b);
	float parches_b = smoothstep(umbral_b, umbral_b + 0.12, parche2);
	float base_b = cobertura_suelo_base * (0.6 + 0.4 * parche2);
	float mask_b = max(parches_b, base_b) * (1.0 - roca) * (1.0 - mask_a * 0.7);

	vec3 n_suelo = n0;
	if (usar_suelo_a && mask_a > 0.01) {
		vec3 ta = mix(
			tri_color_s(textura_suelo_a, posicion_local, w, escala_suelo_a),
			tri_color_s(textura_suelo_a, posicion_local, w, escala_suelo_a * 0.27),
			0.4
		);
		float la = dot(ta, vec3(0.299, 0.587, 0.114));
		arena = mix(arena, mix(arena * (0.45 + 1.1 * la), ta, mezcla_color_suelo), mask_a);
	}
	if (usar_suelo_b && mask_b > 0.01) {
		vec3 tb = mix(
			tri_color_s(textura_suelo_b, posicion_local, w, escala_suelo_b),
			tri_color_s(textura_suelo_b, posicion_local, w, escala_suelo_b * 0.27),
			0.4
		);
		float lb = dot(tb, vec3(0.299, 0.587, 0.114));
		arena = mix(arena, mix(arena * (0.45 + 1.1 * lb), tb, mezcla_color_suelo), mask_b);
	}
	if (usar_normal_suelo_a && mask_a > 0.02) {
		vec3 n1 = tri_normal_s(normal_suelo_a, posicion_local, w, n0, escala_suelo_a, fuerza_normal_suelo);
		vec3 n2 = tri_normal_s(normal_suelo_a, posicion_local, w, n0, escala_suelo_a * 0.27, fuerza_normal_suelo);
		n_suelo = normalize(mix(n_suelo, normalize(mix(n1, n2, 0.35)), mask_a));
	}
	if (usar_normal_suelo_b && mask_b > 0.02) {
		vec3 n3 = tri_normal_s(normal_suelo_b, posicion_local, w, n0, escala_suelo_b, fuerza_normal_suelo);
		vec3 n4 = tri_normal_s(normal_suelo_b, posicion_local, w, n0, escala_suelo_b * 0.27, fuerza_normal_suelo);
		n_suelo = normalize(mix(n_suelo, normalize(mix(n3, n4, 0.35)), mask_b));
	}

	// --- Relieve de la roca (solo donde hay roca) ---
	float h = 0.5;
	vec3 n_local = n_suelo;
	vec3 tex_roca = vec3(0.5);
	if (roca > 0.02) {
		h = relieve(posicion_local, w);

		// Texturas reales de roca (si las asignaste), dos escalas para romper el patrón.
		vec3 n_base = n_suelo;
		if (usar_textura_roca) {
			tex_roca = mix(
				tri_color(posicion_local, w, escala_textura_roca),
				tri_color(posicion_local, w, escala_textura_roca * 0.29),
				0.4
			);
		}
		if (usar_normal_roca) {
			vec3 na = tri_normal(posicion_local, w, n0, escala_textura_roca, fuerza_normal_roca);
			vec3 nb = tri_normal(posicion_local, w, n0, escala_textura_roca * 0.29, fuerza_normal_roca);
			n_base = normalize(mix(n_suelo, normalize(mix(na, nb, 0.35)), roca));
		}
float fade = 1.0 - smoothstep(0.3 * distancia_relieve, distancia_relieve, -VERTEX.z);
n_local = n_base;

if (fade > 0.0) {
    float e = 0.7;
    vec3 g = vec3(
        relieve(posicion_local + vec3(e, 0.0, 0.0), w) - h,
        relieve(posicion_local + vec3(0.0, e, 0.0), w) - h,
        relieve(posicion_local + vec3(0.0, 0.0, e), w) - h
    ) / e;
    g -= n_base * dot(g, n_base);
            n_local = normalize(n_base - g * amplitud_relieve * intensidad_relieve * fade * roca);
    }
NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * n_local));
}
	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * n_local));

	// --- Color de la roca ---
	vec3 piedra = mix(roca_sombra.rgb, roca_media.rgb, smoothstep(0.10, 0.60, h));
	piedra = mix(piedra, roca_sol.rgb, smoothstep(0.55, 1.0, h) * 0.7);
	piedra *= 0.85 + 0.30 * mancha;
	// Estratos: cada banda tiene su tono, con una línea oscura en el borde.
	float yb = posicion_local.y * 0.30 + mancha * 3.0;
	float tono_banda = azar(vec2(floor(yb), 1.7));
	piedra *= 0.86 + 0.28 * tono_banda;
	piedra *= 0.90 + 0.10 * smoothstep(0.0, 0.12, fract(yb));
	piedra = mix(piedra, piedra * vec3(1.10, 1.0, 0.85), tono_banda * 0.5);

	// Grietas y barrancos más oscuros, filos y crestas más claros.
	piedra *= mix(0.65, 1.0, smoothstep(0.25, 0.50, curv));
	piedra *= 1.0 + 0.30 * smoothstep(0.55, 0.80, curv);

	// Con textura: su detalle modula la paleta terracota (mezcla_color_textura = 1 usa su color).
	if (usar_textura_roca && roca > 0.02) {
		float luma = dot(tex_roca, vec3(0.299, 0.587, 0.114));
		piedra = mix(piedra * (0.35 + 1.3 * luma), tex_roca, mezcla_color_textura);
	}

	// La arena de ladera se tiñe un poco de la roca de arriba.
	vec3 arena_ladera = mix(arena, roca_media.rgb, 0.18);
	vec3 base = mix(arena, arena_ladera, sobre_base);
	vec3 color = mix(base, piedra, roca);

	// --- Oclusión horneada en los vértices ---
	color *= mix(1.0 - fuerza_oclusion * 0.75, 1.0, ao);

	// Praderas del recinto urbano. El puerto y las dunas conservan la arena.
	float prado = smoothstep(-300.0, -260.0, posicion_local.x)
		* (1.0 - smoothstep(32.0, 62.0, posicion_local.x))
		* (1.0 - smoothstep(108.0, 147.0, abs(posicion_local.z)))
		* (1.0 - roca);
	vec3 hierba = mix(vec3(0.07, 0.20, 0.08), vec3(0.25, 0.44, 0.15), mancha);
	ALBEDO = mix(color, hierba * (0.7 + 0.6 * dot(arena, vec3(0.33))) * ao, prado * 0.90);
	AO = mix(1.0 - fuerza_oclusion * 0.5, 1.0, ao);
	AO_LIGHT_AFFECT = 0.35;
	ROUGHNESS = mix(0.95, 0.90, roca);
	SPECULAR = 0.10;
}
