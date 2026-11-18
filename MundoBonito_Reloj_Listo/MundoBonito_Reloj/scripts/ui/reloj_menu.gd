extends VBoxContainer
## Pantalla de reloj de Mundo Bonito (Godot 4.x).
## Reemplaza exclusivamente res://scripts/ui/reloj_menu.gd.
## Se integra con menu_pausa.gd SIN modificarlo:
## menu_pausa.gd llama a construir(), abrir() y primer_foco().
## Al cerrar este reloj, se reanuda el juego con menu_pausa.continuar().
## Requiere las tres imagenes de res://assets/ui/reloj/ incluidas en el ZIP.

const IMAGEN_FONDO: Texture2D = preload("res://assets/ui/reloj/fondo_ornamental.png")
const IMAGEN_PARTICULAS: Texture2D = preload("res://assets/ui/reloj/particulas_doradas.png")
const IMAGEN_RELOJ: Texture2D = preload("res://assets/ui/reloj/reloj_colgante.png")

const PASO_MINUTOS: int = 10
const ESPERA_REPETICION: float = 0.40
const INTERVALO_REPETICION: float = 0.12
const MINUTOS_DIA: int = 1440

const ORO: Color = Color(0.98, 0.74, 0.37, 1.0)
const ORO_SUAVE: Color = Color(0.90, 0.71, 0.44, 1.0)

var _capa: CanvasLayer
var _pantalla: Control
var _velo: ColorRect
var _contenido: Control
var _reloj_visual: RelojVisual
var _flecha_izquierda: FlechaDorada
var _flecha_derecha: FlechaDorada
var _texto_hora: Label
var _boton_volver: Button
var _fuente: Font

var _primer_boton: Control
var _minutos_actuales: int = 720
var _direccion: int = 0
var _tiempo_pulsado: float = 0.0
var _tiempo_repeticion: float = 0.0
var _abierto: bool = false
var _cerrando: bool = false
var _posicion_reposo: Vector2 = Vector2.ZERO
var _animacion: Tween


func construir(fuente: Font) -> void:
	# menu_pausa.gd llama a este metodo al crear la pantalla.
	# La interfaz real vive en una capa independiente que cubre la pantalla.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fuente = fuente
	custom_minimum_size = Vector2.ZERO
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if is_instance_valid(_capa):
		return

	_capa = CanvasLayer.new()
	_capa.name = "CapaRelojCinematico"
	_capa.layer = 110
	_capa.process_mode = Node.PROCESS_MODE_ALWAYS
	# Se anade al root para poder terminar la animacion incluso despues
	# de que menu_pausa.continuar() oculte el menu de pausa.
	get_tree().root.add_child(_capa)

	_pantalla = Control.new()
	_pantalla.name = "PantallaCompleta"
	_pantalla.mouse_filter = Control.MOUSE_FILTER_STOP
	_pantalla.process_mode = Node.PROCESS_MODE_ALWAYS
	_capa.add_child(_pantalla)
	_pantalla.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_velo = ColorRect.new()
	_velo.color = Color(0.0, 0.0, 0.0, 1.0)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pantalla.add_child(_velo)
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_contenido = Control.new()
	_contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pantalla.add_child(_contenido)
	_contenido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fondo := TextureRect.new()
	fondo.name = "FondoOrnamental"
	fondo.texture = IMAGEN_FONDO
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.modulate.a = 0.66
	_contenido.add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var particulas := TextureRect.new()
	particulas.name = "BrillosDorados"
	particulas.texture = IMAGEN_PARTICULAS
	particulas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	particulas.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	particulas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particulas.modulate.a = 0.25
	var mezcla := CanvasItemMaterial.new()
	mezcla.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particulas.material = mezcla
	_contenido.add_child(particulas)
	particulas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_reloj_visual = RelojVisual.new()
	_reloj_visual.name = "RelojColgante"
	_reloj_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenido.add_child(_reloj_visual)
	_reloj_visual.construir(_fuente)

	_flecha_izquierda = FlechaDorada.new(-1)
	_flecha_derecha = FlechaDorada.new(1)
	_contenido.add_child(_flecha_izquierda)
	_contenido.add_child(_flecha_derecha)
	_flecha_izquierda.button_down.connect(_apretar.bind(-1))
	_flecha_derecha.button_down.connect(_apretar.bind(1))
	_flecha_izquierda.button_up.connect(_soltar)
	_flecha_derecha.button_up.connect(_soltar)
	_primer_boton = _flecha_izquierda

	_texto_hora = Label.new()
	_texto_hora.name = "HoraDigital"
	_texto_hora.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_hora.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_hora.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto_hora.add_theme_font_size_override("font_size", 45)
	if _fuente != null:
		_texto_hora.add_theme_font_override("font", _fuente)
	_texto_hora.add_theme_color_override("font_color", ORO)
	_texto_hora.add_theme_color_override("font_shadow_color", Color(0.6, 0.28, 0.05, 0.8))
	_texto_hora.add_theme_constant_override("shadow_offset_x", 0)
	_texto_hora.add_theme_constant_override("shadow_offset_y", 3)
	_contenido.add_child(_texto_hora)

	_boton_volver = Button.new()
	_boton_volver.name = "VolverAlJuego"
	_boton_volver.text = "VOLVER AL JUEGO  ·  ESC"
	_boton_volver.flat = true
	_boton_volver.focus_mode = Control.FOCUS_ALL
	_boton_volver.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_boton_volver.add_theme_font_size_override("font_size", 21)
	if _fuente != null:
		_boton_volver.add_theme_font_override("font", _fuente)
	_boton_volver.add_theme_color_override("font_color", ORO_SUAVE)
	_boton_volver.add_theme_color_override("font_hover_color", Color.WHITE)
	_boton_volver.add_theme_color_override("font_focus_color", Color.WHITE)
	_boton_volver.add_theme_color_override("font_pressed_color", Color.WHITE)
	var sin_caja := StyleBoxEmpty.new()
	for estado: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		_boton_volver.add_theme_stylebox_override(estado, sin_caja)
	_boton_volver.pressed.connect(_cerrar)
	_contenido.add_child(_boton_volver)

	_capa.visible = false
	get_viewport().size_changed.connect(_ubicar_interfaz)
	# Al cambiar de escena, no dejar una capa independiente abandonada.
	tree_exiting.connect(_eliminar_capa)
	call_deferred("_ubicar_interfaz")


func primer_foco() -> Control:
	return _primer_boton


func abrir() -> void:
	if not is_instance_valid(_capa):
		return
	if _animacion != null and _animacion.is_running():
		_animacion.kill()
	_abierto = true
	_cerrando = false
	_direccion = 0
	_tiempo_pulsado = 0.0
	_tiempo_repeticion = 0.0
	_flecha_izquierda.disabled = false
	_flecha_derecha.disabled = false
	_boton_volver.disabled = false

	# Se conserva la hora del juego, incluso si no cae en un multiplo de 10.
	# Cada pulsacion le suma o resta exactamente diez minutos.
	_minutos_actuales = posmod(roundi(Reloj.hora * 60.0), MINUTOS_DIA)
	_reloj_visual.poner_hora(_minutos_actuales, true)
	_actualizar_hora_digital()
	_ubicar_interfaz()

	_capa.visible = true
	_velo.color.a = 0.0
	_contenido.modulate.a = 0.0
	_reloj_visual.position.y = _posicion_reposo.y - get_viewport_rect().size.y * 1.3

	_animacion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animacion.tween_property(_velo, "color:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE)
	_animacion.tween_property(_contenido, "modulate:a", 1.0, 0.42)
	_animacion.parallel().tween_property(
		_reloj_visual, "position:y", _posicion_reposo.y, 1.08
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _input(event: InputEvent) -> void:
	if not _abierto:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		_cerrar()
		get_viewport().set_input_as_handled()
	elif not _cerrando and event.is_action_pressed("ui_left"):
		_apretar(-1)
		_soltar()
		get_viewport().set_input_as_handled()
	elif not _cerrando and event.is_action_pressed("ui_right"):
		_apretar(1)
		_soltar()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _abierto or _cerrando or _direccion == 0:
		return
	_tiempo_pulsado += delta
	if _tiempo_pulsado < ESPERA_REPETICION:
		return
	_tiempo_repeticion += delta
	while _tiempo_repeticion >= INTERVALO_REPETICION:
		_tiempo_repeticion -= INTERVALO_REPETICION
		_cambiar(_direccion * PASO_MINUTOS)


func _apretar(direccion: int) -> void:
	if not _abierto or _cerrando:
		return
	_direccion = direccion
	_tiempo_pulsado = 0.0
	_tiempo_repeticion = 0.0
	_cambiar(direccion * PASO_MINUTOS)


func _soltar() -> void:
	_direccion = 0
	_tiempo_pulsado = 0.0
	_tiempo_repeticion = 0.0


func _cambiar(cantidad_minutos: int) -> void:
	_minutos_actuales = posmod(_minutos_actuales + cantidad_minutos, MINUTOS_DIA)
	# Usa el autoload existente. No crea un segundo ciclo dia/noche.
	Reloj.saltar_a_hora(float(_minutos_actuales) / 60.0)
	_reloj_visual.poner_hora(_minutos_actuales)
	_actualizar_hora_digital()


func _actualizar_hora_digital() -> void:
	var horas: int = _minutos_actuales / 60
	var minutos: int = _minutos_actuales % 60
	_texto_hora.text = "%02d:%02d" % [horas, minutos]


func _cerrar() -> void:
	if not _abierto or _cerrando:
		return
	_cerrando = true
	_soltar()
	_flecha_izquierda.disabled = true
	_flecha_derecha.disabled = true
	_boton_volver.disabled = true
	if _animacion != null and _animacion.is_running():
		_animacion.kill()

	_animacion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animacion.tween_property(
		_reloj_visual, "position:y", _posicion_reposo.y - get_viewport_rect().size.y * 1.3, 0.52
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_animacion.parallel().tween_property(_contenido, "modulate:a", 0.0, 0.48)
	# Bajo el negro, se oculta el menu de pausa y se reanuda el mundo.
	_animacion.tween_callback(_reanudar_mundo)
	# El fondo negro se disuelve y deja ver de nuevo el juego.
	_animacion.tween_property(_velo, "color:a", 0.0, 0.42)
	_animacion.tween_callback(_terminar_cierre)


func _reanudar_mundo() -> void:
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo.has_method("continuar"):
			nodo.call("continuar")
			return
		nodo = nodo.get_parent()
	# Respaldo por si se reutiliza esta pantalla fuera de menu_pausa.gd.
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _terminar_cierre() -> void:
	_capa.visible = false
	_abierto = false
	_cerrando = false


func _ubicar_interfaz() -> void:
	if not is_instance_valid(_capa) or not is_instance_valid(_reloj_visual):
		return
	var v: Vector2 = get_viewport_rect().size
	if v.x <= 0.0 or v.y <= 0.0:
		return
	var ancho_reloj: float = clampf(minf(v.y * 0.52, v.x * 0.39), 220.0, 680.0)
	var alto_reloj: float = ancho_reloj * 394.0 / 160.0
	# Centro de la esfera real dentro del recorte de la fotografia.
	var centro_foto_y: float = 293.0 / 394.0
	_posicion_reposo = Vector2(
		(v.x - ancho_reloj) * 0.5,
		v.y * 0.49 - alto_reloj * centro_foto_y
	)
	_reloj_visual.size = Vector2(ancho_reloj, alto_reloj)
	_reloj_visual.position = _posicion_reposo

	var distancia_flechas: float = maxf(200.0, ancho_reloj * 0.73)
	var lado: float = clampf(v.y * 0.085, 60.0, 96.0)
	_flecha_izquierda.size = Vector2(lado, lado)
	_flecha_derecha.size = Vector2(lado, lado)
	_flecha_izquierda.position = Vector2(v.x * 0.5 - distancia_flechas - lado * 0.5, v.y * 0.49 - lado * 0.5)
	_flecha_derecha.position = Vector2(v.x * 0.5 + distancia_flechas - lado * 0.5, v.y * 0.49 - lado * 0.5)

	_texto_hora.add_theme_font_size_override("font_size", roundi(clampf(v.y * 0.040, 24.0, 54.0)))
	_texto_hora.size = Vector2(minf(450.0, v.x * 0.5), 80.0)
	_texto_hora.position = Vector2(
		(v.x - _texto_hora.size.x) * 0.5,
		minf(v.y - 125.0, v.y * 0.49 + (43.0 / 160.0) * ancho_reloj + 75.0)
	)

	_boton_volver.size = Vector2(290.0, 55.0)
	_boton_volver.position = Vector2(maxf(10.0, v.x - 315.0), v.y - 80.0)


func _eliminar_capa() -> void:
	if is_instance_valid(_capa):
		_capa.queue_free()


# -----------------------------------------------------------------------------
# Flechas doradas. Son botones reales con foco y se pueden mantener pulsados.
# -----------------------------------------------------------------------------
class FlechaDorada extends Button:
	var _sentido: int = 1

	func _init(sentido: int = 1) -> void:
		_sentido = sentido
		custom_minimum_size = Vector2(60.0, 60.0)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_ALL
		var vacio := StyleBoxEmpty.new()
		for estado: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(estado, vacio)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var brillo: bool = is_hovered() or has_focus() or button_pressed
		var fuerza: float = 1.0 if brillo else 0.73
		var tono := Color(1.0, 0.72, 0.32, fuerza)
		var punta := Vector2(float(_sentido) * size.x * 0.24, 0.0)
		var base_arriba := Vector2(-float(_sentido) * size.x * 0.15, -size.y * 0.25)
		var base_abajo := Vector2(-float(_sentido) * size.x * 0.15, size.y * 0.25)
		var vertices := PackedVector2Array([c + punta, c + base_arriba, c + base_abajo])
		if brillo:
			draw_colored_polygon(vertices, Color(1.0, 0.64, 0.18, 0.24))
		draw_polyline(PackedVector2Array([vertices[0], vertices[1], vertices[2], vertices[0]]), tono, 3.0, true)
		var marco := PackedVector2Array([
			c + Vector2(0.0, -size.y * 0.45),
			c + Vector2(size.x * 0.42, 0.0),
			c + Vector2(0.0, size.y * 0.45),
			c + Vector2(-size.x * 0.42, 0.0),
			c + Vector2(0.0, -size.y * 0.45)
		])
		draw_polyline(marco, Color(0.80, 0.51, 0.22, fuerza * 0.55), 1.7, true)


# -----------------------------------------------------------------------------
# Fotografia del reloj + caratula superpuesta con manecillas dinamicas.
# El recorte es un AtlasTexture: se usan los PNG originales, sin editarlos.
# -----------------------------------------------------------------------------
class RelojVisual extends Control:
	var _caratula: Caratula

	func construir(fuente: Font) -> void:
		var recorte := AtlasTexture.new()
		recorte.atlas = IMAGEN_RELOJ
		recorte.region = Rect2(174.0, 0.0, 160.0, 394.0)

		var foto := TextureRect.new()
		foto.name = "FotografiaRecortada"
		foto.texture = recorte
		foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		foto.stretch_mode = TextureRect.STRETCH_SCALE
		foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Descartamos en pantalla el fondo negro del PNG para que se vea
		# la decoracion y el polvo dorado a traves de los espacios vacios.
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
void fragment() {
    vec4 pixel = texture(TEXTURE, UV) * COLOR;
    float luz = max(pixel.r, max(pixel.g, pixel.b));
    float visibilidad = smoothstep(0.035, 0.16, luz);
    COLOR = vec4(pixel.rgb, pixel.a * visibilidad);
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		foto.material = material
		add_child(foto)
		foto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		_caratula = Caratula.new()
		_caratula.fuente = fuente
		_caratula.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_caratula)
		_caratula.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func poner_hora(minutos: int, instantaneo: bool = false) -> void:
		if _caratula != null:
			_caratula.poner_hora(minutos, instantaneo)


class Caratula extends Control:
	const ROMANOS := ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
	var fuente: Font
	var _angulo_hora: float = -PI * 0.5
	var _angulo_minuto: float = -PI * 0.5
	var _objetivo_hora: float = -PI * 0.5
	var _objetivo_minuto: float = -PI * 0.5

	func poner_hora(minutos: int, instantaneo: bool = false) -> void:
		var horas: float = float(minutos) / 60.0
		_objetivo_hora = fposmod(horas, 12.0) / 12.0 * TAU - PI * 0.5
		_objetivo_minuto = fposmod(float(minutos), 60.0) / 60.0 * TAU - PI * 0.5
		if instantaneo:
			_angulo_hora = _objetivo_hora
			_angulo_minuto = _objetivo_minuto
		queue_redraw()

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var velocidad: float = minf(1.0, delta * 11.0)
		_angulo_hora = lerp_angle(_angulo_hora, _objetivo_hora, velocidad)
		_angulo_minuto = lerp_angle(_angulo_minuto, _objetivo_minuto, velocidad)
		queue_redraw()

	func _draw() -> void:
		# Coordenadas de la esfera dentro del recorte (174,0,160,394).
		var escala: float = size.x / 160.0
		var c := Vector2((254.0 - 174.0) * escala, (294.0 / 394.0) * size.y)
		var r: float = 43.0 * escala
		if r < 1.0:
			return
		# Tapa las manecillas originales de la fotografia y reconstruye la
		# esfera en alta resolucion; las agujas dibujadas SI pueden girar.
		draw_circle(c, r * 1.02, Color(0.39, 0.28, 0.15))
		draw_circle(c, r * 0.975, Color(0.88, 0.80, 0.61))
		draw_circle(c, r * 0.91, Color(0.96, 0.88, 0.69))
		draw_arc(c, r * 0.92, 0.0, TAU, 100, Color(0.33, 0.23, 0.13, 0.8), maxf(1.0, escala * 0.45), true)
		draw_arc(c, r * 0.64, 0.0, TAU, 100, Color(0.45, 0.31, 0.14, 0.65), maxf(1.0, escala * 0.28), true)
		for i in range(60):
			var direccion := Vector2.from_angle(float(i) / 60.0 * TAU - PI * 0.5)
			var mayor := i % 5 == 0
			var desde := r * (0.85 if mayor else 0.89)
			var hasta := r * 0.93
			draw_line(c + direccion * desde, c + direccion * hasta, Color(0.26, 0.16, 0.09, 0.85), maxf(1.0, escala * (0.55 if mayor else 0.24)), true)
		var tipo: Font = fuente if fuente != null else get_theme_default_font()
		if tipo != null:
			var tamano: int = maxi(11, roundi(r * 0.21))
			for i in range(12):
				var romano: String = ROMANOS[i]
				var direccion := Vector2.from_angle(float(i) / 12.0 * TAU - PI * 0.5)
				var p := c + direccion * (r * 0.76)
				var medida := tipo.get_string_size(romano, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano)
				draw_string(tipo, p + Vector2(-medida.x * 0.5, tamano * 0.34), romano, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color(0.23, 0.14, 0.09))

		_dibujar_aguja(c, _angulo_hora, r * 0.49, r * 0.055)
		_dibujar_aguja(c, _angulo_minuto, r * 0.69, r * 0.032)
		draw_circle(c, r * 0.067, Color(0.21, 0.12, 0.05))
		draw_circle(c, r * 0.039, Color(0.83, 0.60, 0.27))

	func _dibujar_aguja(c: Vector2, angulo: float, largo: float, ancho: float) -> void:
		var rumbo := Vector2.from_angle(angulo)
		var normal := rumbo.orthogonal()
		var puntos := PackedVector2Array([
			c - rumbo * (largo * 0.18),
			c + rumbo * (largo * 0.25) + normal * ancho,
			c + rumbo * largo,
			c + rumbo * (largo * 0.25) - normal * ancho
		])
		draw_colored_polygon(puntos, Color(0.22, 0.13, 0.065))
		var trazo := puntos.duplicate()
		trazo.append(puntos[0])
		draw_polyline(trazo, Color(0.60, 0.39, 0.16), maxf(1.0, ancho * 0.20), true)
