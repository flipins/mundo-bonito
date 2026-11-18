extends CanvasLayer
## HUD ornamental para Mundo Bonito (Godot 4.x)
## - Coloca la vida en la esquina superior izquierda.
## - Elimina el reloj/contador de hora del HUD (ese lo quitamos desde reloj.gd).
## - Construye toda la interfaz por código, así que puede sustituir un HUD viejo sin depender de nodos previos.
##
## Uso rápido:
## 1) Asigna este script al CanvasLayer de tu HUD actual, o crea un CanvasLayer nuevo y usa este script.
## 2) Si tu jugador tiene un script con variables de vida, llama a actualizar_vida(actual, maxima)
##    o usa vincular_objetivo($Jugador).
## 3) Si tu jugador emite alguna de estas señales, se conectará solo:
##    vida_cambiada(actual, maxima), salud_cambiada(actual, maxima), health_changed(actual, maxima).

@export var vida_inicial: float = 1000.0
@export var vida_maxima_inicial: float = 1000.0
@export var limpiar_hijos_existentes: bool = true
@export var mostrar_texto_valor: bool = true
@export var mostrar_titulo: bool = true
@export var titulo: String = "VITALIDAD"
@export var ancho_barra: float = 420.0
@export var alto_barra: float = 38.0
@export var margen_superior: float = 24.0
@export var margen_izquierdo: float = 24.0
@export var auto_buscar_grupo_jugador: String = "player"

const COLOR_ORO := Color(0.84, 0.60, 0.22, 1.0)
const COLOR_ORO_CLARO := Color(0.98, 0.84, 0.50, 1.0)
const COLOR_ORO_OSCURO := Color(0.36, 0.24, 0.10, 1.0)
const COLOR_FONDO := Color(0.03, 0.02, 0.01, 0.78)
const COLOR_BORDE := Color(0.68, 0.46, 0.16, 1.0)
const COLOR_LLENO := Color(0.87, 0.56, 0.20, 1.0)
const COLOR_LLENO_SOMBRA := Color(0.47, 0.23, 0.08, 1.0)
const COLOR_TEXTO := Color(1.0, 0.95, 0.85, 1.0)
const COLOR_TEXTO_SUAVE := Color(0.90, 0.80, 0.62, 0.95)

var _raiz: Control
var _contenedor: Control
var _barra: BarraVidaOrnamental
var _label_titulo: Label
var _label_valor: Label
var _vida_actual: float = 1000.0
var _vida_maxima: float = 1000.0
var _objetivo: Node = null
var _tween: Tween
var _fuente_titulo: Font
var _fuente_valor: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if limpiar_hijos_existentes:
		for hijo in get_children():
			hijo.queue_free()
	_fuente_titulo = _crear_fuente(4)
	_fuente_valor = _crear_fuente(2)
	_vida_actual = vida_inicial
	_vida_maxima = maxf(1.0, vida_maxima_inicial)
	_construir_interfaz()
	_actualizar_visual(false)
	if auto_buscar_grupo_jugador != "":
		var jugadores := get_tree().get_nodes_in_group(auto_buscar_grupo_jugador)
		if not jugadores.is_empty():
			vincular_objetivo(jugadores[0])


func vincular_objetivo(objetivo: Node) -> void:
	_objetivo = objetivo
	if _objetivo == null:
		return
	# Intenta leer la vida actual de varias formas comunes.
	_sincronizar_desde_objetivo()
	# Conectar señales conocidas, si existen.
	for nombre: String in ["vida_cambiada", "salud_cambiada", "health_changed"]:
		if _objetivo.has_signal(nombre):
			var callable := Callable(self, "_on_vida_objetivo_cambiada")
			if not _objetivo.is_connected(nombre, callable):
				_objetivo.connect(nombre, callable)
			break


func actualizar_vida(actual: float, maxima: float = -1.0, animar: bool = true) -> void:
	_vida_actual = maxf(0.0, actual)
	if maxima > 0.0:
		_vida_maxima = maxf(1.0, maxima)
	_vida_actual = minf(_vida_actual, _vida_maxima)
	_actualizar_visual(animar)


func curar(cantidad: float) -> void:
	actualizar_vida(_vida_actual + cantidad, _vida_maxima)


func recibir_danio(cantidad: float) -> void:
	actualizar_vida(_vida_actual - cantidad, _vida_maxima)


func _on_vida_objetivo_cambiada(actual, maxima = null) -> void:
	if maxima == null:
		actualizar_vida(float(actual), _vida_maxima)
	else:
		actualizar_vida(float(actual), float(maxima))


func _sincronizar_desde_objetivo() -> void:
	if _objetivo == null:
		return
	var actual := _leer_propiedad(_objetivo, ["vida", "salud", "health", "current_health", "hp"])
	var maxima := _leer_propiedad(_objetivo, ["vida_maxima", "salud_maxima", "max_health", "health_max", "max_hp"])
	if actual != null:
		_vida_actual = float(actual)
	if maxima != null:
		_vida_maxima = maxf(1.0, float(maxima))
	_vida_actual = clampf(_vida_actual, 0.0, _vida_maxima)
	_actualizar_visual(false)


func _leer_propiedad(objetivo: Object, candidatas: Array[String]):
	for nombre in candidatas:
		if _tiene_propiedad(objetivo, nombre):
			return objetivo.get(nombre)
	return null


func _tiene_propiedad(objetivo: Object, nombre: String) -> bool:
	for p in objetivo.get_property_list():
		if String(p.name) == nombre:
			return true
	return false


func _construir_interfaz() -> void:
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_contenedor = Control.new()
	_contenedor.position = Vector2(margen_izquierdo, margen_superior)
	_contenedor.custom_minimum_size = Vector2(ancho_barra + 120.0, 120.0)
	_contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_contenedor)

	if mostrar_titulo:
		_label_titulo = Label.new()
		_label_titulo.text = titulo
		_label_titulo.position = Vector2(62.0, -2.0)
		_label_titulo.add_theme_font_override("font", _fuente_titulo)
		_label_titulo.add_theme_font_size_override("font_size", 20)
		_label_titulo.add_theme_color_override("font_color", COLOR_TEXTO_SUAVE)
		_label_titulo.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
		_label_titulo.add_theme_constant_override("outline_size", 5)
		_contenedor.add_child(_label_titulo)

	_barra = BarraVidaOrnamental.new()
	_barra.position = Vector2(0.0, 24.0)
	_barra.custom_minimum_size = Vector2(ancho_barra, 72.0)
	_barra.size = _barra.custom_minimum_size
	_contenedor.add_child(_barra)

	if mostrar_texto_valor:
		_label_valor = Label.new()
		_label_valor.position = Vector2(72.0, 37.0)
		_label_valor.size = Vector2(ancho_barra - 90.0, 28.0)
		_label_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label_valor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label_valor.add_theme_font_override("font", _fuente_valor)
		_label_valor.add_theme_font_size_override("font_size", 18)
		_label_valor.add_theme_color_override("font_color", COLOR_TEXTO)
		_label_valor.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		_label_valor.add_theme_constant_override("outline_size", 6)
		_contenedor.add_child(_label_valor)


func _actualizar_visual(animar: bool) -> void:
	var fraccion := clampf(_vida_actual / maxf(1.0, _vida_maxima), 0.0, 1.0)
	if animar:
		if _tween != null:
			_tween.kill()
		_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_method(_set_fraccion_barra, _barra.fraccion_mostrada, fraccion, 0.28) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_set_fraccion_barra(fraccion)
	if _label_valor != null:
		_label_valor.text = "%d / %d" % [int(round(_vida_actual)), int(round(_vida_maxima))]


func _set_fraccion_barra(valor: float) -> void:
	_barra.fraccion_mostrada = valor
	_barra.queue_redraw()


func _crear_fuente(espaciado: int) -> Font:
	var base: Font = null
	var rutas := ["res://fuentes/menu.ttf", "res://assets/fonts/menu.ttf"]
	for ruta in rutas:
		if ResourceLoader.exists(ruta):
			base = load(ruta) as Font
			break
	if base == null:
		var sistema := SystemFont.new()
		sistema.font_names = PackedStringArray([
			"Segoe UI Semibold", "Segoe UI", "Calibri", "Arial"
		])
		base = sistema
	var variacion := FontVariation.new()
	variacion.base_font = base
	variacion.spacing_glyph = espaciado
	return variacion


class BarraVidaOrnamental extends Control:
	var fraccion_mostrada: float = 1.0
	var _brillo_tiempo: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		_brillo_tiempo += delta
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2(58.0, 14.0), Vector2(size.x - 70.0, 30.0))
		var glow := 0.65 + 0.35 * sin(_brillo_tiempo * 1.8)

		# Emblema izquierdo
		var centro := Vector2(28.0, 29.0)
		draw_circle(centro, 21.0, Color(COLOR_ORO_OSCURO, 0.95))
		draw_circle(centro, 18.0, Color(COLOR_ORO, 0.88))
		draw_circle(centro, 12.0, Color(COLOR_FONDO, 1.0))
		draw_arc(centro, 15.0, 0.0, TAU, 48, Color(COLOR_ORO_CLARO, 0.9), 2.0, true)
		for i in range(8):
			var ang := float(i) / 8.0 * TAU
			var a := centro + Vector2.from_angle(ang) * 8.0
			var b := centro + Vector2.from_angle(ang) * 15.0
			draw_line(a, b, Color(COLOR_ORO_CLARO, 0.65), 1.2)

		# Sombra exterior
		draw_rect(rect.grow(6.0), Color(0.0, 0.0, 0.0, 0.24), true)

		# Marco principal
		_draw_panel_ornamental(rect)

		# Fondo interior
		var interior := rect.grow(-5.0)
		draw_rect(interior, COLOR_FONDO, true)
		# Patrón sutil
		for i in range(12):
			var x := interior.position.x + 10.0 + float(i) * ((interior.size.x - 20.0) / 11.0)
			draw_line(Vector2(x, interior.position.y + 3.0), Vector2(x, interior.end.y - 3.0), Color(COLOR_ORO, 0.04), 1.0)

		# Barra de vida
		var margen := 6.0
		var relleno_total := Rect2(interior.position + Vector2(margen, margen), interior.size - Vector2(margen * 2.0, margen * 2.0))
		var ancho := relleno_total.size.x * fraccion_mostrada
		var relleno := Rect2(relleno_total.position, Vector2(maxf(0.0, ancho), relleno_total.size.y))
		if relleno.size.x > 0.0:
			draw_rect(relleno, Color(COLOR_LLENO_SOMBRA, 0.95), true)
			var grad_superior := Rect2(relleno.position, Vector2(relleno.size.x, relleno.size.y * 0.55))
			draw_rect(grad_superior, Color(COLOR_ORO_CLARO.lerp(COLOR_LLENO, 0.35), 0.55 + 0.25 * glow), true)
			for i in range(3):
				var brillo_x := relleno.position.x + clampf(fposmod(_brillo_tiempo * 90.0 + float(i) * 110.0, maxf(1.0, relleno.size.x)), 0.0, relleno.size.x)
				draw_rect(Rect2(Vector2(brillo_x, relleno.position.y + 2.0), Vector2(12.0, relleno.size.y - 4.0)), Color(1.0, 0.93, 0.75, 0.07), true)

		# Borde fino interior
		draw_rect(relleno_total, Color(COLOR_ORO_CLARO, 0.18), false, 1.0)

		# Adornos a la derecha
		var dx := rect.end.x + 8.0
		var cy := rect.get_center().y
		draw_line(Vector2(rect.end.x - 3.0, cy), Vector2(dx + 16.0, cy), Color(COLOR_ORO, 0.65), 1.4)
		draw_circle(Vector2(dx + 22.0, cy), 3.2, Color(COLOR_ORO_CLARO, 0.95))
		draw_circle(Vector2(dx + 30.0, cy), 1.8, Color(COLOR_ORO, 0.80))

	func _draw_panel_ornamental(rect: Rect2) -> void:
		draw_rect(rect, Color(COLOR_ORO_OSCURO, 0.95), true)
		draw_rect(rect, Color(COLOR_BORDE, 1.0), false, 2.0)
		var rect2 := rect.grow(-3.0)
		draw_rect(rect2, Color(COLOR_ORO, 0.22), false, 1.0)
		# puntas decorativas
		for s in [0.0, 1.0]:
			var x := rect.position.x if s == 0.0 else rect.end.x
			var signo := -1.0 if s == 0.0 else 1.0
			var y := rect.get_center().y
			var rombo := PackedVector2Array([
				Vector2(x + signo * 6.0, y),
				Vector2(x + signo * 14.0, y - 7.0),
				Vector2(x + signo * 22.0, y),
				Vector2(x + signo * 14.0, y + 7.0),
			])
			draw_colored_polygon(rombo, Color(COLOR_ORO_OSCURO, 0.9))
			draw_polyline(PackedVector2Array([rombo[0], rombo[1], rombo[2], rombo[3], rombo[0]]), Color(COLOR_ORO_CLARO, 0.8), 1.2, true)
