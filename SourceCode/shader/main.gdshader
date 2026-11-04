shader_type sky;

// =====================================================================================
// Cielo con ciclo día/noche + noche de fantasía (estrellas y dos lunas).
// El cielo de DÍA es el mismo de antes: las capas nuevas solo aparecen con la noche.
// Cada capa tiene su interruptor en el grupo "Night Layers" del material.
// =====================================================================================

group_uniforms Sky;
uniform vec4 sky_day : source_color = vec4(0.0,0.3,0.7,1.0);
uniform vec4 horizon_day : source_color = vec4(0.75,0.85,0.85,1.0);
uniform vec4 horizon_sunset : source_color = vec4(0.9,0.4,0.1,1.0);
uniform vec4 sky_sunset : source_color = vec4(0.15, 0.2, 0.4, 1.0);
uniform vec4 horizon_night : source_color = vec4(0.1, 0.15, 0.2, 1.0);
uniform vec4 sky_night : source_color = vec4(0.05, 0.10, 0.15, 1.0);
uniform float day_night_mix : hint_range(-1.0, 1.0, 0.1) = 0.8;
uniform bool use_directional_light = true;
uniform float horizon_exponent = 2.0;
uniform float sunset_amount_exponent = 0.7;
uniform float night_amount_exponent = 4.0;

group_uniforms Clouds;
uniform sampler2D cloud_tex_01;
uniform sampler2D cloud_tex_02;
uniform vec4 cloud_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec2 cloud_tiling = vec2(1.0);
uniform vec2 wind_speed = vec2(0.5);
uniform float cloud_density : hint_range(0.0, 5.0, 0.1) = 0.7;
uniform float cloud_depth = 2.0;
uniform float cloud_shape_exponent = 2.0;
uniform float cloud_occlude_exponent = 1.0;
// Nubes con volumen
uniform float cloud_thickness : hint_range(0.05, 1.5, 0.01) = 0.4;      // grosor del banco de nubes
uniform float cloud_height_gain : hint_range(0.5, 6.0, 0.1) = 2.5;      // altura de cada nube: sube para más relieve y volumen
uniform float cloud_opacity : hint_range(0.5, 10.0, 0.1) = 2.0;         // qué tan densas/opacas son por dentro
uniform float cloud_light_boost : hint_range(0.0, 4.0, 0.05) = 1.4;     // brillo de las partes iluminadas
uniform float cloud_dark_amount : hint_range(0.0, 1.0, 0.01) = 0.25;    // oscuridad de las partes en sombra
uniform float cloud_shadow : hint_range(0.0, 1.5, 0.01) = 1.2;          // cuánta sombra se hacen a sí mismas
uniform float cloud_light_reach : hint_range(0.0, 0.3, 0.005) = 0.06;   // alcance de la sombra hacia la luz

group_uniforms Stars;
uniform sampler2D night_noise_02;

group_uniforms Sun;
uniform float sun_scale = 0.05;
uniform float sun_strength = 15.0;
uniform vec4 sun_color : source_color = vec4(1.0,0.9,0.0,1.0);

group_uniforms Night_Layers;
uniform bool enable_stars = true;
uniform bool enable_big_moon = true;
uniform bool enable_small_moon = true;
// Mismos valores que altura_noche_total (-0.4) y 0.04 de ciclo_dia.gd, para que todo anochezca a la vez.
uniform float night_full : hint_range(-1.0, 0.0, 0.01) = -0.4;
uniform float night_start : hint_range(-0.2, 0.3, 0.01) = 0.04;

group_uniforms Starfield;
uniform float star_brightness : hint_range(0.0, 5.0, 0.05) = 1.0;
// Multiplica el tamaño de todas las estrellas (1.0 = pequeñas por defecto).
uniform float star_size : hint_range(0.3, 3.0, 0.05) = 1.0;
uniform float star_scale_small = 95.0;
uniform float star_density_small : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float star_scale_big = 36.0;
uniform float star_density_big : hint_range(0.0, 1.0, 0.01) = 0.06;
// Velocidad del parpadeo.
uniform float twinkle_speed : hint_range(0.0, 8.0, 0.1) = 2.0;
// Giro lento de todo el campo de estrellas (radianes por segundo). 0 = quietas.
uniform float star_drift_speed : hint_range(0.0, 0.05, 0.0005) = 0.004;
uniform vec4 star_color_a : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform vec4 star_color_b : source_color = vec4(0.55, 0.95, 1.0, 1.0);
uniform vec4 star_color_c : source_color = vec4(1.0, 0.70, 0.90, 1.0);

group_uniforms Moons;
uniform float moon_brightness : hint_range(0.0, 8.0, 0.1) = 2.0;
// Tamaño = radio angular aproximado en radianes (0.10 ≈ 5.7°).
uniform float big_moon_size : hint_range(0.01, 0.4, 0.005) = 0.10;
uniform vec4 big_moon_color : source_color = vec4(0.55, 0.90, 1.0, 1.0);
uniform vec4 big_moon_rim : source_color = vec4(0.70, 1.0, 1.0, 1.0);
// Dirección de la luz sobre la luna (en su propio plano: x derecha, y arriba, z hacia ti). Define la fase.
uniform vec3 big_moon_light = vec3(-0.5, 0.4, 0.75);
uniform float big_moon_halo_size : hint_range(0.01, 0.5, 0.005) = 0.12;
uniform float big_moon_halo_strength : hint_range(0.0, 3.0, 0.05) = 0.6;

uniform float small_moon_size : hint_range(0.01, 0.4, 0.005) = 0.055;
uniform vec4 small_moon_color : source_color = vec4(0.80, 0.60, 1.0, 1.0);
uniform vec4 small_moon_rim : source_color = vec4(0.90, 0.75, 1.0, 1.0);
uniform vec3 small_moon_light = vec3(0.6, -0.3, 0.7);
uniform float small_moon_halo_size : hint_range(0.01, 0.5, 0.005) = 0.08;
uniform float small_moon_halo_strength : hint_range(0.0, 3.0, 0.05) = 0.5;
// La luna chica orbita rotando a la grande alrededor de este eje. Donde el eje apunta
// cerca de la luna grande, se acercan (eclipse); lejos, se separan. Cambia estos valores para ajustar cuándo se cruzan.
uniform vec3 small_moon_axis = vec3(0.2, 0.85, 0.45);
uniform float small_moon_angle : hint_range(0.0, 1.5, 0.01) = 0.35;
// Solo se usa si "use_directional_light" está apagado.
uniform vec3 moon_fallback_dir = vec3(0.3, 0.7, 0.65);


// ------------------------------------------------------------------------------------
// Utilidades
// ------------------------------------------------------------------------------------

float plane_intersection(vec3 origin, vec3 normal, vec3 ray_start, vec3 ray_dir) {
	return dot(origin - ray_start, normal) / dot(ray_dir, normal);
}

float get_cloud_height(sampler2D tex, vec2 uv) {
	float height = texture(tex, uv).r;
	height = clamp((height - (1.0 - cloud_density)) / (cloud_density), 0.0, 1.0);
	return pow(height, cloud_shape_exponent);
}

float cloud_field(vec2 uv1, vec2 uv2) {
	float h1 = get_cloud_height(cloud_tex_01, uv1);
	float h2 = get_cloud_height(cloud_tex_02, uv2);
	return min(h1, h1 * h2);
}

// Banco de nubes con grosor: se recorre en capas desde la base hasta la cima. Cada capa se ilumina
// mirando si hay nube más alta hacia la luz (sombra propia): bordes claros, bases y centros oscuros.
// Devuelve vec4(color ya multiplicado por la opacidad, opacidad).
vec4 volumetric_clouds(vec3 dir, vec2 wind, vec3 light_dir, vec3 lit_col, vec3 dark_col, int steps) {
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	vec2 tile = cloud_tiling * 0.2;
	vec2 light_off = light_dir.xz / max(light_dir.y, 0.3) * cloud_light_reach;
	float n = float(steps);
	for (int i = 0; i < 6; i++) {
		if (i >= steps) {
			break;
		}
		float h = (float(i) + 0.5) / n;
		float y = 1.0 + h * cloud_thickness;
		vec2 base_uv = dir.xz * (y / dir.y) * tile;
		vec2 uv1 = base_uv + wind;
		vec2 uv2 = base_uv + wind * 0.5;
		float c = clamp(cloud_field(uv1, uv2) * cloud_height_gain, 0.0, 1.0);
		float dens = clamp((c - h * 0.8) / 0.2, 0.0, 1.0);
		if (dens > 0.001) {
			float cl = clamp(cloud_field(uv1 + light_off, uv2 + light_off) * cloud_height_gain, 0.0, 1.0);
			float occ = clamp((cl - h * 0.8) / 0.2, 0.0, 1.0);
			float lit = clamp(1.0 - occ * cloud_shadow, 0.0, 1.0);
			vec3 c_i = mix(dark_col, lit_col, lit);
			float a = clamp(dens * cloud_opacity / n, 0.0, 1.0);
			col += (1.0 - alpha) * a * c_i;
			alpha += (1.0 - alpha) * a;
		}
	}
	return vec4(col, alpha);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float fbm(vec3 p) {
	float amp = 0.5;
	float sum = 0.0;
	for (int i = 0; i < 4; i++) {
		sum += amp * vnoise(p);
		p = p * 2.03 + vec3(11.7, 3.1, 7.3);
		amp *= 0.5;
	}
	return sum;
}

vec3 rotate_around(vec3 v, vec3 axis, float ang) {
	float c = cos(ang);
	float s = sin(ang);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}


// ------------------------------------------------------------------------------------
// Estrellas: celdas 3D sobre la dirección de la vista (sin costuras).
// Pequeñas y nítidas; las "medianas" llevan una cruz corta. Cada una parpadea a su propio
// ritmo y todo el campo gira muy despacio.
// ------------------------------------------------------------------------------------

vec3 star_layer(vec3 dir, float scale, float density, float size, float spikes, float seed, float time) {
	vec3 p = dir * scale + vec3(seed);
	vec3 cell = floor(p);
	vec3 f = fract(p);

	float present = step(1.0 - density, hash13(cell + vec3(17.0)));
	if (present < 0.5) {
		return vec3(0.0);
	}

	vec3 h = hash33(cell);
	vec3 v = f - (vec3(0.5) + (h - 0.5) * 0.3);
	float rnd = hash13(cell + vec3(5.0));
	float k = hash13(cell + vec3(9.0));

	// Parpadeo: cada estrella con su propia velocidad y fase.
	float rate = 0.6 + hash13(cell + vec3(23.0)) * 1.2;
	float tw = 0.55 + 0.45 * sin(time * twinkle_speed * rate + rnd * 60.0);

	// Brillo muy variable (muchas tenues, pocas brillantes) y tamaño casi constante.
	float mag = 0.2 + 0.8 * pow(hash13(cell + vec3(41.0)), 2.5);
	if (spikes > 0.0) {
		mag = 0.35 + 0.35 * mag;
	}
	float r = size * star_size * (0.7 + 0.5 * rnd) * (0.9 + 0.1 * tw);
	float d = length(v);
	float s = pow(1.0 - smoothstep(0.0, r, d), 2.0) * mag;

	if (spikes > 0.0) {
		// Cruz corta y fina: un brazo horizontal y otro vertical en el cielo.
		vec3 t1 = normalize(cross(dir, vec3(0.0, 0.0, 1.0)) + vec3(0.00001));
		vec3 t2 = cross(dir, t1);
		vec2 q = vec2(dot(v, t1), dot(v, t2));
		float depth = abs(dot(v, dir));
		float len = 0.10 * star_size * (0.7 + 0.3 * tw);
		float th = r * 0.5;
		float arms = (1.0 - smoothstep(0.0, len, abs(q.x))) * exp(-abs(q.y) / th)
				   + (1.0 - smoothstep(0.0, len, abs(q.y))) * exp(-abs(q.x) / th);
		s += arms * spikes * 0.5 * mag * (1.0 - smoothstep(0.0, 0.3, depth));
	}

	vec3 col = mix(mix(star_color_a.rgb, star_color_b.rgb, step(0.5, k)), star_color_c.rgb, step(0.8, k));
	return col * s * tw;
}

vec3 starfield(vec3 dir, float time) {
	// Giro lento del cielo estrellado.
	vec3 d = rotate_around(dir, normalize(vec3(0.3, 0.9, 0.3)), time * star_drift_speed);
	vec3 s = star_layer(d, star_scale_small, star_density_small, 0.08, 0.0, 0.0, time);
	s += star_layer(d, star_scale_big, star_density_big, 0.04, 1.0, 31.0, time);
	return s * star_brightness;
}


// ------------------------------------------------------------------------------------
// Lunas: halo aditivo + disco opaco con fase, superficie y borde iluminado.
// ------------------------------------------------------------------------------------

vec3 moon_halo(vec3 dir, vec3 mdir, float r, vec3 col, float size, float strength) {
	float d = length(dir - mdir);
	return col * exp(-max(d - r, 0.0) / size) * strength;
}

// Devuelve vec4(color, máscara del disco).
vec4 moon_disc(vec3 dir, vec3 mdir, float r, vec3 col, vec3 rim_col, vec3 light_local, float brightness) {
	vec3 dv = dir - mdir;
	float d = length(dv);
	float mask = 1.0 - smoothstep(r * 0.95, r, d);
	if (mask <= 0.0) {
		return vec4(0.0);
	}

	// Plano local de la luna (eje de referencia X: no se degenera con el recorrido del sol).
	vec3 right = normalize(vec3(0.0, -mdir.z, mdir.y) + vec3(0.00001));
	vec3 up = cross(mdir, right);
	vec2 p = vec2(dot(dv, right), dot(dv, up)) / r;
	float z = sqrt(max(1.0 - dot(p, p), 0.0));
	vec3 n = vec3(p, z);

	float lit = dot(n, normalize(light_local));
	float diff = smoothstep(-0.2, 0.6, lit);

	float tex = fbm(n * 2.2 + vec3(3.0));
	float fine = fbm(n * 7.0);
	float albedo = mix(0.45, 1.0, smoothstep(0.35, 0.65, tex)) * (0.8 + 0.4 * fine);

	float rim = pow(1.0 - z, 3.0) * clamp(lit + 0.6, 0.0, 1.0);
	vec3 c = col * albedo * (0.2 + 0.8 * diff) * brightness + rim_col * rim * brightness;
	return vec4(c, mask);
}


// ------------------------------------------------------------------------------------

void sky() {
	float t = plane_intersection(vec3(0.0, 1.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(0.0), EYEDIR);

	float blend = day_night_mix;
	if (use_directional_light) {
		blend = LIGHT0_DIRECTION.y;
	}

	// 0 = pleno día, 1 = noche cerrada (misma curva que ciclo_dia.gd).
	float night = 1.0 - smoothstep(night_full, night_start, blend);

	vec3 sky = vec3(0.0);
	vec3 horizon_color = vec3(0.0);
	vec3 sky_color = vec3(0.0);

	// Dirección de la luna (opuesta al sol) y luz que ilumina las nubes: sol de día, luna de noche.
	vec3 moon_dir = normalize(moon_fallback_dir);
	if (use_directional_light) {
		moon_dir = -normalize(LIGHT0_DIRECTION);
	}
	vec3 sun_dir = -moon_dir;
	float moon_mix = smoothstep(0.1, 0.7, night);
	vec3 cloud_light_dir = normalize(mix(sun_dir, moon_dir, moon_mix) + vec3(0.0, 0.25, 0.0));
	float sunset_amount = (1.0 - clamp(blend * 4.0, 0.0, 1.0)) * (1.0 - moon_mix);
	vec3 warm = mix(vec3(1.0), horizon_sunset.rgb * 1.3, sunset_amount);
	vec3 cloud_lit_col = cloud_color.rgb * cloud_light_boost * warm + big_moon_color.rgb * 0.12 * moon_mix;
	vec3 cloud_dark_col = cloud_color.rgb * cloud_dark_amount * vec3(0.8, 0.9, 1.1);

	float cloud_value = 0.0;
	vec3 cloud_rgb = vec3(0.0);
	if (EYEDIR.y > 0.005) {
		vec2 wind_uv = wind_speed * TIME * 0.1;
		int cloud_steps = 6;
		if (AT_CUBEMAP_PASS) {
			cloud_steps = 2;
		}
		vec4 cl = volumetric_clouds(EYEDIR, wind_uv, cloud_light_dir, cloud_lit_col, cloud_dark_col, cloud_steps);
		float cloud_fade = smoothstep(0.0, 0.2, EYEDIR.y);
		cloud_value = cl.a * cloud_fade;
		cloud_rgb = cl.rgb * cloud_fade;
	}

	// Sol (sin cambios)
	float sun_distance = clamp(1.0 - distance(EYEDIR, LIGHT0_DIRECTION) - pow(cloud_value, cloud_occlude_exponent), 0.0, 1.0);
	float sun_disc = clamp(smoothstep(1.0 - sun_scale, 1.0, sun_distance), 0.0, 1.0);
	float sun_glow = clamp(0.0, 1.0, (pow(sun_distance, 4.0) * 0.07));
	vec3 sun = mix(vec3(0.0), sun_color.rgb * sun_strength, max(sun_disc, sun_glow));

	// Colores del cielo (sin cambios)
	float night_noise = texture(night_noise_02, (EYEDIR / ((1.0 - abs(t) * 0.05))).xz).r;

	horizon_color = mix(horizon_sunset, horizon_day, clamp(blend, 0.0, 1.0)).rgb;
	horizon_color = mix(horizon_night.rgb, horizon_color, pow(clamp(1.0 + blend, 0.0, 1.0), 4.0)).rgb;

	vec3 sky_night_mix = sky_night.rgb * (night_noise * 0.5 + 0.5);
	sky_color = mix(sky_sunset, sky_day, clamp(blend, 0.0, 1.0)).rgb;
	sky_color = mix(sky_night_mix, sky_color, clamp(pow(1.0 + blend, 4.0), 0.0, 1.0)).rgb;

	sky = mix(sky_color, horizon_color, pow(1.0 - abs(EYEDIR.y), horizon_exponent));
	sky = sky * (1.0 - cloud_value) + cloud_rgb;

	sky = mix(sky, mix(sky_color * 0.5, horizon_color, EYEDIR.y + 1.0).rgb, clamp(pow(1.0 - EYEDIR.y, 2.0), 0.0, 1.0));

	// --- Capa de noche: estrellas (no se pintan bajo nubes ni bajo el horizonte) ---
	float open_sky = clamp(1.0 - cloud_value * 2.0, 0.0, 1.0);
	if (night > 0.001) {
		if (enable_stars) {
			sky += starfield(EYEDIR, TIME) * night * open_sky * smoothstep(0.0, 0.1, EYEDIR.y);
		}
	}

	if (use_directional_light) {
		sky += sun * clamp(pow(EYEDIR.y + 1.0, 16.0), 0.0, 1.0);
	}

	// --- Lunas: la grande va opuesta al sol; la chica orbita a su alrededor y puede taparla ---
	float moon_vis = smoothstep(0.02, 0.5, night) * (1.0 - clamp(cloud_value * 1.2, 0.0, 1.0)) * smoothstep(-0.08, 0.02, EYEDIR.y);
	if (moon_vis > 0.001) {
		if (enable_big_moon) {
			sky += moon_halo(EYEDIR, moon_dir, big_moon_size, big_moon_color.rgb, big_moon_halo_size, big_moon_halo_strength) * moon_vis;
			vec4 big = moon_disc(EYEDIR, moon_dir, big_moon_size, big_moon_color.rgb, big_moon_rim.rgb, big_moon_light, moon_brightness);
			sky = mix(sky, big.rgb, big.a * moon_vis);
		}
		if (enable_small_moon) {
			vec3 small_dir = rotate_around(moon_dir, normalize(small_moon_axis), small_moon_angle);
			sky += moon_halo(EYEDIR, small_dir, small_moon_size, small_moon_color.rgb, small_moon_halo_size, small_moon_halo_strength) * moon_vis;
			vec4 small = moon_disc(EYEDIR, small_dir, small_moon_size, small_moon_color.rgb, small_moon_rim.rgb, small_moon_light, moon_brightness);
			sky = mix(sky, small.rgb, small.a * moon_vis);
		}
	}

	COLOR = sky;
}
