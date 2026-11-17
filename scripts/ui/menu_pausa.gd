extends CanvasLayer
## Menú de pausa: se abre y se cierra con Esc dentro del juego.
## Se instancia como hijo de la escena del mundo (node_3d.tscn).
## Tiene el mismo estilo que la pantalla de título: texto a la izquierda sobre un degradado
## oscuro, sin cajas. Toda la interfaz se construye por código, así que los nodos que tenga
## la escena (Fondo, Principal, Opciones...) ya no se usan: el script los quita al abrir.

## Escena a la que se vuelve con "Menú principal".
@export_file("*.tscn") var escena_menu: String = "res://addons/scenes/menus/pantalla_titulo.tscn"

## Título que se muestra arriba (se pasa a mayúsculas solo).
@export var titulo_pausa: String = "Pausa"

## Letra del menú (la misma de la pantalla de título).
@export_file("*.ttf", "*.otf") var archivo_fuente: String = "res://fuentes/menu.ttf"

## Qué tan oscura es la franja de la izquierda detrás del texto (0 = nada, 1 = negro total).
@export_range(0.0, 1.0, 0.05) var oscurecer_izquierda: float = 0.85

## Cuánto se oscurece todo el juego detrás del menú (0 = nada, 1 = negro total).
@export_range(0.0, 1.0, 0.05) var oscurecer_general: float = 0.3

## Sonidos del menú (los mismos de la pantalla de título). Déjalos vacíos para quitarlos.
@export_file("*.ogg", "*.mp3", "*.wav") var archivo_hover: String = "res://assets/audio/ui_click.mp3"
@export_file("*.ogg", "*.mp3", "*.wav") var archivo_click: String = "res://assets/audio/ui_click.mp3"

const COLOR_TEXTO := Color(1.0, 0.97, 0.90, 1.0)
const COLOR_APAGADO := Color(0.93, 0.85, 0.72, 0.8)

var _raiz: Control
var _lista_principal: VBoxContainer
var _lista_ajustes: VBoxContainer
var _boton_continuar: Button
var _slider_volumen: HSlider
var _slider_ambiente: HSlider
var _slider_efectos: HSlider
var _slider_sensibilidad: HSlider
var _lista_rendimiento: VBoxContainer
var _lista_reloj ## Control con reloj_menu.gd
var _primer_boton_rendimiento: Button
var _botones_rendimiento: Dictionary = {}
var _fuente_titulo: Font
var _fuente_item: Font
var _sfx_hover: AudioStreamPlayer
var _sfx_click: AudioStreamPlayer
var _sin_sonido: bool = false
var _tween: Tween


func _ready() -> void:
	# Este nodo debe seguir funcionando mientras el juego está en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	# La interfaz ahora se construye por código: se quitan los nodos viejos de la escena.
	for hijo in get_children():
		hijo.queue_free()

	_fuente_titulo = _crear_fuente(6)
	_fuente_item = _crear_fuente(3)
	_crear_interfaz()
	_sfx_hover = _crear_reproductor(archivo_hover, -20.0, AjustesAudio.BUS_EFECTOS)
	_sfx_click = _crear_reproductor(archivo_click, -6.0, AjustesAudio.BUS_EFECTOS)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not get_tree().paused:
		pausar()
	elif _lista_reloj.visible:
		_on_volver_reloj()
	elif _lista_rendimiento.visible:
		_on_volver_rendimiento()
	elif _lista_ajustes.visible:
		_on_volver()
	else:
		continuar()
	get_viewport().set_input_as_handled()


func pausar() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Los sliders muestran siempre el valor actual de los ajustes.
	_slider_volumen.set_value_no_signal(Ajustes.volumen)
	_slider_ambiente.set_value_no_signal(AjustesAudio.get_volumen(AjustesAudio.BUS_AMBIENTE))
	_slider_efectos.set_value_no_signal(AjustesAudio.get_volumen(AjustesAudio.BUS_EFECTOS))
	_slider_sensibilidad.set_value_no_signal(Ajustes.sensibilidad)
	show()
	_mostrar_principal()
	_entrada_suave()


func continuar() -> void:
	Ajustes.guardar()
	AjustesAudio.guardar()
	get_viewport().gui_release_focus()
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- Construcción

func _crear_interfaz() -> void:
	# Raíz a pantalla completa: bloquea los clics hacia el juego y sirve para el fundido.
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Todo el juego se oscurece un poco detrás del menú.
	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.0, 0.0, oscurecer_general)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(velo)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Degradado negro a la izquierda para que el texto resalte: es más fuerte donde está
	# el texto y se desvanece hacia el centro de la pantalla.
	var tono := Color(0.0, 0.0, 0.0)
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
	textura.fill_to = Vector2(0.85, 0.5)
	textura.width = 256
	textura.height = 16
	var sombra := TextureRect.new()
	sombra.texture = textura
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Margen izquierdo y superior: la columna de texto queda arriba a la izquierda.
	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_theme_constant_override("margin_left", 130)
	margen.add_theme_constant_override("margin_top", 150)
	_raiz.add_child(margen)
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(columna)

	columna.add_child(_crear_etiqueta(titulo_pausa.to_upper(), 62, COLOR_TEXTO, _fuente_titulo))
	columna.add_child(_crear_espacio(64.0))

	_lista_principal = VBoxContainer.new()
	_lista_principal.add_theme_constant_override("separation", 6)
	columna.add_child(_lista_principal)
	_boton_continuar = _agregar_boton(_lista_principal, "Continuar", continuar)
	_agregar_boton(_lista_principal, "Opciones", _mostrar_opciones)
	_agregar_boton(_lista_principal, "Reloj", _mostrar_reloj)
	_agregar_boton(_lista_principal, "Menú principal", _on_menu_principal)

	_crear_ajustes(columna)
	_crear_rendimiento(columna)
	_crear_reloj(columna)


func _crear_ajustes(columna: Control) -> void:
	_lista_ajustes = VBoxContainer.new()
	_lista_ajustes.add_theme_constant_override("separation", 10)
	_lista_ajustes.visible = false
	columna.add_child(_lista_ajustes)

	_lista_ajustes.add_child(_crear_etiqueta("AJUSTES", 34, COLOR_TEXTO, _fuente_item))

	_slider_volumen = _agregar_slider("VOLUMEN", 0.0, 1.0, 0.05, Ajustes.volumen, _on_volumen_cambiado)
	_slider_ambiente = _agregar_slider("AMBIENTE", 0.0, 1.0, 0.05,
			AjustesAudio.get_volumen(AjustesAudio.BUS_AMBIENTE), _on_ambiente_cambiado)
	_slider_efectos = _agregar_slider("EFECTOS", 0.0, 1.0, 0.05,
			AjustesAudio.get_volumen(AjustesAudio.BUS_EFECTOS), _on_efectos_cambiado)
	# Al soltar el slider suena el click, para escuchar el nivel que quedó.
	_slider_efectos.drag_ended.connect(_on_efectos_soltado)
	_slider_sensibilidad = _agregar_slider("SENSIBILIDAD DEL MOUSE", 0.2, 3.0, 0.1,
			Ajustes.sensibilidad, _on_sensibilidad_cambiada)

	_lista_ajustes.add_child(_crear_espacio(18.0))
	_agregar_boton(_lista_ajustes, "Rendimiento", _mostrar_rendimiento)
	_agregar_boton(_lista_ajustes, "Volver", _on_volver)


# Una fila de ajustes: etiqueta pequeña y, debajo, el slider.
func _agregar_slider(titulo: String, minimo: float, maximo: float, paso: float, valor: float, al_cambiar: Callable) -> HSlider:
	_lista_ajustes.add_child(_crear_espacio(8.0))
	_lista_ajustes.add_child(_crear_etiqueta(titulo, 22, COLOR_APAGADO, _fuente_item))
	var slider := _crear_slider(minimo, maximo, paso, valor)
	slider.value_changed.connect(al_cambiar)
	_lista_ajustes.add_child(slider)
	return slider


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
	# Una sombra suave ayuda a que la letra fina no se pierda.
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


# Letra fina con un poco de espacio entre letras, como en la pantalla de título.
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


func _crear_reproductor(ruta: String, volumen_db: float, bus: String) -> AudioStreamPlayer:
	if ruta.is_empty():
		return null
	if not ResourceLoader.exists(ruta):
		push_warning("MenuPausa: no se encontró el audio '%s'." % ruta)
		return null
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = load(ruta)
	reproductor.volume_db = volumen_db
	reproductor.bus = bus
	add_child(reproductor)
	return reproductor


# ---------------------------------------------------------------- Sonidos y transiciones

func _sonido_hover() -> void:
	if _sfx_hover != null and not _sin_sonido:
		_sfx_hover.play()


func _sonido_click() -> void:
	if _sfx_click != null and _sfx_click.is_inside_tree():
		_sfx_click.play()


# Al abrir: el menú aparece con un fundido corto (corre aunque el juego esté en pausa).
func _entrada_suave() -> void:
	if _tween != null:
		_tween.kill()
	_raiz.modulate.a = 0.0
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_raiz, "modulate:a", 1.0, 0.2)


# ---------------------------------------------------------------- Acciones

func _mostrar_principal() -> void:
	_lista_ajustes.hide()
	_lista_rendimiento.hide()
	_lista_reloj.hide()
	_lista_principal.show()
	# Al abrir el menú o volver de Ajustes no debe sonar el "hover".
	_sin_sonido = true
	_boton_continuar.grab_focus()
	_sin_sonido = false


func _mostrar_opciones() -> void:
	_lista_principal.hide()
	_lista_ajustes.show()
	_slider_volumen.grab_focus()


func _on_volver() -> void:
	Ajustes.guardar()
	AjustesAudio.guardar()
	_mostrar_principal()


func _on_menu_principal() -> void:
	if not ResourceLoader.exists(escena_menu):
		push_error("MenuPausa: no existe la escena '%s'. Revisa escena_menu." % escena_menu)
		return
	Ajustes.guardar()
	AjustesAudio.guardar()
	# Hay que quitar la pausa antes de cambiar de escena,
	# si no el menú principal se cargaría congelado.
	get_tree().paused = false
	get_tree().change_scene_to_file(escena_menu)


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


# ---------------------------------------------------------------- Rendimiento

# Pantalla con el contador de FPS y las opciones gráficas (la lógica está en rendimiento.gd).
# Cada opción es un botón: al pulsarlo cambia al siguiente valor y el texto se actualiza.
func _crear_rendimiento(columna: Control) -> void:
	_lista_rendimiento = VBoxContainer.new()
	_lista_rendimiento.add_theme_constant_override("separation", 6)
	_lista_rendimiento.visible = false
	columna.add_child(_lista_rendimiento)

	_lista_rendimiento.add_child(_crear_etiqueta("RENDIMIENTO", 34, COLOR_TEXTO, _fuente_item))
	_lista_rendimiento.add_child(_crear_espacio(10.0))

	var rend: Variant = Ajustes.rendimiento
	for opcion: Dictionary in rend.opciones():
		var id: StringName = opcion["id"]
		var boton := _agregar_boton(_lista_rendimiento, rend.texto(id), _sin_accion)
		boton.pressed.connect(_alternar_rendimiento.bind(id))
		_botones_rendimiento[id] = boton
		if _primer_boton_rendimiento == null:
			_primer_boton_rendimiento = boton

	_lista_rendimiento.add_child(_crear_espacio(18.0))
	_agregar_boton(_lista_rendimiento, "Volver", _on_volver_rendimiento)


func _sin_accion() -> void:
	pass


func _alternar_rendimiento(id: StringName) -> void:
	Ajustes.rendimiento.alternar(id)
	_refrescar_rendimiento()


# Pone en cada botón el valor actual (por ejemplo si el contador se encendió con F3).
func _refrescar_rendimiento() -> void:
	var rend: Variant = Ajustes.rendimiento
	for id in _botones_rendimiento:
		var boton: Button = _botones_rendimiento[id]
		boton.text = String(rend.texto(id)).to_upper()


func _mostrar_rendimiento() -> void:
	_lista_ajustes.hide()
	_refrescar_rendimiento()
	_lista_rendimiento.show()
	# Al entrar no debe sonar el "hover".
	_sin_sonido = true
	_primer_boton_rendimiento.grab_focus()
	_sin_sonido = false


func _on_volver_rendimiento() -> void:
	_lista_rendimiento.hide()
	_lista_ajustes.show()
	_slider_volumen.grab_focus()


# ---------------------------------------------------------------- Reloj

# Pantalla para cambiar la hora del juego (la lógica y el dibujo están en reloj_menu.gd).
func _crear_reloj(columna: Control) -> void:
	_lista_reloj = VBoxContainer.new()
	_lista_reloj.set_script(preload("res://scripts/ui/reloj_menu.gd"))
	_lista_reloj.visible = false
	columna.add_child(_lista_reloj)
	_lista_reloj.add_child(_crear_etiqueta("RELOJ", 34, COLOR_TEXTO, _fuente_item))
	_lista_reloj.construir(_fuente_item)
	_agregar_boton(_lista_reloj, "Volver", _on_volver_reloj)


func _mostrar_reloj() -> void:
	_lista_principal.hide()
	_lista_reloj.abrir()
	_lista_reloj.show()
	_sin_sonido = true
	_lista_reloj.primer_foco().grab_focus()
	_sin_sonido = false


func _on_volver_reloj() -> void:
	_lista_reloj.hide()
	_lista_principal.show()
	_sin_sonido = true
	_boton_continuar.grab_focus()
	_sin_sonido = false
