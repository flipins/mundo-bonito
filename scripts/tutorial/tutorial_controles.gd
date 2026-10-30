extends Node
## Tutorial de controles (escena 2 del storyboard): mirar, caminar, correr, agacharse y saltar.
##
## Cómo funciona:
##  - Es un nodo suelto que se agrega como hijo de la escena del mundo (desierto.tscn).
##  - No toca al jugador ni se come ninguna tecla: solo mira lo que el jugador ya hace
##    (Input, mouse y su posición). Por eso no estorba al resto del juego ni al menú de pausa.
##  - Los avisos salen de a uno, a la derecha y a media altura, discretos. Cada uno se va solo cuando
##    el jugador cumple la acción.
##  - Al terminar todos se emite "tutorial_completado": ahí se engancha la escena 3 (caminata).

## Se emite cada vez que el jugador cumple un aviso ("camara", "mover", "correr", ...).
signal paso_completado(nombre: StringName)
## Se emite una sola vez, cuando se completaron todos los avisos.
signal tutorial_completado

enum Paso { CAMARA, MOVER, CORRER, AGACHARSE, SALTAR }
enum Estado { INACTIVO, ESPERANDO, PIDIENDO, TERMINADO }

@export_group("Jugador")
## El nodo "jugador" (CharacterBody3D). Si se deja vacío, se busca solo en la escena del mundo.
@export var jugador: CharacterBody3D

@export_group("Flujo")
## Si está activo, el tutorial empieza solo al cargar la escena.
@export var iniciar_automaticamente: bool = true
## Segundos antes del primer aviso (para que el jugador alcance a mirar el despertar).
@export var retraso_inicial: float = 2.5
## Segundos de respiro entre un aviso y el siguiente.
@export var pausa_entre_avisos: float = 1.0
## Pedir "mover el mouse" para mirar (conviene dejarlo: es lo primero que se necesita en 3D).
@export var pedir_camara: bool = true
## Pedir un salto al final (el jugador ya puede saltar con Espacio).
@export var pedir_salto: bool = true

@export_group("Cuánto tiene que hacer el jugador")
## Píxeles de mouse que hay que mover para dar por cumplido "mirar".
@export var pixeles_de_mouse: float = 700.0
## Metros que hay que caminar.
@export var metros_a_caminar: float = 4.0
## Segundos corriendo de verdad (con Shift y moviéndose a velocidad de carrera).
@export var segundos_corriendo: float = 1.5
## Segundos agachado.
@export var segundos_agachado: float = 0.7
## Velocidad horizontal desde la que se considera que corre (caminar = 5, correr = 9 en jugador.gd).
@export var velocidad_minima_correr: float = 6.5

@export_group("Apariencia")
## Letra del menú (la misma de la pantalla de título). Si no existe, se usa una del sistema.
@export_file("*.ttf", "*.otf") var archivo_fuente: String = "res://fuentes/menu.ttf"
## Distancia desde el borde derecho de la pantalla, en píxeles.
@export var margen_derecho: float = 70.0
## Subir o bajar el aviso respecto a la mitad de la pantalla, en píxeles (negativo = más arriba).
@export var desplazamiento_vertical: float = 0.0
@export var tamano_titulo: int = 30
@export var tamano_tecla: int = 18
## Qué tan oscuro es el degradado del lado derecho que ayuda a leer sobre la arena (0 = nada).
@export_range(0.0, 1.0, 0.05) var oscurecer_lado: float = 0.45

const COLOR_TEXTO := Color(1.0, 0.97, 0.90, 1.0)
const COLOR_APAGADO := Color(0.93, 0.85, 0.72, 0.8)
const ACCION_CORRER := &"correr"
const ACCION_AGACHARSE := &"agacharse"
const ACCION_SALTO := &"ui_accept"

var _estado: Estado = Estado.INACTIVO
var _pasos: Array[int] = []
var _indice: int = -1
var _espera: float = 0.0

# Avance del aviso actual.
var _progreso: float = 0.0
var _progreso_visible: float = 0.0
var _mouse_acumulado: float = 0.0
var _distancia: float = 0.0
var _tiempo: float = 0.0
var _ultima_posicion: Vector3 = Vector3.ZERO

# Interfaz (se construye por código, como el resto de los menús).
var _capa: CanvasLayer
var _raiz: Control
var _aviso: Control
var _titulo: Label
var _tecla: Label
var _barra_relleno: ColorRect
var _tween: Tween


func _ready() -> void:
	# Siempre activo: así el aviso se esconde por sí solo cuando el juego está en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buscar_jugador()
	_crear_interfaz()
	if jugador == null:
		push_error("TutorialControles: no se encontró el nodo 'jugador'. Asígnalo en el Inspector (propiedad Jugador).")
		return
	if iniciar_automaticamente:
		iniciar()


## Arranca (o reinicia) el tutorial desde el primer aviso.
func iniciar() -> void:
	if jugador == null:
		return
	_pasos.clear()
	if pedir_camara:
		_pasos.append(Paso.CAMARA)
	_pasos.append(Paso.MOVER)
	_pasos.append(Paso.CORRER)
	_pasos.append(Paso.AGACHARSE)
	if pedir_salto:
		_pasos.append(Paso.SALTAR)
	_indice = -1
	_espera = retraso_inicial
	_estado = Estado.ESPERANDO


## Da el tutorial por terminado sin pedir nada más (útil para depurar o si se carga una partida).
func saltar_tutorial() -> void:
	if _estado != Estado.TERMINADO:
		_terminar()


func esta_activo() -> bool:
	return _estado == Estado.ESPERANDO or _estado == Estado.PIDIENDO


func _input(event: InputEvent) -> void:
	# Solo mira el mouse; no marca el evento como usado, así que el jugador sigue girando normal.
	if _estado != Estado.PIDIENDO or get_tree().paused:
		return
	if _pasos[_indice] != Paso.CAMARA:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_acumulado += (event as InputEventMouseMotion).relative.length()


func _process(delta: float) -> void:
	if _estado == Estado.INACTIVO or _estado == Estado.TERMINADO:
		return

	# En pausa el aviso se esconde y no se cuenta nada.
	var en_pausa := get_tree().paused
	_raiz.visible = not en_pausa
	if en_pausa:
		return

	match _estado:
		Estado.ESPERANDO:
			_espera -= delta
			if _espera <= 0.0:
				_mostrar_siguiente()
		Estado.PIDIENDO:
			_avanzar_paso(delta)

	_progreso_visible = move_toward(_progreso_visible, _progreso, delta * 4.0)
	_barra_relleno.anchor_right = _progreso_visible


# --- Flujo de avisos -------------------------------------------------------------------------

func _mostrar_siguiente() -> void:
	_indice += 1
	if _indice >= _pasos.size():
		_terminar()
		return

	var paso: int = _pasos[_indice]
	_mouse_acumulado = 0.0
	_distancia = 0.0
	_tiempo = 0.0
	_progreso = 0.0
	_progreso_visible = 0.0
	_ultima_posicion = jugador.global_position

	var textos := _textos_del_paso(paso)
	_titulo.text = textos[0]
	_tecla.text = textos[1]
	_mostrar_aviso(true)
	_estado = Estado.PIDIENDO


func _avanzar_paso(delta: float) -> void:
	var paso: int = _pasos[_indice]
	match paso:
		Paso.CAMARA:
			_progreso = _mouse_acumulado / pixeles_de_mouse
		Paso.MOVER:
			var ahora := jugador.global_position
			var recorrido := Vector2(ahora.x - _ultima_posicion.x, ahora.z - _ultima_posicion.z).length()
			_ultima_posicion = ahora
			# Un salto grande de golpe es un teletransporte, no caminar.
			if recorrido < 2.0:
				_distancia += recorrido
			_progreso = _distancia / metros_a_caminar
		Paso.CORRER:
			if Input.is_action_pressed(ACCION_CORRER) and _velocidad_horizontal() > velocidad_minima_correr:
				_tiempo += delta
			_progreso = _tiempo / segundos_corriendo
		Paso.AGACHARSE:
			if Input.is_action_pressed(ACCION_AGACHARSE):
				_tiempo += delta
			_progreso = _tiempo / segundos_agachado
		Paso.SALTAR:
			if Input.is_action_just_pressed(ACCION_SALTO) and jugador.is_on_floor():
				_progreso = 1.0

	_progreso = clampf(_progreso, 0.0, 1.0)
	if _progreso >= 1.0:
		_completar_paso(paso)


func _completar_paso(paso: int) -> void:
	paso_completado.emit(_nombre_del_paso(paso))
	# Un instante con la barra llena y luego el aviso se apaga solo.
	_mostrar_aviso(false, 0.3)
	_estado = Estado.ESPERANDO
	_espera = pausa_entre_avisos


func _terminar() -> void:
	_estado = Estado.TERMINADO
	_mostrar_aviso(false)
	tutorial_completado.emit()


func _mostrar_aviso(entrar: bool, retraso: float = 0.0) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if retraso > 0.0:
		_tween.tween_interval(retraso)
	_tween.tween_property(_aviso, "modulate:a", 1.0 if entrar else 0.0, 0.6 if entrar else 0.5)


# --- Textos y teclas --------------------------------------------------------------------------

func _textos_del_paso(paso: int) -> PackedStringArray:
	match paso:
		Paso.CAMARA:
			return PackedStringArray(["Mira a tu alrededor", "Mueve el mouse"])
		Paso.MOVER:
			return PackedStringArray(["Camina", _teclas_de_movimiento()])
		Paso.CORRER:
			return PackedStringArray(["Corre", "Mantén %s mientras caminas" % _nombre_tecla(ACCION_CORRER)])
		Paso.AGACHARSE:
			return PackedStringArray(["Agáchate", "Mantén %s" % _nombre_tecla(ACCION_AGACHARSE)])
		Paso.SALTAR:
			var tecla_salto := "Espacio" if _accion_usa_tecla(ACCION_SALTO, KEY_SPACE) else _nombre_tecla(ACCION_SALTO)
			return PackedStringArray(["Salta", tecla_salto])
	return PackedStringArray(["", ""])


func _nombre_del_paso(paso: int) -> StringName:
	match paso:
		Paso.CAMARA:
			return &"camara"
		Paso.MOVER:
			return &"mover"
		Paso.CORRER:
			return &"correr"
		Paso.AGACHARSE:
			return &"agacharse"
		Paso.SALTAR:
			return &"saltar"
	return &""


func _teclas_de_movimiento() -> String:
	return "%s  %s  %s  %s" % [
		_nombre_tecla(&"ui_up"), _nombre_tecla(&"ui_left"),
		_nombre_tecla(&"ui_down"), _nombre_tecla(&"ui_right"),
	]


## Nombre de la tecla de una acción, tal como está escrita en el teclado del jugador
## (si cambias la tecla en el Mapa de entrada, el aviso se actualiza solo).
func _nombre_tecla(accion: StringName) -> String:
	if not InputMap.has_action(accion):
		return "?"
	var respaldo := ""
	for evento in InputMap.action_get_events(accion):
		if not evento is InputEventKey:
			continue
		var tecla := evento as InputEventKey
		if tecla.physical_keycode != KEY_NONE:
			var codigo := DisplayServer.keyboard_get_keycode_from_physical(tecla.physical_keycode)
			return OS.get_keycode_string(codigo)
		if respaldo.is_empty() and tecla.keycode != KEY_NONE:
			respaldo = OS.get_keycode_string(tecla.keycode)
	return respaldo if not respaldo.is_empty() else "?"


func _accion_usa_tecla(accion: StringName, codigo: Key) -> bool:
	if not InputMap.has_action(accion):
		return false
	for evento in InputMap.action_get_events(accion):
		if evento is InputEventKey:
			var tecla := evento as InputEventKey
			if tecla.keycode == codigo or tecla.physical_keycode == codigo:
				return true
	return false


# --- Ayudas -----------------------------------------------------------------------------------

func _buscar_jugador() -> void:
	if jugador != null:
		return
	var padre := get_parent()
	if padre != null:
		jugador = padre.get_node_or_null("jugador") as CharacterBody3D
	if jugador == null and get_tree().current_scene != null:
		jugador = get_tree().current_scene.get_node_or_null("jugador") as CharacterBody3D


func _velocidad_horizontal() -> float:
	return Vector2(jugador.velocity.x, jugador.velocity.z).length()


# --- Interfaz ---------------------------------------------------------------------------------

func _crear_interfaz() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 5
	add_child(_capa)

	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(_raiz)

	# Todo el aviso cuelga de aquí, para poder aparecer y desaparecer con un solo fundido.
	_aviso = Control.new()
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.modulate.a = 0.0
	_raiz.add_child(_aviso)

	# Degradado suave en el lado derecho para que el texto se lea sobre la arena clara
	# (transparente hacia el centro de la pantalla, más oscuro hacia el borde).
	var degradado := Gradient.new()
	degradado.set_color(0, Color(0, 0, 0, 0))
	degradado.set_color(1, Color(0, 0, 0, oscurecer_lado))
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill_from = Vector2(0.0, 0.0)
	textura.fill_to = Vector2(1.0, 0.0)
	textura.width = 128
	textura.height = 4
	var fondo := TextureRect.new()
	fondo.texture = textura
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.anchor_left = 0.62
	fondo.anchor_right = 1.0
	fondo.anchor_top = 0.0
	fondo.anchor_bottom = 1.0
	_aviso.add_child(fondo)

	# Texto pegado al borde derecho, centrado en vertical.
	var caja := VBoxContainer.new()
	caja.anchor_left = 1.0
	caja.anchor_right = 1.0
	caja.anchor_top = 0.5
	caja.anchor_bottom = 0.5
	caja.offset_left = -(margen_derecho + 360.0)
	caja.offset_right = -margen_derecho
	caja.offset_top = desplazamiento_vertical - 60.0
	caja.offset_bottom = desplazamiento_vertical + 60.0
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_theme_constant_override("separation", 6)
	_aviso.add_child(caja)

	_titulo = _crear_etiqueta(tamano_titulo, COLOR_TEXTO, _crear_fuente(4))
	_tecla = _crear_etiqueta(tamano_tecla, COLOR_APAGADO, _crear_fuente(2))
	caja.add_child(_titulo)
	caja.add_child(_tecla)

	# Barrita fina que se llena a medida que el jugador cumple la acción.
	var barra_fondo := ColorRect.new()
	barra_fondo.color = Color(1.0, 1.0, 1.0, 0.18)
	barra_fondo.custom_minimum_size = Vector2(240.0, 3.0)
	barra_fondo.size_flags_horizontal = Control.SIZE_SHRINK_END
	barra_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(barra_fondo)

	_barra_relleno = ColorRect.new()
	_barra_relleno.color = COLOR_TEXTO
	_barra_relleno.anchor_left = 0.0
	_barra_relleno.anchor_top = 0.0
	_barra_relleno.anchor_bottom = 1.0
	_barra_relleno.anchor_right = 0.0
	_barra_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_fondo.add_child(_barra_relleno)


func _crear_etiqueta(tamano: int, color: Color, fuente: Font) -> Label:
	var etiqueta := Label.new()
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	etiqueta.add_theme_constant_override("outline_size", 4)
	return etiqueta


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
