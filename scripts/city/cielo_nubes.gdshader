shader_type sky;

// Cielo diurno con cumulos volumetricos (raymarching) para Godot 4.x
// Uso: WorldEnvironment > Environment > Sky > New Sky > Sky Material > ShaderMaterial > cargar este archivo.
// El sol sale de la direccion del DirectionalLight3D (LIGHT0). Para una foto como la referencia,
// sube el sol (rotacion X del DirectionalLight3D cerca de -50 a -65 grados).

group_uniforms cielo;
uniform vec3 color_cenit : source_color = vec3(0.10, 0.31, 0.72);
uniform vec3 color_horizonte : source_color = vec3(0.62, 0.82, 0.95);
uniform vec3 color_suelo : source_color = vec3(0.25, 0.35, 0.40);
uniform float curva_gradiente : hint_range(0.1, 2.0) = 0.5;

group_uniforms sol;
uniform vec3 color_sol : source_color = vec3(1.0, 0.95, 0.85);
uniform float tamano_sol : hint_range(0.003, 0.1) = 0.012;
uniform float brillo_sol : hint_range(0.0, 40.0) = 20.0;
uniform float brillo_halo : hint_range(0.0, 3.0) = 1.0;
uniform float rayos_sol : hint_range(0.0, 2.0) = 0.6;
uniform vec3 sol_manual = vec3(0.0, 0.6, -1.0); // se usa solo si no hay DirectionalLight3D

group_uniforms atardecer;
// Cuando el sol baja, el cielo y las nubes se tiñen de calido automaticamente. Pon 0 para desactivarlo.
uniform float tinte_atardecer : hint_range(0.0, 1.0) = 1.0;
uniform vec3 color_horizonte_atardecer : source_color = vec3(1.0, 0.62, 0.36);
uniform vec3 color_luz_atardecer : source_color = vec3(1.0, 0.72, 0.45);

group_uniforms nubes_forma;
uniform float cobertura : hint_range(0.0, 1.0) = 0.42;   // cuanta nube hay DENTRO de las zonas con nubes
uniform float agrupacion : hint_range(0.0, 1.0) = 0.7;   // 0 = nubes por todo el cielo; 1 = grupos de nubes con cielo despejado entre medio
uniform float suavidad : hint_range(0.02, 0.6) = 0.14;
uniform float detalle : hint_range(0.0, 0.6) = 0.28;        // erosion de bordes (aspecto coliflor)
uniform float escala : hint_range(0.1, 3.0) = 0.42;          // mas alto = nubes mas chicas
uniform float altura_base = 1.4;                             // donde empieza la capa de nubes
uniform float grosor : hint_range(0.3, 4.0) = 2.2;           // alto de la capa (nubes mas "torreadas")
uniform float opacidad : hint_range(0.5, 20.0) = 10.0;        // que tan densas/opacas se ven
uniform float velocidad : hint_range(0.0, 0.2) = 0.02;       // viento: desplaza las nubes
uniform float evolucion : hint_range(0.0, 0.15) = 0.02;     // cuanto cambian de forma (0 = congeladas)

group_uniforms nubes_luz;
uniform vec3 color_nube_luz : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 color_nube_sombra : source_color = vec3(0.32, 0.40, 0.56);   // base gris azulada
uniform vec3 color_nube_ambiente : source_color = vec3(0.58, 0.70, 0.93);  // luz del cielo en la cima
uniform float brillo_luz : hint_range(0.0, 6.0) = 1.5;
uniform float absorcion_luz : hint_range(0.0, 12.0) = 4.0;    // sombras internas (mas alto = mas contraste)

group_uniforms calidad;
uniform int pasos : hint_range(8, 64) = 20;       // calidad dentro de las nubes; menos = mas FPS
uniform int octavas : hint_range(2, 5) = 4;       // detalle de la forma; menos = mas FPS
uniform bool nubes_activas = true;                // false = solo gradiente de cielo (casi gratis)
uniform bool jitter_animado = true;               // true = el grano cambia cada frame y el ojo lo promedia (se ve mas suave)

group_uniforms ruido;
// Textura de ruido 3D precalculada (mucho mas barata que calcular el ruido en cada pixel).
// Cargar aqui cielo_ruido.tres (ver instrucciones).
uniform sampler3D ruido : filter_linear, repeat_enable;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// Ruido 3D leido de la textura. La textura tiene 16 celdas por lado, asi que x/16
// da celdas de 1 unidad, igual que el ruido procedural anterior.
float noise3(vec3 x) {
	return textureLod(ruido, x * (1.0 / 16.0), 0.0).r;
}

float fbm3(vec3 p, int oct) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		if (i >= oct) {
			break;
		}
		float fi = float(i);
		// Cada octava deriva en otra direccion y mas rapido cuanto mas fina:
		// las formas grandes cambian lento y los detalles "hierven" rapido.
		// El componente Y positivo simula conveccion (la nube crece hacia arriba).
		vec3 dirv = vec3(sin(fi * 2.1 + 1.0), 0.6 + 0.4 * cos(fi * 1.3), cos(fi * 1.7 + 2.0));
		vec3 off = dirv * (TIME * evolucion * (0.3 + fi * 0.7));
		v += a * noise3(p + off);
		p = p * 2.03 + vec3(11.7, 5.3, 8.9);
		a *= 0.5;
	}
	return v;
}

// Mascara de gran escala: decide DONDE hay zonas con nubes y donde cielo despejado.
// Devuelve 1 en zonas con nubes y 0 en zonas despejadas.
float mascara(vec3 q) {
	float m = noise3(vec3(q.x * 0.2, 3.7 + TIME * evolucion * 0.3, q.z * 0.2));
	return mix(1.0, smoothstep(0.35, 0.65, m), agrupacion);
}

// Densidad de nube en un punto del espacio (0 = vacio, 1 = nube densa)
float densidad(vec3 p, int oct) {
	float hf = clamp((p.y - altura_base) / grosor, 0.0, 1.0);
	// base plana, cima redondeada
	float perfil = smoothstep(0.0, 0.12, hf) * smoothstep(1.0, 0.45, hf);
	vec3 q = p * escala + vec3(TIME * velocidad, 0.0, TIME * velocidad * 0.5);
	float n = fbm3(q, oct);
	// erosion de alta frecuencia: muerde los bordes y crea relieve
	if (oct >= 3) {
		n -= (1.0 - noise3(q * 5.0 + vec3(3.1, 7.7, 1.3) + vec3(0.3, 0.5, -0.2) * (TIME * evolucion * 3.0))) * detalle * (1.0 - perfil * 0.5);
	}
	n *= perfil * mascara(q);
	float umbral = 0.78 - cobertura * 0.55;
	return smoothstep(umbral, umbral + suavidad, n);
}

float hg(float c, float g) {
	float g2 = g * g;
	return (1.0 - g2) / (12.566 * pow(1.0 + g2 - 2.0 * g * c, 1.5));
}

// Salto de espacio vacio: cota conservadora. Si ni sumando el maximo posible de las
// octavas que faltan hay nube, el punto esta vacio y nos ahorramos el calculo completo.
// No cambia el aspecto de las nubes, solo evita trabajo inutil.
bool vacio(vec3 p) {
	vec3 q = p * escala + vec3(TIME * velocidad, 0.0, TIME * velocidad * 0.5);
	float m = mascara(q);
	if (m <= 0.001) {
		return true; // zona de cielo despejado: no hace falta calcular nada mas
	}
	float hf = clamp((p.y - altura_base) / grosor, 0.0, 1.0);
	float perfil = smoothstep(0.0, 0.12, hf) * smoothstep(1.0, 0.45, hf);
	float n = fbm3(q, 2) + 0.25 * (1.0 - pow(0.5, float(octavas - 2)));
	return n * perfil * m <= 0.78 - cobertura * 0.55;
}

// Raymarching de la capa de nubes. Devuelve (luz acumulada rgb, transmitancia en a).
// Avanza con pasos grandes por el aire vacio y con pasos finos dentro de las nubes:
// asi se gasta calidad solo donde hay nube (menos grano, menos costo).
vec4 nubes(vec3 dir, vec3 sun_dir, vec3 c_luz, float jit) {
	float h = dir.y;
	float T = 1.0;
	vec3 scat = vec3(0.0);

	float t0 = altura_base / h;
	float t1 = (altura_base + grosor) / h;
	float paso = (t1 - t0) / float(pasos); // paso fino (dentro de nubes)
	float grueso = paso * 2.5;             // paso grande (en el vacio)
	float fase = 0.45 + 1.2 * hg(dot(dir, sun_dir), 0.6); // brillo hacia el sol

	float t = t0 + jit * grueso;
	for (int i = 0; i < 96; i++) {
		if (t > t1 || T < 0.03) {
			break;
		}
		vec3 p = dir * t;
		if (vacio(p)) {
			t += grueso;
			continue;
		}
		float d = densidad(p, octavas);
		// Pasos mas finos en los bordes de la nube (densidad baja): ahi estaba el punteado
		float dt = paso * mix(0.45, 1.0, smoothstep(0.0, 0.35, d));

		if (d > 0.005) {
			// Cuanta nube hay entre este punto y el sol
			float ls = 0.0;
			ls += densidad(p + sun_dir * 0.3, 2);
			ls += densidad(p + sun_dir * 0.9, 2);
			float k = ls * absorcion_luz * 0.55;
			float trans_sol = max(exp(-k), exp(-k * 0.2) * 0.45);

			float hf = clamp((p.y - altura_base) / grosor, 0.0, 1.0);
			vec3 ambiente = mix(color_nube_sombra, color_nube_ambiente, pow(hf, 0.7));
			vec3 c = c_luz * brillo_luz * trans_sol * fase + ambiente;

			float a = 1.0 - exp(-d * opacidad * dt);
			scat += T * a * c;
			T *= (1.0 - a);
		}
		t += dt;
	}
	return vec4(scat, T);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(sol_manual);

	float h = dir.y;
	float sd = max(dot(dir, sun_dir), 0.0);

	// Tinte calido cuando el sol esta bajo
	float atard = (1.0 - smoothstep(0.05, 0.45, sun_dir.y)) * tinte_atardecer;
	vec3 c_hor = mix(color_horizonte, color_horizonte_atardecer, atard);
	vec3 c_luz = mix(color_nube_luz, color_luz_atardecer, atard);

	vec3 col;

	if (h >= 0.0) {
		// Gradiente del cielo
		col = mix(c_hor, color_cenit, pow(clamp(h, 0.0, 1.0), curva_gradiente));

		// Halo y disco solar
		col += color_sol * (pow(sd, 6.0) * 0.25 + pow(sd, 64.0) * 0.6) * brillo_halo;
		float disco = smoothstep(cos(tamano_sol * 1.5), cos(tamano_sol), sd);
		col += color_sol * disco * brillo_sol;

		// Las nubes no se dibujan en el cubemap de reflejos/ambiente (es caro)
		float Te = 1.0;
		if (!AT_CUBEMAP_PASS && nubes_activas && h > 0.02) {
			float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
			if (jitter_animado) {
				jit = fract(jit + fract(TIME * 61.8033));
			}
			vec4 r = nubes(dir, sun_dir, c_luz, jit);
			float fade = smoothstep(0.05, 0.32, h);
			Te = mix(1.0, r.a, fade);
			col = col * Te + r.rgb * fade;
		}

		// Brillo del sol que "sangra" por encima de las nubes
		col += color_sol * pow(sd, 24.0) * 0.25 * brillo_halo;

		// Rayos radiales alrededor del sol
		vec3 ref = abs(sun_dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
		vec3 tx = normalize(cross(sun_dir, ref));
		vec3 ty = cross(sun_dir, tx);
		float ang = atan(dot(dir, ty), dot(dir, tx));
		float rr = (sin(ang * 5.0 + 0.7) * 0.5 + 0.5) * (sin(ang * 11.0 + 1.7) * 0.5 + 0.5);
		col += color_sol * (0.2 + rr) * pow(sd, 10.0) * 0.35 * rayos_sol * (0.4 + 0.6 * Te);
	} else {
		// Bajo el horizonte
		col = mix(c_hor * 0.9, color_suelo, smoothstep(0.0, -0.35, h));
	}

	COLOR = col;
}