extends Control
## Escena que se carga con "Nueva partida" (el juego de verdad: el desierto).
@export_file("*.tscn") var escena_juego: String = "res://addons/scenes/world/desierto.tscn"
@export_file("*.tscn") var escena_pruebas: String = "res://addons/scenes/world/node_3d.tscn"
@export_file("*.tscn") var escena_fondo: String = "res://addons/scenes/menus/fondo_menu.tscn"
## Título que se muestra arriba (se pasa a mayúsculas solo)
@export var titulo_juego: String = "Título del juego"
## Letra del menú. Si este archivo no existe se usa una letra fina del sistema (Segoe UI Light).
## Para una letra propia: baja un .ttf fino (por ejemplo Montserrat Light o Lato Light),
## ponlo en una carpeta "fuentes" y cambia esta ruta.
@export_file("*.ttf", "*.otf") var archivo_fuente: String = "res://fuentes/menu.ttf"
## Qué tan oscura es la franja de la izquierda detrás del texto (0 = nada, 1 = casi negra).
## El cielo del fondo es muy claro: si el texto no se lee bien, sube este valor.
@export_range(0.0, 1.0, 0.05) var oscurecer_izquierda: float = 0.75
## Audio del menú.
@export_file("*.ogg", "*.mp3", "*.wav") var archivo_musica: String = "res://assets/audio/ambiente_desierto.wav"
@export_file("*.ogg", "*.mp3", "*.wav") var archivo_hover: String = "res://assets/audio/ui_click.mp3"
@export_file("*.ogg", "*.mp3", "*.wav") var archivo_click: String = "res://assets/audio/ui_click.mp3"

const COLOR_TEXTO := Color(1.0, 0.97, 0.90, 1.0)
const COLOR_APAGADO := Color(0.93, 0.85, 0.72, 0.8)

var _interfaz: Control
var _lista_principal: VBoxContainer
var _lista_ajustes: VBoxContainer
var _boton_jugar: Button
var _slider_volumen: HSlider
var _slider_ambiente: HSlider
var _slider_efectos: HSlider
var _slider_sensibilidad: HSlider
var _cortina: ColorRect
var _fuente_titulo: Font
var _fuente_item: Font
var _cargando: bool = false
var _musica: AudioStreamPlayer
var _sfx_hover: AudioStreamPlayer
var _sfx_click: AudioStreamPlayer


func _ready() -> void:
	# El juego captura el mouse; en el menú lo necesitamos visible.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_fuente_titulo = _crear_fuente(6)
	_fuente_item = _crear_fuente(3)
	_crear_fondo()
	_crear_interfaz()
	_crear_audio()
	_entrada_suave()
func _crear_audio() -> void:
	# Cada sonido va a su bus: los sliders de Ajustes regulan el bus, y volumen_db sigue siendo
	# el balance fino entre sonidos (el bus se suma a ese valor).
	_musica = _crear_reproductor(archivo_musica, -12.0, AjustesAudio.BUS_AMBIENTE)
	if _musica != null:
		_musica.play()
	_sfx_hover = _crear_reproductor(archivo_hover, -20.0, AjustesAudio.BUS_EFECTOS)
	_sfx_click = _crear_reproductor(archivo_click, -6.0, AjustesAudio.BUS_EFECTOS)


func _crear_reproductor(ruta: String, volumen_db: float, bus: String) -> AudioStreamPlayer:
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		push_warning("PantallaTitulo: no se encontró el audio '%s'." % ruta)
		return null
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = load(ruta)
	reproductor.volume_db = volumen_db
	reproductor.bus = bus
	add_child(reproductor)
	return reproductor


func _sonido_hover() -> void:
	if _sfx_hover != null:
		_sfx_hover.play()


func _sonido_click() -> void:
	if _sfx_click != null:
		_sfx_click.play()

func _unhandled_input(event: InputEvent) -> void:
	# Esc dentro de Ajustes vuelve al menú.
	if _lista_ajustes.visible and event.is_action_pressed("ui_cancel"):
		_on_volver()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Construcción

func _crear_fondo() -> void:
	if escena_fondo != "" and ResourceLoader.exists(escena_fondo):
		var escena := load(escena_fondo) as PackedScene
		if escena != null:
			add_child(escena.instantiate())
			return
	push_warning("PantallaTitulo: no se encontró el fondo '%s'; se usa un color liso." % escena_fondo)
	var liso := ColorRect.new()
	liso.color = Color(0.10, 0.07, 0.05)
	add_child(liso)
	liso.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _crear_interfaz() -> void:
	# Un degradado oscuro y cálido a la izquierda para que el texto se lea sobre el cielo claro.
	# Es más fuerte donde está el texto y se desvanece hacia la espada.
	var tono := Color(0.08, 0.04, 0.02)
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	degradado.colors = PackedColorArray([
		Color(tono.r, tono.g, tono.b, oscurecer_izquierda),
		Color(tono.r, tono.g, tono.b, oscurecer_izquierda * 0.55),
		Color(tono.r, tono.g, tono.b, 0.0),
	])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill = GradientTexture2D.FILL_LINEAR
	textura.fill_from = Vector2(0.0, 0.5)
	textura.fill_to = Vector2(0.75, 0.5)
	textura.width = 256
	textura.height = 16
	var sombra := TextureRect.new()
	sombra.texture = textura
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Margen izquierdo y superior: la columna de texto queda arriba a la izquierda.
	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_theme_constant_override("margin_left", 130)
	margen.add_theme_constant_override("margin_top", 150)
	add_child(margen)
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interfaz = margen

	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(columna)

	var titulo := _crear_etiqueta(titulo_juego.to_upper(), 62, COLOR_TEXTO, _fuente_titulo)
	columna.add_child(titulo)

	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0.0, 64.0)
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(espacio)

	_lista_principal = VBoxContainer.new()
	_lista_principal.add_theme_constant_override("separation", 6)
	columna.add_child(_lista_principal)
	_boton_jugar = _agregar_boton(_lista_principal, "Nueva partida", _on_jugar)
	_agregar_boton(_lista_principal, "Zona de pruebas", _on_pruebas)
	_agregar_boton(_lista_principal, "Ajustes", _mostrar_ajustes)
	_agregar_boton(_lista_principal, "Salir", _on_salir)

	_crear_ajustes(columna)

	# Cortina negra encima de todo, para entrar y salir con un fundido.
	_cortina = ColorRect.new()
	_cortina.color = Color(0.0, 0.0, 0.0, 1.0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)
	_cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_boton_jugar.grab_focus()


func _crear_ajustes(columna: Control) -> void:
	_lista_ajustes = VBoxContainer.new()
	_lista_ajustes.add_theme_constant_override("separation", 10)
	_lista_ajustes.visible = false
	columna.add_child(_lista_ajustes)

	_lista_ajustes.add_child(_crear_etiqueta("AJUSTES", 34, COLOR_TEXTO, _fuente_item))
	_lista_ajustes.add_child(_crear_espacio(10.0))

	_lista_ajustes.add_child(_crear_etiqueta("VOLUMEN", 22, COLOR_APAGADO, _fuente_item))
	_slider_volumen = _crear_slider(0.0, 1.0, 0.05, Ajustes.volumen)
	_slider_volumen.value_changed.connect(_on_volumen_cambiado)
	_lista_ajustes.add_child(_slider_volumen)

	_lista_ajustes.add_child(_crear_espacio(8.0))
	_lista_ajustes.add_child(_crear_etiqueta("AMBIENTE", 22, COLOR_APAGADO, _fuente_item))
	_slider_ambiente = _crear_slider(0.0, 1.0, 0.05, AjustesAudio.get_volumen(AjustesAudio.BUS_AMBIENTE))
	_slider_ambiente.value_changed.connect(_on_ambiente_cambiado)
	_lista_ajustes.add_child(_slider_ambiente)

	_lista_ajustes.add_child(_crear_espacio(8.0))
	_lista_ajustes.add_child(_crear_etiqueta("EFECTOS", 22, COLOR_APAGADO, _fuente_item))
	_slider_efectos = _crear_slider(0.0, 1.0, 0.05, AjustesAudio.get_volumen(AjustesAudio.BUS_EFECTOS))
	_slider_efectos.value_changed.connect(_on_efectos_cambiado)
	# Al soltar el slider suena el click, para escuchar el nivel que quedó.
	_slider_efectos.drag_ended.connect(_on_efectos_soltado)
	_lista_ajustes.add_child(_slider_efectos)

	_lista_ajustes.add_child(_crear_espacio(8.0))
	_lista_ajustes.add_child(_crear_etiqueta("SENSIBILIDAD DEL MOUSE", 22, COLOR_APAGADO, _fuente_item))
	_slider_sensibilidad = _crear_slider(0.2, 3.0, 0.1, Ajustes.sensibilidad)
	_slider_sensibilidad.value_changed.connect(_on_sensibilidad_cambiada)
	_lista_ajustes.add_child(_slider_sensibilidad)

	_lista_ajustes.add_child(_crear_espacio(18.0))
	_agregar_boton(_lista_ajustes, "Volver", _on_volver)


# Un elemento del menú: texto en mayúsculas, sin fondo; se enciende al pasar el mouse o con el teclado.
func _agregar_boton(padre: Control, texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto.to_upper()
	boton.flat = true
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.focus_mode = Control.FOCUS_ALL
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.add_theme_font_override("font", _fuente_item)
	boton.add_theme_font_size_override("font_size", 30)
	boton.add_theme_color_override("font_color", COLOR_APAGADO)
	boton.add_theme_color_override("font_hover_color", COLOR_TEXTO)
	boton.add_theme_color_override("font_focus_color", COLOR_TEXTO)
	boton.add_theme_color_override("font_pressed_color", COLOR_TEXTO)
	boton.add_theme_color_override("font_hover_pressed_color", COLOR_TEXTO)

	# Sin cajas ni bordes: solo texto. Los márgenes de arriba y abajo agrandan la zona de clic.
	var vacio := StyleBoxEmpty.new()
	vacio.content_margin_top = 7.0
	vacio.content_margin_bottom = 7.0
	for estilo: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		boton.add_theme_stylebox_override(estilo, vacio)

	# Pasar el mouse por encima también lo selecciona (así solo hay uno encendido a la vez).
	boton.mouse_entered.connect(boton.grab_focus)
	boton.pressed.connect(accion)
	boton.focus_entered.connect(_sonido_hover)
	boton.pressed.connect(_sonido_click)
	padre.add_child(boton)
	return boton


func _crear_etiqueta(texto: String, tamano: int, color: Color, fuente: Font) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	# Una sombra suave ayuda a que la letra fina no se pierda contra el cielo.
	etiqueta.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	etiqueta.add_theme_constant_override("shadow_offset_x", 0)
	etiqueta.add_theme_constant_override("shadow_offset_y", 2)
	return etiqueta


func _crear_espacio(alto: float) -> Control:
	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0.0, alto)
	espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return espacio


# Slider minimalista: una línea fina y una perilla redonda.
func _crear_slider(minimo: float, maximo: float, paso: float, valor: float) -> HSlider:
	var slider := HSlider.new()
	# Primero el rango y el paso, después el valor.
	slider.min_value = minimo
	slider.max_value = maximo
	slider.step = paso
	slider.value = valor
	slider.custom_minimum_size = Vector2(380.0, 28.0)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slider.add_theme_stylebox_override("slider", _crear_linea(Color(1.0, 1.0, 1.0, 0.28)))
	slider.add_theme_stylebox_override("grabber_area", _crear_linea(COLOR_TEXTO))
	slider.add_theme_stylebox_override("grabber_area_highlight", _crear_linea(Color(1.0, 1.0, 1.0, 1.0)))
	var perilla := _crear_perilla(Color(0.96, 0.93, 0.88, 1.0))
	slider.add_theme_icon_override("grabber", perilla)
	slider.add_theme_icon_override("grabber_highlight", perilla)
	slider.add_theme_icon_override("grabber_disabled", perilla)
	return slider


func _crear_linea(color: Color) -> StyleBoxFlat:
	var linea := StyleBoxFlat.new()
	linea.bg_color = color
	linea.set_corner_radius_all(1)
	# El grosor de la línea sale de los márgenes de arriba y abajo: 1 + 1 = 2 píxeles.
	linea.content_margin_top = 1.0
	linea.content_margin_bottom = 1.0
	return linea


func _crear_perilla(color: Color) -> ImageTexture:
	var tam: int = 18
	var imagen := Image.create_empty(tam, tam, false, Image.FORMAT_RGBA8)
	var medio: float = (tam - 1) * 0.5
	for y in range(tam):
		for x in range(tam):
			var distancia: float = Vector2(x - medio, y - medio).length()
			var pixel: Color = color
			# Suaviza el borde para que no se vea dentado.
			pixel.a = clampf(medio - distancia + 0.5, 0.0, 1.0)
			imagen.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(imagen)


# Letra fina con un poco de espacio entre letras, como en el boceto.
func _crear_fuente(espaciado: int) -> Font:
	var base: Font = null
	if archivo_fuente != "" and ResourceLoader.exists(archivo_fuente):
		base = load(archivo_fuente) as Font
	if base == null:
		var sistema := SystemFont.new()
		sistema.font_names = PackedStringArray([
			"Segoe UI Light", "Segoe UI Semilight", "Calibri Light", "Helvetica Neue", "Arial"
		])
		base = sistema
	var variacion := FontVariation.new()
	variacion.base_font = base
	variacion.spacing_glyph = espaciado
	return variacion


# ---------------------------------------------------------------- Transiciones

# Al abrir: la imagen aparece desde negro y después el texto se enciende.
func _entrada_suave() -> void:
	_cortina.color.a = 1.0
	_interfaz.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_cortina, "color:a", 0.0, 1.6)
	tween.parallel().tween_property(_interfaz, "modulate:a", 1.0, 1.2).set_delay(0.6)


func _cargar_escena(ruta: String) -> void:
	if _cargando:
		return
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		push_error("PantallaTitulo: no existe la escena '%s'. ¿Ya la creaste?" % ruta)
		return
	_cargando = true
	# La cortina bloquea los clics mientras se oscurece la pantalla.
	_cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_cortina, "color:a", 1.0, 0.7)
	tween.tween_callback(get_tree().change_scene_to_file.bind(ruta))


# ---------------------------------------------------------------- Acciones

func _on_jugar() -> void:
	# Una partida nueva empieza con el inventario vacío.
	Inventario.vaciar()
	_cargar_escena(escena_juego)


func _on_pruebas() -> void:
	_cargar_escena(escena_pruebas)


func _mostrar_ajustes() -> void:
	_lista_principal.hide()
	_lista_ajustes.show()
	_slider_volumen.grab_focus()


func _on_volver() -> void:
	Ajustes.guardar()
	AjustesAudio.guardar()
	_lista_ajustes.hide()
	_lista_principal.show()
	_boton_jugar.grab_focus()


func _on_salir() -> void:
	get_tree().quit()


func _on_volumen_cambiado(valor: float) -> void:
	Ajustes.volumen = valor
	Ajustes.aplicar_volumen()


func _on_ambiente_cambiado(valor: float) -> void:
	AjustesAudio.set_volumen(AjustesAudio.BUS_AMBIENTE, valor)


func _on_efectos_cambiado(valor: float) -> void:
	AjustesAudio.set_volumen(AjustesAudio.BUS_EFECTOS, valor)


func _on_efectos_soltado(_cambio: bool) -> void:
	_sonido_click()


func _on_sensibilidad_cambiada(valor: float) -> void:
	Ajustes.sensibilidad = valor
