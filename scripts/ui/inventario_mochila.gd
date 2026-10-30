extends CanvasLayer
## Mochila (inventario) estilo Minecraft / Rust: una cuadrícula de casillas cuadradas sobre
## un fondo desenfocado y oscurecido. Se abre y se cierra con I o Tab (Esc también cierra).
##
## - Muestra lo que haya en el Autoload "Inventario" (ver inventario.gd). No guarda objetos
##   propios: solo recuerda en qué casilla está cada uno, y el jugador puede cambiarlo
##   arrastrando los objetos de una casilla a otra.
## - Mientras está abierta el juego queda en pausa y el mouse se muestra.
## - Se instancia como hijo de la escena del mundo (desierto.tscn), igual que el menú de pausa.
## - Íconos: si existe un archivo "res://assets/iconos/<id del objeto>.png" (por ejemplo
##   "rama_espada.png") se usa como ícono. Si no existe, se dibuja un cuadro de color con
##   las iniciales del objeto.

# Desenfoque del fondo: toma la pantalla que hay detrás (el juego en pausa), la difumina
# con una malla de 25 muestras sobre una versión reducida de la imagen, y la oscurece.
# "intensidad" sube de 0 a 1 al abrir y baja al cerrar, para que el fondo se desenfoque con un fundido.
const SHADER_DESENFOQUE := """
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float intensidad : hint_range(0.0, 1.0) = 1.0;
uniform float radio : hint_range(0.0, 8.0) = 2.5;
uniform float nivel : hint_range(0.0, 6.0) = 2.0;
uniform float oscuridad : hint_range(0.0, 1.0) = 0.35;
uniform vec4 tinte : source_color = vec4(0.02, 0.02, 0.03, 1.0);

void fragment() {
	vec2 paso = SCREEN_PIXEL_SIZE * radio * 2.0;
	vec3 suma = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 d = vec2(float(x), float(y));
			float peso = max(0.0, 1.0 - length(d) / 3.2);
			suma += textureLod(pantalla, SCREEN_UV + d * paso, nivel).rgb * peso;
			total += peso;
		}
	}
	vec3 color = mix(suma / total, tinte.rgb, oscuridad);
	COLOR = vec4(color, intensidad);
}
"""

const COLOR_TEXTO := Color(1.0, 0.97, 0.90, 1.0)
const COLOR_APAGADO := Color(0.93, 0.85, 0.72, 0.8)
const COLOR_ACENTO := Color(1.0, 0.85, 0.5, 1.0)

## Nombre de la acción de entrada. Si no existe se crea; siempre se asegura que tenga las teclas I y Tab.
@export var accion: StringName = &"inventario"

@export_group("Mochila")
## Casillas por fila.
@export_range(3, 10, 1) var columnas: int = 6
## Filas de casillas. La mochila guarda columnas × filas objetos distintos.
@export_range(1, 8, 1) var filas: int = 4
## Lado de cada casilla, en píxeles.
@export var tamano_casilla: float = 88.0
## Espacio entre casillas, en píxeles.
@export var separacion: float = 8.0
## Título que se muestra arriba (se pasa a mayúsculas solo).
@export var titulo: String = "Mochila"
## Carpeta donde buscar los íconos (un PNG por objeto, con el id del objeto como nombre).
@export var carpeta_iconos: String = "res://assets/iconos/"

@export_group("Fondo")
## Cuánto se desenfoca el juego de atrás (0 = nada).
@export_range(0.0, 8.0, 0.25) var desenfoque: float = 2.5
## Cuánto se oscurece el fondo (0 = nada, 1 = negro).
@export_range(0.0, 1.0, 0.05) var oscurecer: float = 0.35
## Qué tan opaco es el panel de la mochila (0 = transparente, 1 = sólido).
@export_range(0.0, 1.0, 0.05) var opacidad_panel: float = 0.55

@export_group("Letra")
## Letra del menú (la misma de la pantalla de título). Si no existe, se usa una del sistema.
@export_file("*.ttf", "*.otf") var archivo_fuente: String = "res://fuentes/menu.ttf"

# Qué objeto hay en cada casilla (id), o &"" si está vacía.
var _orden: Array[StringName] = []
# Copia del contenido del Inventario, de la última vez que se actualizó.
var _datos: Dictionary = {}
var _casillas: Array = []
var _iconos: Dictionary = {}

var _abierto: bool = false
var _visibilidad: float = 0.0
var _indice_hover: int = -1

var _raiz: Control
var _fondo: ColorRect
var _material: ShaderMaterial
var _panel: PanelContainer
var _rejilla: GridContainer
var _contador: Label
var _vacio: Label
var _tip: PanelContainer
var _tip_titulo: Label
var _tip_detalle: Label
var _fuente_titulo: Font
var _fuente_texto: Font
var _tween: Tween


func _ready() -> void:
	# Debe seguir funcionando con el juego en pausa, si no no podría cerrarse.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_asegurar_accion()
	_orden.resize(columnas * filas)
	_orden.fill(&"")
	_fuente_titulo = _crear_fuente(6)
	_fuente_texto = _crear_fuente(1)
	_crear_interfaz()
	Inventario.objeto_agregado.connect(_al_cambiar_inventario)
	Inventario.objeto_quitado.connect(_al_cambiar_inventario)
	hide()


func _process(_delta: float) -> void:
	if visible:
		_actualizar_tooltip()


# Se usa _input (y no _unhandled_input) para recibir Esc ANTES que el menú de pausa:
# así, con la mochila abierta, Esc solo cierra la mochila.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(accion):
		if _abierto:
			cerrar()
		elif not get_tree().paused:
			abrir()
		else:
			return # Hay otro menú abierto (por ejemplo la pausa): no se hace nada.
		get_viewport().set_input_as_handled()
	elif _abierto and event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()


func abrir() -> void:
	_sincronizar()
	_abierto = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	_animar(true)


func cerrar() -> void:
	_abierto = false
	_indice_hover = -1
	_tip.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_animar(false)


## Mueve el objeto de una casilla a otra (si la de destino tiene algo, se intercambian).
func mover(desde: int, hasta: int) -> void:
	if desde == hasta or desde < 0 or hasta < 0:
		return
	if desde >= _orden.size() or hasta >= _orden.size():
		return
	var guardado: StringName = _orden[desde]
	_orden[desde] = _orden[hasta]
	_orden[hasta] = guardado
	_refrescar()


# --- Datos -------------------------------------------------------------------------------------

func _al_cambiar_inventario(_id: StringName) -> void:
	# Si se recoge algo con la mochila cerrada, se acomoda en cuanto se abra.
	if _abierto:
		_sincronizar()


func _sincronizar() -> void:
	_datos = Inventario.todos()

	# Lo que ya no está en el inventario libera su casilla.
	for i in range(_orden.size()):
		if _orden[i] != &"" and not _datos.has(_orden[i]):
			_orden[i] = &""

	# Lo nuevo va a la primera casilla libre (en orden alfabético, para que sea estable).
	var nuevos: Array = []
	for id in _datos.keys():
		if not _orden.has(id):
			nuevos.append(id)
	nuevos.sort_custom(func(a, b): return str(_datos[a]["nombre"]) < str(_datos[b]["nombre"]))
	for id in nuevos:
		var libre: int = _orden.find(&"")
		if libre == -1:
			break # Mochila llena: lo que sobra sigue en el Inventario, pero no cabe en pantalla.
		_orden[libre] = id

	_refrescar()


func _refrescar() -> void:
	var ocupadas: int = 0
	for i in range(_casillas.size()):
		var id: StringName = _orden[i]
		if id == &"" or not _datos.has(id):
			_casillas[i].poner(&"", "", 0, Color.WHITE, null)
			continue
		ocupadas += 1
		var fila: Dictionary = _datos[id]
		_casillas[i].poner(id, str(fila["nombre"]), int(fila["cantidad"]), _color_de(id), _icono_de(id))
	_contador.text = "%d / %d" % [ocupadas, _casillas.size()]
	# Se esconde con transparencia (y no con visible) para que el panel no cambie de tamaño.
	_vacio.modulate.a = 1.0 if ocupadas == 0 else 0.0


# Un color estable para cada objeto, sacado de su id (el mismo objeto siempre sale del mismo color).
func _color_de(id: StringName) -> Color:
	return Color.from_hsv(float(str(id).hash() % 360) / 360.0, 0.45, 0.62)


func _icono_de(id: StringName) -> Texture2D:
	if _iconos.has(id):
		return _iconos[id]
	var textura: Texture2D = null
	var ruta := "%s%s.png" % [carpeta_iconos, id]
	if ResourceLoader.exists(ruta):
		textura = load(ruta) as Texture2D
	_iconos[id] = textura
	return textura


# --- Apertura y cierre -------------------------------------------------------------------------

func _animar(entrar: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# Tiene que correr aunque el juego esté en pausa.
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_poner_visibilidad, _visibilidad, 1.0 if entrar else 0.0, 0.22 if entrar else 0.15)
	if not entrar:
		_tween.tween_callback(hide)


func _poner_visibilidad(valor: float) -> void:
	_visibilidad = valor
	_material.set_shader_parameter(&"intensidad", valor)
	_panel.modulate.a = valor


func _asegurar_accion() -> void:
	if not InputMap.has_action(accion):
		InputMap.add_action(accion)
	for codigo in [KEY_I, KEY_TAB]:
		if not _accion_usa_tecla(codigo):
			var tecla := InputEventKey.new()
			tecla.physical_keycode = codigo
			InputMap.action_add_event(accion, tecla)


func _accion_usa_tecla(codigo: int) -> bool:
	for evento in InputMap.action_get_events(accion):
		if evento is InputEventKey:
			var tecla := evento as InputEventKey
			if tecla.physical_keycode == codigo or tecla.keycode == codigo:
				return true
	return false


# --- Casillas ----------------------------------------------------------------------------------

func _al_hover_casilla(indice: int, dentro: bool) -> void:
	if dentro:
		_indice_hover = indice
	elif _indice_hover == indice:
		_indice_hover = -1


# El cuadrito con el nombre y la cantidad, pegado al mouse cuando está sobre un objeto.
func _actualizar_tooltip() -> void:
	var id: StringName = &""
	if _abierto and _indice_hover >= 0 and not get_viewport().gui_is_dragging():
		id = _orden[_indice_hover]
	if id == &"" or not _datos.has(id):
		_tip.visible = false
		return

	var fila: Dictionary = _datos[id]
	_tip_titulo.text = str(fila["nombre"])
	_tip_detalle.text = "Cantidad: %d" % int(fila["cantidad"])
	_tip.visible = true

	var pantalla: Vector2 = get_viewport().get_visible_rect().size
	var posicion: Vector2 = get_viewport().get_mouse_position() + Vector2(20.0, 22.0)
	posicion.x = minf(posicion.x, pantalla.x - _tip.size.x - 8.0)
	posicion.y = minf(posicion.y, pantalla.y - _tip.size.y - 8.0)
	_tip.position = posicion


class Casilla extends PanelContainer:
	## Una casilla cuadrada de la mochila. Se puede arrastrar su objeto a otra casilla.

	signal soltado(desde: int, hasta: int)
	signal hover(indice: int, dentro: bool)

	var indice: int = 0
	var id: StringName = &""
	var estilo_normal: StyleBoxFlat
	var estilo_hover: StyleBoxFlat

	var _icono: Panel
	var _estilo_icono: StyleBoxFlat
	var _iniciales: Label
	var _textura: TextureRect
	var _cantidad: Label


	func construir(tamano: float, fuente: Font) -> void:
		custom_minimum_size = Vector2(tamano, tamano)
		add_theme_stylebox_override("panel", estilo_normal)

		var contenido := Control.new()
		contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(contenido)

		# Ícono dibujado: un cuadro de color con las iniciales (cuando no hay PNG).
		_estilo_icono = StyleBoxFlat.new()
		_estilo_icono.set_corner_radius_all(6)
		_estilo_icono.set_border_width_all(1)
		_estilo_icono.border_color = Color(1.0, 1.0, 1.0, 0.25)
		_icono = Panel.new()
		_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icono.add_theme_stylebox_override("panel", _estilo_icono)
		contenido.add_child(_icono)
		_icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)

		_iniciales = Label.new()
		_iniciales.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_iniciales.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_iniciales.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_iniciales.add_theme_font_override("font", fuente)
		_iniciales.add_theme_font_size_override("font_size", int(tamano * 0.3))
		_iniciales.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
		_iniciales.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.45))
		_iniciales.add_theme_constant_override("outline_size", 4)
		_icono.add_child(_iniciales)
		_iniciales.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		# Ícono de imagen (cuando existe el PNG del objeto).
		_textura = TextureRect.new()
		_textura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_textura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		contenido.add_child(_textura)
		_textura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)

		# Cantidad, abajo a la derecha como en Minecraft (solo si hay más de uno).
		_cantidad = Label.new()
		_cantidad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cantidad.anchor_left = 1.0
		_cantidad.anchor_right = 1.0
		_cantidad.anchor_top = 1.0
		_cantidad.anchor_bottom = 1.0
		_cantidad.offset_left = -56.0
		_cantidad.offset_top = -30.0
		_cantidad.offset_right = -7.0
		_cantidad.offset_bottom = -3.0
		_cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_cantidad.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_cantidad.add_theme_font_override("font", fuente)
		_cantidad.add_theme_font_size_override("font_size", 20)
		_cantidad.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90, 1.0))
		_cantidad.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		_cantidad.add_theme_constant_override("outline_size", 6)
		contenido.add_child(_cantidad)

		mouse_entered.connect(_cambiar_hover.bind(true))
		mouse_exited.connect(_cambiar_hover.bind(false))
		poner(&"", "", 0, Color.WHITE, null)


	## Pone (o vacía, con un id vacío) el objeto de la casilla.
	func poner(nuevo_id: StringName, nombre: String, cantidad: int, color: Color, textura: Texture2D) -> void:
		id = nuevo_id
		var hay: bool = nuevo_id != &""
		_icono.visible = hay and textura == null
		_textura.visible = hay and textura != null
		_cantidad.visible = hay and cantidad > 1
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hay else Control.CURSOR_ARROW
		if not hay:
			return
		_estilo_icono.bg_color = color
		_iniciales.text = nombre.substr(0, 2).to_upper()
		_textura.texture = textura
		_cantidad.text = str(cantidad)


	func _cambiar_hover(dentro: bool) -> void:
		add_theme_stylebox_override("panel", estilo_hover if dentro else estilo_normal)
		hover.emit(indice, dentro)


	# --- Arrastrar y soltar ---

	func _get_drag_data(_en_posicion: Vector2) -> Variant:
		if id == &"":
			return null
		set_drag_preview(_crear_vista_previa())
		return {"desde": indice}


	func _can_drop_data(_en_posicion: Vector2, datos: Variant) -> bool:
		return datos is Dictionary and datos.has("desde")


	func _drop_data(_en_posicion: Vector2, datos: Variant) -> void:
		soltado.emit(int(datos["desde"]), indice)


	# Lo que se ve pegado al mouse mientras se arrastra: el ícono, un poco transparente.
	func _crear_vista_previa() -> Control:
		var raiz := Control.new()
		var lado: float = size.x * 0.75
		var icono: Control
		if _textura.visible and _textura.texture != null:
			var imagen := TextureRect.new()
			imagen.texture = _textura.texture
			imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icono = imagen
		else:
			var cuadro := Panel.new()
			cuadro.add_theme_stylebox_override("panel", _estilo_icono)
			var letras := Label.new()
			letras.text = _iniciales.text
			letras.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			letras.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			letras.add_theme_font_size_override("font_size", int(lado * 0.36))
			cuadro.add_child(letras)
			letras.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icono = cuadro
		icono.size = Vector2(lado, lado)
		icono.position = -icono.size * 0.5
		icono.modulate.a = 0.85
		raiz.add_child(icono)
		return raiz


# --- Interfaz ----------------------------------------------------------------------------------

func _crear_interfaz() -> void:
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Fondo: la pantalla de atrás, desenfocada y oscurecida.
	var shader := Shader.new()
	shader.code = SHADER_DESENFOQUE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter(&"radio", desenfoque)
	_material.set_shader_parameter(&"oscuridad", oscurecer)
	_material.set_shader_parameter(&"intensidad", 0.0)
	_fondo = ColorRect.new()
	_fondo.material = _material
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.add_child(_fondo)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Panel de la mochila, al centro.
	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _crear_estilo_panel())
	_panel.modulate.a = 0.0
	centro.add_child(_panel)

	var margen := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 28)
	_panel.add_child(margen)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 16)
	margen.add_child(caja)

	# Cabecera: título a la izquierda y cuántas casillas hay ocupadas a la derecha.
	var cabecera := HBoxContainer.new()
	caja.add_child(cabecera)
	var etiqueta_titulo := _crear_etiqueta(titulo.to_upper(), 34, COLOR_TEXTO, _fuente_titulo)
	etiqueta_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(etiqueta_titulo)
	_contador = _crear_etiqueta("", 20, COLOR_APAGADO, _fuente_texto)
	_contador.size_flags_vertical = Control.SIZE_SHRINK_END
	cabecera.add_child(_contador)

	var linea := ColorRect.new()
	linea.color = Color(1.0, 1.0, 1.0, 0.14)
	linea.custom_minimum_size = Vector2(0.0, 1.0)
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(linea)

	# La cuadrícula de casillas.
	_rejilla = GridContainer.new()
	_rejilla.columns = columnas
	_rejilla.add_theme_constant_override("h_separation", int(separacion))
	_rejilla.add_theme_constant_override("v_separation", int(separacion))
	caja.add_child(_rejilla)
	for i in range(columnas * filas):
		var casilla := Casilla.new()
		casilla.indice = i
		casilla.estilo_normal = _crear_estilo_casilla(false)
		casilla.estilo_hover = _crear_estilo_casilla(true)
		casilla.construir(tamano_casilla, _fuente_texto)
		casilla.soltado.connect(mover)
		casilla.hover.connect(_al_hover_casilla)
		_rejilla.add_child(casilla)
		_casillas.append(casilla)

	_vacio = _crear_etiqueta("Tu mochila está vacía.", 20, COLOR_APAGADO, _fuente_texto)
	_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_vacio)

	var pie := _crear_etiqueta("Arrastra los objetos para ordenarlos   ·   I, Tab o Esc para cerrar", 16, Color(COLOR_APAGADO.r, COLOR_APAGADO.g, COLOR_APAGADO.b, 0.55), _fuente_texto)
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(pie)

	# Cuadrito con el nombre del objeto, que sigue al mouse.
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_tip := StyleBoxFlat.new()
	estilo_tip.bg_color = Color(0.04, 0.04, 0.05, 0.92)
	estilo_tip.border_color = Color(COLOR_ACENTO.r, COLOR_ACENTO.g, COLOR_ACENTO.b, 0.5)
	estilo_tip.set_border_width_all(1)
	estilo_tip.set_corner_radius_all(6)
	estilo_tip.set_content_margin_all(10.0)
	_tip.add_theme_stylebox_override("panel", estilo_tip)
	var caja_tip := VBoxContainer.new()
	caja_tip.add_theme_constant_override("separation", 2)
	_tip.add_child(caja_tip)
	_tip_titulo = _crear_etiqueta("", 22, COLOR_TEXTO, _fuente_texto)
	_tip_detalle = _crear_etiqueta("", 17, COLOR_APAGADO, _fuente_texto)
	caja_tip.add_child(_tip_titulo)
	caja_tip.add_child(_tip_detalle)
	_tip.visible = false
	_raiz.add_child(_tip)


func _crear_estilo_panel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.04, 0.05, opacidad_panel)
	estilo.border_color = Color(1.0, 1.0, 1.0, 0.12)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(12)
	estilo.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	estilo.shadow_size = 28
	return estilo


func _crear_estilo_casilla(resaltada: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(1.0, 1.0, 1.0, 0.10) if resaltada else Color(0.0, 0.0, 0.0, 0.38)
	estilo.border_color = COLOR_ACENTO if resaltada else Color(1.0, 1.0, 1.0, 0.16)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	return estilo


func _crear_etiqueta(texto: String, tamano: int, color: Color, fuente: Font) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
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
