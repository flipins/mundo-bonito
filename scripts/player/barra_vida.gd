class_name BarraVida
extends CanvasLayer
## Barra de vida simple: una barra verde con el número de vida dentro.
## Otros scripts la usan con: get_tree().get_first_node_in_group(&"barra_vida").recibir_dano(100)
 
signal vida_cambiada(actual: int, maximo: int)
signal murio
 
@export var vida_maxima: int = 1000
@export_group("Aspecto")
@export var ancho: float = 420.0
@export var alto: float = 12.5
## Distancia desde el borde inferior de la pantalla hasta la barra.
@export var margen_inferior: float = 60.0
@export var tamano_texto: int = 10
@export var color_vida: Color = Color(0.43, 0.689, 0.2, 1.0)
@export var color_fondo: Color = Color(0.0, 0.0, 0.0, 0.55)
## Qué tan rápido se mueve la barra al cambiar la vida (más alto = más rápido).
@export_range(1.0, 20.0, 0.5) var suavizado: float = 8.0
 
var vida: int = 0
var _mostrada: float = 0.0
var _barra: ProgressBar
var _texto: Label
 
 
func _ready() -> void:
	add_to_group(&"barra_vida")
	layer = 9
	vida = vida_maxima
	_mostrada = float(vida)
	_crear_interfaz()
	_actualizar_texto()
 
 
func _process(delta: float) -> void:
	if not is_equal_approx(_mostrada, float(vida)):
		_mostrada = lerpf(_mostrada, float(vida), clampf(delta * suavizado, 0.0, 1.0))
		if absf(_mostrada - float(vida)) < 0.5:
			_mostrada = float(vida)
		_barra.value = _mostrada
 
 
func recibir_dano(cantidad: int) -> void:
	if vida <= 0 or cantidad <= 0:
		return
	vida = maxi(vida - cantidad, 0)
	_actualizar_texto()
	vida_cambiada.emit(vida, vida_maxima)
	if vida == 0:
		murio.emit()
 
 
func curar(cantidad: int) -> void:
	if vida <= 0 or cantidad <= 0:
		return
	vida = mini(vida + cantidad, vida_maxima)
	_actualizar_texto()
	vida_cambiada.emit(vida, vida_maxima)
 
 
## Deja la vida al máximo (por ejemplo al reaparecer).
func restaurar() -> void:
	vida = vida_maxima
	_mostrada = float(vida)
	_barra.value = _mostrada
	_actualizar_texto()
	vida_cambiada.emit(vida, vida_maxima)
 
 
func _actualizar_texto() -> void:
	_texto.text = "%d / %d" % [vida, vida_maxima]
 
 
func _crear_interfaz() -> void:
	# La barra se ancla abajo al centro, a "margen_inferior" del borde.
	_barra = ProgressBar.new()
	_barra.show_percentage = false
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.max_value = vida_maxima
	_barra.value = vida
	_barra.anchor_left = 0.8
	_barra.anchor_right = 0.5
	_barra.anchor_top = 1
	_barra.anchor_bottom = 1
	_barra.offset_left = -ancho * 0.6
	_barra.offset_right = ancho * 0.6
	_barra.offset_top = -(margen_inferior + alto)
	_barra.offset_bottom = -margen_inferior
	_barra.add_theme_stylebox_override("background", _estilo(color_fondo))
	_barra.add_theme_stylebox_override("fill", _estilo(color_vida))
	add_child(_barra)
 
	# El número va dentro de la barra, centrado.
	_texto = Label.new()
	_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_font_size_override("font_size", tamano_texto)
	_texto.add_theme_constant_override("outline_size", 4)
	_texto.add_theme_color_override("font_outline_color", Color.ANTIQUE_WHITE)
	_barra.add_child(_texto)
 
 
func _estilo(color: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(int(alto * 0.7))
	return estilo
 
