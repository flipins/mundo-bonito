extends Node3D
## Caminata por el desierto (escena 3 del storyboard).
##
## Cómo funciona:
##  - Es un nodo que contiene las zonas de historia (ZonaHistoria) como hijos, a lo largo del
##    camino lineal que cierran las montañas.
##  - Cuando el tutorial de controles termina ("tutorial_completado"), arma todas las zonas.
##  - Cada vez que el jugador pisa una, muestra su texto abajo y al centro, como subtítulo.
##  - La zona marcada como "es_final" (junto a la espada) emite "llego_a_la_espada":
##    ahí se engancha la escena 4.
##  - No toca al jugador ni al ciclo de día; este último sigue su curso (si quieres que
##    el día avance más rápido o más lento durante la caminata, cambia la velocidad del
##    AnimationPlayer del ciclo de día).

## Se emite cada vez que el jugador descubre una zona.
signal zona_descubierta(zona: Area3D)
## Se emite al pisar la zona final, la que está junto a la espada.
signal llego_a_la_espada

@export_group("Flujo")
## El nodo TutorialControles. Si se deja vacío, se busca uno con ese nombre en la escena del mundo.
## Si no hay tutorial, la caminata arranca sola.
@export var tutorial: Node
## Segundos que espera, tras terminar el tutorial, antes de activar las zonas.
@export var retraso_tras_tutorial: float = 1.0

@export_group("Textos")
## Segundos mínimos que se queda un texto en pantalla.
@export var segundos_minimos: float = 4.0
## Segundos extra por cada letra del texto (los textos largos se quedan más tiempo).
@export var segundos_por_caracter: float = 0.05

@export_group("Apariencia")
## Letra del menú (la misma de la pantalla de título). Si no existe, se usa una del sistema.
@export_file("*.ttf", "*.otf") var archivo_fuente: String = "res://fuentes/menu.ttf"
## Distancia desde el borde de abajo de la pantalla, en píxeles.
@export var margen_inferior: float = 120.0
@export var tamano_texto: int = 28
## Qué tan oscuro es el degradado de abajo que ayuda a leer sobre la arena (0 = nada).
@export_range(0.0, 1.0, 0.05) var oscurecer_abajo: float = 0.5

const COLOR_TEXTO := Color(1.0, 0.97, 0.90, 1.0)

var _zonas: Array[Area3D] = []
var _iniciada: bool = false
var _cola: Array[String] = []
var _mostrando: bool = false

# Interfaz (se construye por código, como el resto de los menús).
var _capa: CanvasLayer
var _raiz: Control
var _caja: Control
var _etiqueta: Label
var _tween: Tween


func _ready() -> void:
	# Siempre activo: así el texto se esconde por sí solo cuando el juego está en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_interfaz()
	_recoger_zonas()
	_conectar_tutorial()


func _process(_delta: float) -> void:
	# En pausa el texto se esconde (y su fundido se congela, ver _mostrar_siguiente_texto).
	_raiz.visible = not get_tree().paused


## Arma todas las zonas. Se llama sola al terminar el tutorial; también se puede llamar a mano.
func iniciar() -> void:
	if _iniciada:
		return
	_iniciada = true
	if retraso_tras_tutorial > 0.0:
		await get_tree().create_timer(retraso_tras_tutorial, false).timeout
	for zona in _zonas:
		zona.call(&"armar")


func _recoger_zonas() -> void:
	for nodo in find_children("*", "Area3D", true, false):
		if nodo.has_method(&"armar") and nodo.has_signal(&"activada"):
			var zona := nodo as Area3D
			_zonas.append(zona)
			zona.connect(&"activada", _al_activar_zona)
	if _zonas.is_empty():
		push_warning("CaminataDesierto: no hay ninguna ZonaHistoria como hija de este nodo.")


func _conectar_tutorial() -> void:
	if tutorial == null:
		var padre := get_parent()
		if padre != null:
			tutorial = padre.get_node_or_null("TutorialControles")
	if tutorial != null and tutorial.has_signal(&"tutorial_completado"):
		tutorial.connect(&"tutorial_completado", iniciar)
	else:
		# Sin tutorial, la caminata arranca sola.
		iniciar.call_deferred()


func _al_activar_zona(zona: Area3D) -> void:
	zona_descubierta.emit(zona)
	var texto := str(zona.get(&"texto")).strip_edges()
	if texto != "":
		_encolar(texto)
	if bool(zona.get(&"es_final")):
		llego_a_la_espada.emit()


# --- Textos en pantalla ------------------------------------------------------------------------

func _encolar(texto: String) -> void:
	_cola.append(texto)
	if not _mostrando:
		_mostrar_siguiente_texto()


func _mostrar_siguiente_texto() -> void:
	if _cola.is_empty():
		_mostrando = false
		return
	_mostrando = true
	var texto: String = _cola.pop_front()
	_etiqueta.text = texto
	var duracion := maxf(segundos_minimos, texto.length() * segundos_por_caracter)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# Si el jugador pausa mientras se lee, el texto espera en vez de seguir corriendo.
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_tween.tween_property(_caja, "modulate:a", 1.0, 1.0)
	_tween.tween_interval(duracion)
	_tween.tween_property(_caja, "modulate:a", 0.0, 1.2)
	_tween.tween_callback(_mostrar_siguiente_texto)


# --- Interfaz ----------------------------------------------------------------------------------

func _crear_interfaz() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 4
	add_child(_capa)

	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(_raiz)

	# Todo el texto cuelga de aquí, para aparecer y desaparecer con un solo fundido.
	_caja = Control.new()
	_caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja.modulate.a = 0.0
	_raiz.add_child(_caja)

	# Degradado suave en la parte de abajo para que el texto se lea sobre la arena clara.
	var degradado := Gradient.new()
	degradado.set_color(0, Color(0, 0, 0, 0))
	degradado.set_color(1, Color(0, 0, 0, oscurecer_abajo))
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill_from = Vector2(0.0, 0.0)
	textura.fill_to = Vector2(0.0, 1.0)
	textura.width = 4
	textura.height = 128
	var fondo := TextureRect.new()
	fondo.texture = textura
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.anchor_left = 0.0
	fondo.anchor_right = 1.0
	fondo.anchor_top = 0.62
	fondo.anchor_bottom = 1.0
	_caja.add_child(fondo)

	# Texto centrado abajo, con salto de línea automático si es largo.
	_etiqueta = Label.new()
	_etiqueta.anchor_left = 0.5
	_etiqueta.anchor_right = 0.5
	_etiqueta.anchor_top = 1.0
	_etiqueta.anchor_bottom = 1.0
	_etiqueta.offset_left = -480.0
	_etiqueta.offset_right = 480.0
	_etiqueta.offset_top = -(margen_inferior + 150.0)
	_etiqueta.offset_bottom = -margen_inferior
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiqueta.add_theme_font_override("font", _crear_fuente(3))
	_etiqueta.add_theme_font_size_override("font_size", tamano_texto)
	_etiqueta.add_theme_color_override("font_color", COLOR_TEXTO)
	_etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_etiqueta.add_theme_constant_override("outline_size", 4)
	_caja.add_child(_etiqueta)


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
