extends VBoxContainer
## Mundo Bonito - Reloj 3D (v9): evita que la cadena se recorte al caer.
## REEMPLAZA: res://scripts/ui/reloj_menu.gd
## Sin PNG: fondo, ornamentacion y transicion construidos mediante codigo y shaders.
## Sin cambios en menu_pausa.gd, reloj.gd ni el modelo GLB.
## Muestra exclusivamente el GLB de res://assets/models/reloj_steampunk_3d.glb.

const MODELO_3D: String = "res://assets/models/reloj_steampunk_3d.glb"
const PASO_MINUTOS: int = 10
const MINUTOS_DIA: int = 1440
const ESPERA_MANTENER: float = 0.42
const INTERVALO_REPETICION: float = 0.13
const ORO: Color = Color(0.98, 0.75, 0.40)

var _capa: CanvasLayer
var _pantalla: Control
var _velo: ColorRect
var _interfaz: Control
var _fondo: ColorRect
var _particulas: CPUParticles2D
var _ornamento: OrnamentoDinamico
var _emblema_fondo: EmblemaFondo
var _transicion: Control
var _polvo_transicion: NubeDorada
var _sombra_transicion: ColorRect
var _visor: Visor3D
var _izquierda: FlechaDorada
var _derecha: FlechaDorada
var _hora_digital: Label
var _fuente: Font

var _minutos: int = 720
var _direccion: int = 0
var _tiempo_pulsado: float = 0.0
var _tiempo_repeticion: float = 0.0
var _abierto: bool = false
var _cerrando: bool = false
var _puede_cambiar: bool = false
var _posicion_reloj: Vector2 = Vector2.ZERO
var _tween: Tween


# Interfaz publica requerida por menu_pausa.gd.
func construir(fuente: Font) -> void:
	_fuente = fuente
	process_mode = Node.PROCESS_MODE_ALWAYS
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	custom_minimum_size = Vector2.ZERO
	if is_instance_valid(_capa):
		return

	# La capa vive en el root, por delante del menu de pausa.
	# Asi sigue visible durante el fundido de salida al reanudar el juego.
	_capa = CanvasLayer.new()
	_capa.name = "Reloj3DCinematico"
	_capa.layer = 110
	_capa.process_mode = Node.PROCESS_MODE_ALWAYS
	# MenuPausa puede llamar construir() mientras Godot crea los nodos en _ready.
	# Anadir a root de forma diferida evita ERR_INVALID_PARAMETER:
	# "Parent node is busy setting up children".
	get_tree().root.add_child.call_deferred(_capa)

	_pantalla = Control.new()
	_pantalla.mouse_filter = Control.MOUSE_FILTER_STOP
	_pantalla.process_mode = Node.PROCESS_MODE_ALWAYS
	_capa.add_child(_pantalla)
	_pantalla.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_velo = ColorRect.new()
	_velo.color = Color(0.0, 0.0, 0.0, 0.0)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pantalla.add_child(_velo)
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_interfaz = Control.new()
	_interfaz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pantalla.add_child(_interfaz)
	_interfaz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Primera referencia: fondo arcano casi negro, con luz inferior,
	# patron de rombos y filigranas. Todo calculado por GPU (sin PNG).
	_fondo = ColorRect.new()
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_fondo := Shader.new()
	shader_fondo.code = """
shader_type canvas_item;

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rombos(vec2 p) {
    vec2 f = abs(fract(p) - vec2(0.5));
    float d = f.x + f.y;
    return smoothstep(0.44, 0.464, d) - smoothstep(0.480, 0.506, d);
}

void fragment() {
    vec2 uv = UV;
    vec2 c = uv - vec2(0.5, 0.48);
    float r = length(c * vec2(1.34, 1.0));
    float brillo_centro = exp(-r*r * 12.5);
    float ascua = exp(-pow((uv.y - 1.07) / 0.31, 2.0));
    float oscuridad_arriba = 1.0 - smoothstep(0.14, 0.85, uv.y);
    float latido = 0.93 + 0.07*sin(TIME * 0.37);
    vec3 color = vec3(0.003, 0.003, 0.004);
    color += vec3(0.047, 0.026, 0.012) * brillo_centro * latido;
    color += vec3(0.115, 0.078, 0.040) * ascua * 0.72;
    color += vec3(0.010, 0.008, 0.006) * oscuridad_arriba;

    // Geometria repetida del tapiz de la primera imagen: rombos y cruces.
    float mascara_tapiz = smoothstep(0.32, 0.72, uv.y);
    float tejido = rombos(uv * vec2(70.0, 37.0));
    float interior = rombos(uv * vec2(70.0, 37.0) + vec2(0.5));
    float juntas = rombos(uv * vec2(35.0, 18.5));
    color += vec3(0.15, 0.12, 0.088) *
             (tejido * 0.30 + interior * 0.12 + juntas * 0.10) * mascara_tapiz;

    // Destellos diminutos en el cielo, sin textura de estrellas externa.
    vec2 q = uv * vec2(83.0, 49.0);
    vec2 id = floor(q);
    vec2 f = fract(q);
    vec2 centro = vec2(hash12(id + 12.1), hash12(id + 7.3));
    float estrella = 1.0 - smoothstep(0.008, 0.034, length(f-centro));
    float prob = step(0.972, hash12(id + 28.7));
    float parpadeo = 0.72 + 0.28*sin(TIME * 0.73 + hash12(id)*6.283);
    color += vec3(0.42, 0.26, 0.09) * estrella * prob * parpadeo;
    COLOR = vec4(color, 1.0);
}
"""
	var material_fondo := ShaderMaterial.new()
	material_fondo.shader = shader_fondo
	_fondo.material = material_fondo
	_interfaz.add_child(_fondo)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Filigrana central con lineas y curvas reales, dibujadas por _draw.
	_emblema_fondo = EmblemaFondo.new()
	_emblema_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interfaz.add_child(_emblema_fondo)
	_emblema_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Particulas VIVAS: nacen, se desplazan y desaparecen solas.
	_particulas = CPUParticles2D.new()
	_particulas.name = "PolvoDoradoVivo"
	_particulas.amount = 105
	_particulas.lifetime = 7.5
	_particulas.preprocess = 7.5
	_particulas.explosiveness = 0.0
	_particulas.randomness = 0.65
	_particulas.direction = Vector2(0.0, -1.0)
	_particulas.spread = 180.0
	_particulas.gravity = Vector2(0.0, -3.0)
	_particulas.initial_velocity_min = 2.0
	_particulas.initial_velocity_max = 18.0
	_particulas.scale_amount_min = 0.10
	_particulas.scale_amount_max = 0.45
	_particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particulas.emitting = true
	_particulas.texture = _crear_textura_particula()
	_interfaz.add_child(_particulas)

	# Anillo de runas y trazos metalicos procedurales, animados lentamente.
	_ornamento = OrnamentoDinamico.new()
	_ornamento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interfaz.add_child(_ornamento)

	# MODELO 3D REAL: no se dibuja otra esfera encima ni se usa PNG.
	_visor = Visor3D.new()
	_visor.name = "ModeloRelojOriginal3D"
	_visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interfaz.add_child(_visor)

	_izquierda = FlechaDorada.new(-1)
	_derecha = FlechaDorada.new(1)
	_interfaz.add_child(_izquierda)
	_interfaz.add_child(_derecha)
	_izquierda.button_down.connect(_apretar.bind(-1))
	_derecha.button_down.connect(_apretar.bind(1))
	_izquierda.button_up.connect(_soltar)
	_derecha.button_up.connect(_soltar)

	_hora_digital = _crear_etiqueta(43, ORO)
	_hora_digital.name = "HoraDigital"
	_interfaz.add_child(_hora_digital)
	# Sin etiquetas de ayuda ni boton inferior: flechas + hora solamente.

	# Transicion 100% geometrica. No hay texturas, particulas con quads,
	# ni shaders con celdas. Los destellos son circulos transparentes reales.
	# Asi desaparecen las placas/cuadrados visibles de las versiones 5 y 6.
	_transicion = Control.new()
	_transicion.name = "TransicionSinCuadrados"
	_transicion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pantalla.add_child(_transicion)
	_transicion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sombra_transicion = ColorRect.new()
	_sombra_transicion.name = "SombraUniforme"
	_sombra_transicion.color = Color(0.014, 0.006, 0.002, 0.82)
	_sombra_transicion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transicion.add_child(_sombra_transicion)
	_sombra_transicion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_polvo_transicion = NubeDorada.new()
	_polvo_transicion.name = "DestellosGeometricosMoviles"
	_polvo_transicion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transicion.add_child(_polvo_transicion)
	_polvo_transicion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_transicion.visible = false
	_transicion.modulate.a = 0.0

	_capa.visible = false
	get_viewport().size_changed.connect(_reacomodar)
	tree_exiting.connect(_liberar_capa)
	call_deferred("_reacomodar")


func _activar_tormenta() -> void:
	_transicion.visible = true
	_polvo_transicion.reiniciar()


func _desactivar_tormenta() -> void:
	_transicion.visible = false


func _crear_etiqueta(tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_shadow_color", Color(0.3, 0.13, 0.04, 0.8))
	etiqueta.add_theme_constant_override("shadow_offset_x", 0)
	etiqueta.add_theme_constant_override("shadow_offset_y", 2)
	if _fuente != null:
		etiqueta.add_theme_font_override("font", _fuente)
	return etiqueta


func _crear_textura_particula() -> GradientTexture2D:
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	degradado.colors = PackedColorArray([
		Color(1.0, 0.89, 0.61, 0.9),
		Color(1.0, 0.64, 0.22, 0.55),
		Color(0.85, 0.30, 0.06, 0.15),
		Color(0.55, 0.20, 0.02, 0.0)
	])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.width = 24
	textura.height = 24
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(0.5, 0.0)
	return textura


func primer_foco() -> Control:
	return _izquierda


func abrir() -> void:
	if not is_instance_valid(_capa):
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	_abierto = true
	_cerrando = false
	_puede_cambiar = false
	_soltar()
	_minutos = posmod(roundi(Reloj.hora * 60.0), MINUTOS_DIA)
	_visor.poner_hora_inicial(_minutos)
	_actualizar_hora()
	_reacomodar()
	_capa.visible = true
	_velo.color.a = 0.0
	_interfaz.modulate.a = 0.0
	_activar_tormenta()
	_transicion.modulate.a = 0.0

	# No aparece el modelo de golpe: empieza fuera de la pantalla,
	# mientras el mundo se apaga y la nube se mueve por encima.
	var y_desde: float = -_visor.size.y - get_viewport_rect().size.y*0.16
	_visor.position = Vector2(_posicion_reloj.x, y_desde)
	_izquierda.modulate.a = 0.0
	_derecha.modulate.a = 0.0
	_hora_digital.modulate.a = 0.0
	_ornamento.modulate.a = 0.0

	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Etapa 1: negro progresivo + destellos que ya estan moviendose.
	_tween.tween_property(_velo, "color:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(_transicion, "modulate:a", 0.98, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.13)
	# Etapa 2: fondo revelado bajo las particulas. El reloj desciende
	# DESDE arriba durante el mismo intervalo; sin cortes ni pantallazos.
	_tween.tween_property(_interfaz, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(_transicion, "modulate:a", 0.0, 1.43).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_callback(_visor.iniciar_caida).set_delay(0.16)
	# No usar TRANS_BACK aqui: esa curva rebasa y=0, desplaza TODO el visor 3D
	# hacia abajo y crea un hueco visible sobre la cadena. El rebote del
	# reloj ya lo simula Visor3D.iniciar_caida() sin mover el visor.
	_tween.parallel().tween_property(_visor, "position:y", _posicion_reloj.y, 1.34).set_delay(0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_ornamento, "modulate:a", 1.0, 0.80).set_delay(0.34)
	_tween.parallel().tween_property(_izquierda, "modulate:a", 1.0, 0.52).set_delay(0.88)
	_tween.parallel().tween_property(_derecha, "modulate:a", 1.0, 0.52).set_delay(0.88)
	_tween.parallel().tween_property(_hora_digital, "modulate:a", 1.0, 0.52).set_delay(0.88)
	_tween.tween_callback(_desactivar_tormenta)
	_tween.tween_callback(_habilitar_controles)


func _habilitar_controles() -> void:
	_puede_cambiar = true


func _input(event: InputEvent) -> void:
	if not _abierto:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		_cerrar()
		get_viewport().set_input_as_handled()
	elif _puede_cambiar and not _cerrando and event.is_action_pressed("ui_left"):
		_apretar(-1)
		_soltar()
		get_viewport().set_input_as_handled()
	elif _puede_cambiar and not _cerrando and event.is_action_pressed("ui_right"):
		_apretar(1)
		_soltar()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _abierto or _cerrando or not _puede_cambiar or _direccion == 0:
		return
	_tiempo_pulsado += delta
	if _tiempo_pulsado < ESPERA_MANTENER:
		return
	_tiempo_repeticion += delta
	while _tiempo_repeticion >= INTERVALO_REPETICION:
		_tiempo_repeticion -= INTERVALO_REPETICION
		_cambiar(_direccion * PASO_MINUTOS)


func _apretar(sentido: int) -> void:
	if not _abierto or _cerrando or not _puede_cambiar:
		return
	_direccion = sentido
	_tiempo_pulsado = 0.0
	_tiempo_repeticion = 0.0
	_cambiar(sentido * PASO_MINUTOS)


func _soltar() -> void:
	_direccion = 0
	_tiempo_pulsado = 0.0
	_tiempo_repeticion = 0.0


func _cambiar(diferencia: int) -> void:
	_minutos = posmod(_minutos + diferencia, MINUTOS_DIA)
	# Se sigue usando el AnimationPlayer del ciclo dia/noche original.
	Reloj.saltar_a_hora(float(_minutos) / 60.0)
	_visor.avanzar_minutos(diferencia)
	_actualizar_hora()
	_visor.empujar_reloj(signi(diferencia))


func _actualizar_hora() -> void:
	var horas: int = int(_minutos / 60)
	var minutos: int = _minutos % 60
	_hora_digital.text = "%02d:%02d" % [horas, minutos]


func _cerrar() -> void:
	if not _abierto or _cerrando:
		return
	_cerrando = true
	_puede_cambiar = false
	_soltar()
	if _tween != null and _tween.is_running():
		_tween.kill()
	_activar_tormenta()
	_transicion.modulate.a = 0.0
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# La nube tapa gradualmente el reloj mientras sube, nunca un corte.
	_tween.tween_property(_transicion, "modulate:a", 0.98, 0.73).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(_visor, "position:y", -_visor.size.y - get_viewport_rect().size.y*0.16, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_interfaz, "modulate:a", 0.0, 0.89).set_trans(Tween.TRANS_SINE)
	# Se reanuda el juego aun cubierto por el velo negro.
	_tween.tween_callback(_reanudar_juego)
	_tween.tween_property(_velo, "color:a", 0.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(_transicion, "modulate:a", 0.0, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_terminar_cierre)


func _reanudar_juego() -> void:
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo.has_method("continuar"):
			nodo.call("continuar")
			return
		nodo = nodo.get_parent()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _terminar_cierre() -> void:
	_desactivar_tormenta()
	_capa.visible = false
	_abierto = false
	_cerrando = false


func _reacomodar() -> void:
	if not is_instance_valid(_capa) or not is_instance_valid(_visor):
		return
	var v: Vector2 = get_viewport_rect().size
	if v.x < 1.0 or v.y < 1.0:
		return
	var alto_reloj: float = clampf(v.y * 0.76, 300.0, 950.0)
	var ancho_reloj: float = alto_reloj * 0.80
	if ancho_reloj > v.x * 0.50:
		ancho_reloj = v.x * 0.50
		alto_reloj = ancho_reloj / 0.80
	_visor.size = Vector2(ancho_reloj, alto_reloj)
	# El visor anterior empezaba unos pixeles por debajo del borde superior.
	# Aunque la cadena 3D tenga 42 eslabones, SubViewportContainer la recorta
	# al salir de su propio rectangulo. Lo colocamos en y=0 para que la cadena
	# llegue al borde REAL de la pantalla.
	var margen_anterior: float = maxf(0.0, (v.y - alto_reloj) * 0.50 - v.y * 0.04)
	_posicion_reloj = Vector2((v.x - ancho_reloj) * 0.5, 0.0)
	# Compensacion optica: el reloj permanece en la misma posicion que en v7.
	_visor.compensar_margen_superior(margen_anterior, alto_reloj)
	_visor.position = _posicion_reloj

	var lado_runa: float = clampf(v.y * 0.70, 300.0, 850.0)
	_ornamento.size = Vector2(lado_runa, lado_runa)
	# Acompana el ligero descenso aparente del reloj dentro del visor.
	_ornamento.position = v * 0.5 - _ornamento.size * 0.5 + Vector2(0.0, v.y * 0.025)

	_particulas.position = v * 0.5
	_particulas.emission_rect_extents = v * 0.50

	var lado: float = clampf(v.y * 0.075, 55.0, 95.0)
	var separacion: float = minf(v.x * 0.27, ancho_reloj * 0.73)
	_izquierda.size = Vector2(lado, lado)
	_derecha.size = Vector2(lado, lado)
	_izquierda.position = Vector2(v.x * 0.5 - separacion - lado * 0.5, v.y * 0.545 - lado * 0.5)
	_derecha.position = Vector2(v.x * 0.5 + separacion - lado * 0.5, v.y * 0.545 - lado * 0.5)

	_hora_digital.add_theme_font_size_override("font_size", roundi(clampf(v.y * 0.042, 24.0, 52.0)))
	_hora_digital.size = Vector2(minf(v.x * 0.65, 500.0), 72.0)
	_hora_digital.position = Vector2((v.x - _hora_digital.size.x) * 0.5, v.y * 0.77)


func _liberar_capa() -> void:
	if is_instance_valid(_capa):
		_capa.queue_free()


# Nube de polvo SIN QUADS: completamente vectorial, sin imagenes.
# Cada destello son circulos concentraciones de luz, nunca rectangulos.
class NubeDorada extends Control:
	const TOTAL: int = 220
	var _puntos: Array[Dictionary] = []
	var _segundos: float = 0.0
	var _azar := RandomNumberGenerator.new()

	func _init() -> void:
		_azar.seed = 917624
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_regenerar()

	func reiniciar() -> void:
		_segundos = 0.0
		_azar.seed = 917624
		_regenerar()
		queue_redraw()

	func _regenerar() -> void:
		_puntos.clear()
		for i in range(TOTAL):
			var profundidad: float = _azar.randf_range(0.4, 1.7)
			# Mas puntos en la mitad superior, como en la referencia.
			var fy: float = pow(_azar.randf(), 1.55)
			_puntos.append({
				"x": _azar.randf(),
				"y": fy,
				"vx": _azar.randf_range(-0.009, 0.010) * profundidad,
				"vy": _azar.randf_range(-0.010, -0.032) * profundidad,
				"radio": _azar.randf_range(0.65, 2.5) * profundidad,
				"brillo": _azar.randf_range(0.30, 0.84),
				"fase": _azar.randf_range(0.0, TAU),
				"frecuencia": _azar.randf_range(0.5, 2.3),
			})

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var dt: float = minf(delta, 0.05)
		_segundos += dt
		for d in _puntos:
			var fx: float = float(d["x"]) + float(d["vx"]) * dt
			var fy: float = float(d["y"]) + float(d["vy"]) * dt
			if fy < -0.06:
				fy += 1.13
			if fx < -0.06:
				fx += 1.13
			if fx > 1.06:
				fx -= 1.13
			d["x"] = fx
			d["y"] = fy
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		# Color liso transparente por debajo: no hay shader de ruido,
		# ni un sprite cuadrado que pueda dejar bordes en la pantalla.
		for d in _puntos:
			var fx: float = float(d["x"])
			var fy: float = float(d["y"])
			var p := Vector2(fx * size.x, fy * size.y)
			var r: float = float(d["radio"]) * clampf(size.y / 930.0, 0.5, 1.6)
			var flicker: float = 0.80 + 0.20 * sin(_segundos * float(d["frecuencia"]) + float(d["fase"]))
			var a: float = float(d["brillo"]) * flicker
			# Suave bokeh hecho de halos circulares, no texturas ni rectangulos.
			draw_circle(p, r * 5.5, Color(0.86, 0.33, 0.045, a * 0.022))
			draw_circle(p, r * 3.2, Color(1.0, 0.48, 0.09, a * 0.054))
			draw_circle(p, r * 1.8, Color(1.0, 0.67, 0.18, a * 0.17))
			draw_circle(p, maxf(0.75, r * 0.70), Color(1.0, 0.83, 0.39, a * 0.69))


# Filigrana central inspirada en la imagen de referencia.
# Se dibuja vectorialmente: lineas, rizos, anillos y detalles que parpadean.
# No se usa ninguna textura de imagen.
class EmblemaFondo extends Control:
	var _tiempo: float = 0.0

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_tiempo += delta
			queue_redraw()

	func _curva(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
		var puntos := PackedVector2Array()
		for i in range(30):
			var t: float = float(i) / 29.0
			var u: float = 1.0-t
			var p: Vector2 = a*u*u*u + b*3.0*u*u*t + c*3.0*u*t*t + d*t*t*t
			puntos.append(p)
		return puntos

	func _draw() -> void:
		if size.x < 1.0 or size.y < 1.0:
			return
		var centro: Vector2 = size*Vector2(0.50, 0.445)
		var unidad: float = minf(size.x/1600.0, size.y/900.0)
		var pulso: float = 0.78 + 0.22*sin(_tiempo*0.42)
		var oro: Color = Color(0.55, 0.41, 0.22, 0.16*pulso)
		var oro_marcado: Color = Color(0.73, 0.51, 0.24, 0.22*pulso)
		# Eje horizontal filamentoso (visible a izquierda y derecha del 3D).
		for lado in [-1.0, 1.0]:
			var x0: float = centro.x + lado*96.0*unidad
			var x1: float = centro.x + lado*690.0*unidad
			var y: float = centro.y + 2.0*unidad
			draw_line(Vector2(x0,y), Vector2(x1,y), oro, 2.0*unidad, true)
			draw_line(Vector2(x0,y-8.0*unidad), Vector2(x1,y-8.0*unidad), Color(oro, 0.060), 1.0*unidad, true)
			# Prolongaciones asimetricas y rizos goticos.
			var a: Vector2 = centro + Vector2(lado*145.0, -12.0)*unidad
			var b: Vector2 = centro + Vector2(lado*240.0, -85.0)*unidad
			var c: Vector2 = centro + Vector2(lado*320.0, 55.0)*unidad
			var d: Vector2 = centro + Vector2(lado*490.0, -2.0)*unidad
			draw_polyline(_curva(a,b,c,d), oro, 2.0*unidad, true)
			var a2: Vector2 = centro + Vector2(lado*170.0, 22.0)*unidad
			var b2: Vector2 = centro + Vector2(lado*280.0, 105.0)*unidad
			var c2: Vector2 = centro + Vector2(lado*410.0,-38.0)*unidad
			var d2: Vector2 = centro + Vector2(lado*535.0,-4.0)*unidad
			draw_polyline(_curva(a2,b2,c2,d2), Color(oro,0.12), 1.5*unidad, true)
			for k in range(11):
				var x: float = centro.x + lado*(365.0+float(k)*30.0)*unidad
				var glifo: float = sin(float(k)*2.3)*2.0*unidad
				draw_line(Vector2(x, y-5.0*unidad+glifo),Vector2(x,y+5.0*unidad+glifo), oro_marcado, 1.0*unidad, true)
		# Medallon de fondo con marcas, casi oculto tras el reloj fisico.
		for k in range(4):
			draw_arc(centro, (90.0+float(k)*21.0)*unidad, 0.0, TAU, 90, Color(oro,0.06+0.02*float(k)), 1.3*unidad, true)
		for k in range(16):
			var t: float = float(k)*TAU/16.0
			var d: Vector2 = Vector2.from_angle(t)
			draw_line(centro+d*171.0*unidad, centro+d*183.0*unidad, Color(oro_marcado,0.12),1.0*unidad,true)
		# Pendientes metalicos que se pierden en el mosaico inferior.
		draw_line(centro+Vector2(0.0,130.0)*unidad, centro+Vector2(0.0,420.0)*unidad, Color(oro,0.12), 1.0*unidad, true)


# Flechas dibujadas por codigo; responden a hover y pulsaciones.
class FlechaDorada extends Button:
	var _sentido: int = 1
	var _tiempo: float = 0.0

	func _init(sentido: int = 1) -> void:
		_sentido = sentido
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var vacio := StyleBoxEmpty.new()
		for estado: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(estado, vacio)

	func _process(delta: float) -> void:
		_tiempo += delta
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var hover: bool = is_hovered() or has_focus() or button_pressed
		var pulso: float = 0.78 + 0.22 * sin(_tiempo * 1.9)
		var a: float = 1.0 if hover else pulso * 0.72
		var d: float = float(_sentido)
		var p1 := c + Vector2(d * size.x * 0.27, 0.0)
		var p2 := c + Vector2(-d * size.x * 0.16, -size.y * 0.23)
		var p3 := c + Vector2(-d * size.x * 0.16, size.y * 0.23)
		var puntos := PackedVector2Array([p1, p2, p3])
		if hover:
			draw_colored_polygon(puntos, Color(1.0, 0.63, 0.16, 0.22))
		draw_polyline(PackedVector2Array([p1, p2, p3, p1]), Color(1.0, 0.71, 0.32, a), 3.0, true)
		var rombo := PackedVector2Array([
			c + Vector2(0.0, -size.y * 0.40),
			c + Vector2(size.x * 0.38, 0.0),
			c + Vector2(0.0, size.y * 0.40),
			c + Vector2(-size.x * 0.38, 0.0),
			c + Vector2(0.0, -size.y * 0.40)
		])
		draw_polyline(rombo, Color(0.78, 0.47, 0.16, a * 0.60), 1.5, true)


# Ornamento 2D independiente del modelo: lineas y runas que giran de verdad.
class OrnamentoDinamico extends Control:
	var _tiempo: float = 0.0

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_tiempo += delta
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.47
		if r <= 0.0:
			return
		for k in range(3):
			var radio: float = r * (0.74 + 0.11 * float(k))
			var alpha: float = 0.20 - float(k) * 0.035
			draw_arc(c, radio, 0.0, TAU, 160, Color(0.89, 0.51, 0.18, alpha), 1.3, true)
		# Dos grupos de glifos en sentidos contrarios, discretos tras el 3D.
		for i in range(40):
			var t: float = float(i) / 40.0 * TAU + _tiempo * 0.07
			var p: Vector2 = c + Vector2.from_angle(t) * r * 0.89
			var d: Vector2 = Vector2.from_angle(t)
			var a: float = 0.12 + 0.10 * sin(_tiempo * 1.1 + float(i))
			draw_line(p - d * 7.0, p + d * 7.0, Color(1.0, 0.62, 0.22, a), 1.2, true)
			if i % 4 == 0:
				draw_line(p + d.orthogonal() * 4.0, p - d.orthogonal() * 4.0, Color(1.0, 0.68, 0.26, a), 1.1, true)
		for i in range(12):
			var t: float = float(i) / 12.0 * TAU - _tiempo * 0.05
			var p: Vector2 = c + Vector2.from_angle(t) * r * 0.77
			draw_circle(p, 1.5, Color(1.0, 0.58, 0.17, 0.35))


# Visor del modelo GLB real. La fisica de caida, cadena y agujas es 3D.
class Visor3D extends SubViewportContainer:
	const ANILLO_Y: float = 1.757
	const PIVOTE_Y: float = 2.20
	const HORA_ORIGINAL: float = 10.0 + 25.0 / 60.0

	var _pivote: Node3D
	var _camara: Camera3D
	var _manecilla_hora: Node3D
	var _manecilla_minuto: Node3D
	var _minutos_visuales: float = 720.0
	var _minutos_objetivo: float = 720.0
	var _y: float = 0.0
	var _velocidad_y: float = 0.0
	var _cayendo: bool = false
	var _angulo_z: float = 0.0
	var _velocidad_z: float = 0.0
	var _angulo_y: float = 0.0
	var _velocidad_giro: float = 0.0
	var _tiempo_idle: float = 0.0

	func _init() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _ready() -> void:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(720, 900)
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)

		# Ambiente reflejado por el metal. El 3D necesita reflejos para destacar.
		var cielo := ProceduralSkyMaterial.new()
		cielo.sky_top_color = Color(0.12, 0.07, 0.045)
		cielo.sky_horizon_color = Color(0.48, 0.30, 0.16)
		cielo.ground_horizon_color = Color(0.29, 0.16, 0.09)
		cielo.ground_bottom_color = Color(0.06, 0.03, 0.02)
		var sky := Sky.new()
		sky.sky_material = cielo
		var ambiente := Environment.new()
		ambiente.background_mode = Environment.BG_CLEAR_COLOR
		ambiente.sky = sky
		ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		ambiente.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var mundo := WorldEnvironment.new()
		mundo.environment = ambiente
		viewport.add_child(mundo)

		var principal := OmniLight3D.new()
		principal.light_color = Color(1.0, 0.74, 0.42)
		principal.light_energy = 1.35
		principal.omni_range = 12.0
		principal.position = Vector3(-2.0, 3.8, 4.2)
		viewport.add_child(principal)

		var rebote := OmniLight3D.new()
		rebote.light_color = Color(0.85, 0.91, 1.0)
		rebote.light_energy = 0.85
		rebote.omni_range = 10.0
		rebote.position = Vector3(3.0, -1.0, 3.8)
		viewport.add_child(rebote)

		var frontal := DirectionalLight3D.new()
		frontal.light_color = Color(1.0, 0.84, 0.61)
		frontal.light_energy = 0.55
		frontal.rotation_degrees = Vector3(-35.0, 23.0, 0.0)
		viewport.add_child(frontal)

		# Contraluz lateral: al oscilar se aprecia el canto y los reflejos metalicos.
		var contraluz := OmniLight3D.new()
		contraluz.light_color = Color(1.0, 0.55, 0.23)
		contraluz.light_energy = 1.2
		contraluz.omni_range = 9.0
		contraluz.position = Vector3(2.2, 1.6, -2.2)
		viewport.add_child(contraluz)

		var camara := Camera3D.new()
		camara.fov = 38.0
		camara.position = Vector3(0.55, 0.54, 6.4)
		viewport.add_child(camara)
		# Encuadre un poco mas alto: se ven mas eslabones sobre el reloj,
		# sin recortar su esfera ni desplazar las agujas del modelo.
		camara.look_at(Vector3(0.0, 0.79, 0.0), Vector3.UP)
		camara.current = true
		_camara = camara

		_pivote = Node3D.new()
		viewport.add_child(_pivote)
		# Se instancia el GLB original. No hay geometria 2D que sustituya el reloj.
		if not ResourceLoader.exists(MODELO_3D):
			push_error("Reloj 3D: falta el archivo " + MODELO_3D)
		else:
			var escena: PackedScene = load(MODELO_3D) as PackedScene
			if escena == null:
				push_error("Reloj 3D: el GLB existe pero no se pudo importar como escena: " + MODELO_3D)
			else:
				var modelo: Node3D = escena.instantiate() as Node3D
				if modelo == null:
					push_error("Reloj 3D: la raiz importada no es Node3D.")
				else:
					modelo.name = "RelojSteampunkOriginalGLB"
					modelo.position = Vector3(0.0, -ANILLO_Y, 0.0)
					_pivote.add_child(modelo)
					_manecilla_hora = modelo.find_child("HourHand", true, false) as Node3D
					_manecilla_minuto = modelo.find_child("MinuteHand", true, false) as Node3D
					var cantidad_mallas: int = modelo.find_children("*", "MeshInstance3D", true, false).size()
					print("Mundo Bonito | Reloj 3D cargado: ", MODELO_3D, " | Mallas: ", cantidad_mallas)
					if cantidad_mallas == 0:
						push_warning("Reloj 3D: GLB cargado pero no hay mallas visibles.")
					if _manecilla_hora == null or _manecilla_minuto == null:
						push_warning("Reloj 3D: no se encontraron HourHand y MinuteHand en el GLB.")
		_crear_cadena()
		_colocar()
		_actualizar_agujas()

	# Mantiene el reloj en el mismo lugar de la pantalla al llevar el visor
	# hasta y=0. Solo ajusta la camara: NO mueve, estira ni cambia el modelo GLB.
	func compensar_margen_superior(margen_px: float, alto_visor_px: float) -> void:
		if not is_instance_valid(_camara) or alto_visor_px <= 0.0:
			return
		# En una camara perspectiva, la altura visible a 6.4 unidades es:
		# 2 * distancia * tan(fov/2). Se convierte el margen antiguo a mundo 3D.
		var distancia: float = 6.4
		var altura_mundo: float = 2.0 * distancia * tan(deg_to_rad(_camara.fov * 0.5))
		var compensacion: float = margen_px / alto_visor_px * altura_mundo
		_camara.position = Vector3(0.55, 0.54 + compensacion, distancia)
		_camara.look_at(Vector3(0.0, 0.79 + compensacion, 0.0), Vector3.UP)

	func _crear_cadena() -> void:
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.75, 0.50, 0.21)
		metal.metallic = 0.85
		metal.roughness = 0.32
		# La cadena nace de la corona y continua hacia la parte superior.
		# Antes tenia 24 eslabones; ahora tiene 42.
		for i in range(42):
			var malla := TorusMesh.new()
			malla.inner_radius = 0.10
			malla.outer_radius = 0.23
			malla.rings = 20
			malla.ring_segments = 10
			var eslabon := MeshInstance3D.new()
			eslabon.mesh = malla
			eslabon.material_override = metal
			var base := Basis(Vector3.RIGHT, PI * 0.5)
			if i % 2 == 1:
				base = Basis(Vector3.UP, PI * 0.5) * base
			eslabon.basis = base
			eslabon.position = Vector3(0.0, 0.11 + float(i) * 0.30, 0.0)
			_pivote.add_child(eslabon)

	func poner_hora_inicial(minutos: int) -> void:
		_minutos_visuales = float(minutos)
		_minutos_objetivo = float(minutos)
		_actualizar_agujas()

	func avanzar_minutos(diferencia: int) -> void:
		# No usar modulo aqui: 23:50 -> 00:00 debe rotar hacia adelante.
		_minutos_objetivo += float(diferencia)

	func empujar_reloj(sentido: int) -> void:
		_velocidad_z += float(sentido) * 0.35
		_velocidad_giro += float(sentido) * 0.18

	func iniciar_caida() -> void:
		# Caida 3D mas corta: el desplazamiento principal ya ocurre en la UI.
		# Asi nunca aparece de repente cuando entra en el campo de la camara.
		_y = 1.7
		_velocidad_y = 0.0
		_cayendo = true
		_angulo_z = -0.13
		_tiempo_idle = 0.0
		_velocidad_z = 0.0
		_angulo_y = 0.06
		_velocidad_giro = 0.0
		_colocar()

	func _process(delta: float) -> void:
		if _pivote == null or not is_visible_in_tree():
			return
		var dt: float = minf(delta, 0.033)
		_tiempo_idle += dt
		# Transicion suave entre posiciones de las agujas.
		_minutos_visuales = lerpf(_minutos_visuales, _minutos_objetivo, minf(1.0, dt * 10.0))
		_actualizar_agujas()
		# Caida con gravedad y cadena tensandose al llegar al centro.
		if _cayendo:
			_velocidad_y -= 25.0 * dt
			_y += _velocidad_y * dt
			if _y <= 0.0:
				_y = 0.0
				_velocidad_y = -_velocidad_y * 0.17
				_cayendo = false
				_velocidad_z = 2.1
				_velocidad_giro = -0.95
		else:
			_velocidad_y += (-95.0 * _y - 11.0 * _velocidad_y) * dt
			_y += _velocidad_y * dt
		# Balanceo amortiguado, no un giro infinito.
		_velocidad_z += (-22.0 * _angulo_z - 4.0 * _velocidad_z) * dt
		_angulo_z += _velocidad_z * dt
		_velocidad_giro += (-18.0 * _angulo_y - 4.5 * _velocidad_giro) * dt
		_angulo_y += _velocidad_giro * dt
		_colocar()

	func _colocar() -> void:
		if _pivote != null:
			_pivote.position = Vector3(0.0, PIVOTE_Y + _y, 0.0)
			# Leve paralaje permanente: el espesor del modelo 3D queda a la vista.
			var balanceo_y: float = sin(_tiempo_idle * 0.62) * 0.11
			var balanceo_x: float = sin(_tiempo_idle * 0.45) * 0.022
			_pivote.rotation = Vector3(balanceo_x, _angulo_y + balanceo_y, _angulo_z)

	func _actualizar_agujas() -> void:
		var hora: float = _minutos_visuales / 60.0
		if _manecilla_hora != null:
			_manecilla_hora.rotation.z = -(hora - HORA_ORIGINAL) / 12.0 * TAU
		if _manecilla_minuto != null:
			_manecilla_minuto.rotation.z = -(hora - HORA_ORIGINAL) * TAU
