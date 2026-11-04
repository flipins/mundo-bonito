shader_type spatial;

// --- Arena (suelo) ---
uniform sampler2D arena_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arena_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arena_rugosidad : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tamano_textura = 4.0;
uniform float fuerza_relieve : hint_range(0.0, 3.0) = 1.0;
uniform float sentido_relieve = 1.0;
uniform vec3 tinte : source_color = vec3(1.0);

// --- Roca (paredes) ---
uniform sampler2D roca_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roca_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roca_rugosidad : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tamano_roca = 6.0;
uniform float fuerza_relieve_roca : hint_range(0.0, 3.0) = 1.0;
// 0 = solo la textura de roca, 1 = textura teñida con el color de vetas de la grieta.
uniform float mezcla_color_vetas : hint_range(0.0, 1.0) = 0.5;

// Desde qué inclinación empieza la roca de las paredes.
uniform float roca_desde = 0.03;
uniform float roca_hasta = 0.30;

varying vec3 pos_mundo;
varying vec3 normal_mundo;

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Pesos para proyectar la textura desde los tres ejes (así no se estira en las paredes).
vec3 pesos(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z);
}

void fragment() {
	vec3 n_mundo = normalize(normal_mundo);
	float pendiente = 1.0 - n_mundo.y;
	float mezcla = smoothstep(roca_desde, roca_hasta, pendiente);

	// ---- Arena ----
	vec2 uv = pos_mundo.xz / tamano_textura;
	vec3 arena = texture(arena_color, uv).rgb * tinte;
	float rug_arena = texture(arena_rugosidad, uv).r;
	vec3 na = texture(arena_normal, uv).xyz * 2.0 - 1.0;
	vec3 normal_arena = normalize(n_mundo + vec3(na.x, 0.0, na.y * sentido_relieve) * fuerza_relieve);

	// ---- Roca (triplanar) ----
	vec3 w = pesos(n_mundo);
	vec2 uv_x = pos_mundo.zy / tamano_roca;
	vec2 uv_y = pos_mundo.xz / tamano_roca;
	vec2 uv_z = pos_mundo.xy / tamano_roca;

	vec3 roca = texture(roca_color, uv_x).rgb * w.x
			  + texture(roca_color, uv_y).rgb * w.y
			  + texture(roca_color, uv_z).rgb * w.z;
	float rug_roca = texture(roca_rugosidad, uv_x).r * w.x
				   + texture(roca_rugosidad, uv_y).r * w.y
				   + texture(roca_rugosidad, uv_z).r * w.z;

	// Las vetas de color de la grieta (vienen en sRGB desde dunas.gd).
	vec3 vetas = pow(COLOR.rgb, vec3(2.2));
	roca = mix(roca, roca * vetas * 2.0, mezcla_color_vetas);

	vec3 nx = texture(roca_normal, uv_x).xyz * 2.0 - 1.0;
	vec3 ny = texture(roca_normal, uv_y).xyz * 2.0 - 1.0;
	vec3 nz = texture(roca_normal, uv_z).xyz * 2.0 - 1.0;
	vec3 desvio = vec3(0.0, nx.y, nx.x) * w.x
				+ vec3(ny.x, 0.0, ny.y) * w.y
				+ vec3(nz.x, nz.y, 0.0) * w.z;
	vec3 normal_roca = normalize(n_mundo + desvio * fuerza_relieve_roca);

	// ---- Mezcla final ----
	ALBEDO = mix(arena, roca, mezcla);
	ROUGHNESS = mix(rug_arena, rug_roca, mezcla);
	vec3 n_final = normalize(mix(normal_arena, normal_roca, mezcla));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_final, 0.0)).xyz);
}