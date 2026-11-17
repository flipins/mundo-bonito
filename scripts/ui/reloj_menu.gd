extends VBoxContainer
## Pantalla "Reloj" del menú de pausa: un reloj de bolsillo arcano para cambiar la hora del juego.
## Sustituye a la cama. Guardar como: res://scripts/ui/reloj_menu.gd
##
## - Flechas izquierda / derecha: atrasan o adelantan la hora (un toque = 15 min, mantener = rápido).
## - Sol: salta al mediodía.  Atardecer: salta al anochecer.
## Todo se dibuja por código; menu_pausa.gd lo crea y le añade el botón "Volver".

const HORA_MEDIODIA := 12.0
const HORA_ATARDECER := 19.0
const PASO_TOQUE := 0.25
const VELOCIDAD_MANTENER := 4.0 ## Horas del juego por segundo mientras se mantiene una flecha.
const ESPERA_MANTENER := 0.4

const LATON := Color(0.78, 0.58, 0.24)
const LATON_OSCURO := Color(0.36, 0.24, 0.10)
const LATON_CLARO := Color(0.96, 0.80, 0.45)
const CARA := Color(0.15, 0.10, 0.07)
const RUNA := Color(1.0, 0.55, 0.15)
const NUMERAL := Color(0.93, 0.80, 0.52)

var _hora: float = 12.0
var _esfera: Esfera
var _pie: Pie
var _direccion: int = 0
var _mantenido: float = 0.0
var _primer_boton: Control


func construir(fuente: Font) -> void:
	add_theme_constant_override("separation", 4)

	# Reloj con una flecha a cada lado.
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_BEGIN
	fila.add_theme_constant_override("separation", 6)
	add_child(fila)
	var izq := BotonIcono.new("izq")
	izq.button_down.connect(_apretar.bind(-1))
	izq.button_up.connect(_soltar)
	_primer_boton = izq
	fila.add_child(izq)
	_esfera = Esfera.new()
	_esfera.fuente = fuente
	fila.add_child(_esfera)
	var der := BotonIcono.new("der")
	der.button_down.connect(_apretar.bind(1))
	der.button_up.connect(_soltar)
	fila.add_child(der)
	for b: Control in [izq, der]:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Debajo: sol, hora digital y atardecer.
	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 6)
	add_child(abajo)
	var sol := BotonIcono.new("sol")
	sol.pressed.connect(saltar.bind(HORA_MEDIODIA))
	abajo.add_child(sol)
	_pie = Pie.new()
	_pie.fuente = fuente
	_pie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abajo.add_child(_pie)
	var ocaso := BotonIcono.new("ocaso")
	ocaso.pressed.connect(saltar.bind(HORA_ATARDECER))
	abajo.add_child(ocaso)

	# Ancho total: flecha + reloj + flecha.
	custom_minimum_size = Vector2(Esfera.ANCHO + 2.0 * BotonIcono.LADO + 12.0, 0.0)


## Primer botón que recibe el foco al entrar (el de la flecha izquierda).
func primer_foco() -> Control:
	return _primer_boton


## Se llama al abrir la pantalla: lee la hora actual del juego.
func abrir() -> void:
	_hora = Reloj.hora
	_direccion = 0
	_refrescar()


func _process(delta: float) -> void:
	if not visible or _direccion == 0:
		return
	_mantenido += delta
	if _mantenido > ESPERA_MANTENER:
		cambiar(_direccion * VELOCIDAD_MANTENER * delta)


func _apretar(dir: int) -> void:
	_direccion = dir
	_mantenido = 0.0
	cambiar(dir * PASO_TOQUE)


func _soltar() -> void:
	_direccion = 0


func saltar(hora: float) -> void:
	_hora = fposmod(hora, 24.0)
	Reloj.saltar_a_hora(_hora)
	_refrescar()


func cambiar(horas: float) -> void:
	saltar(_hora + horas)


func _refrescar() -> void:
	_esfera.hora = _hora
	var h := int(_hora)
	var m := int((_hora - float(h)) * 60.0)
	_pie.texto = "%02d:%02d" % [h, m]
	_pie.queue_redraw()
	_esfera.queue_redraw()


# ------------------------------------------------------------------------------------
# El reloj de bolsillo
# ------------------------------------------------------------------------------------

class Esfera extends Control:
	const ANCHO := 300.0
	const ALTO := 340.0
	const NUMEROS := ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]

	var hora: float = 12.0
	var fuente: Font
	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(ANCHO, ALTO)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 200.0)
		var r := 128.0
		_cadena(c, r)
		_caja(c, r)
		_runas(c, r)
		_cara(c, r)
		_agujas(c, r)

	func _cadena(c: Vector2, r: float) -> void:
		# Corona (la rueda para dar cuerda) y tres eslabones que suben.
		draw_rect(Rect2(c.x - 11.0, c.y - r - 16.0, 22.0, 16.0), LATON_OSCURO)
		draw_rect(Rect2(c.x - 9.0, c.y - r - 16.0, 18.0, 14.0), LATON)
		for i in range(3):
			var y := c.y - r - 26.0 - float(i) * 20.0
			var ancho := 0.55 if i % 2 == 0 else 0.2
			draw_set_transform(Vector2(c.x, y), 0.0, Vector2(ancho, 1.0))
			draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, LATON_OSCURO, 5.0)
			draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, LATON, 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _caja(c: Vector2, r: float) -> void:
		draw_circle(c, r + 4.0, LATON_OSCURO)
		draw_circle(c, r, LATON)
		draw_circle(c, r - 7.0, LATON_OSCURO)
		# Anillo oscuro donde brillan las runas.
		draw_circle(c, r * 0.93, Color(0.09, 0.05, 0.035))
		draw_arc(c, r * 0.945, 0.0, TAU, 96, LATON_CLARO, 2.0, true)

	func _runas(c: Vector2, r: float) -> void:
		var n := 24
		for i in range(n):
			var ang := float(i) / n * TAU
			var pulso := 0.6 + 0.4 * sin(_t * 1.6 + float(i) * 0.7)
			draw_set_transform(c + Vector2.from_angle(ang - PI * 0.5) * r * 0.865, ang, Vector2.ONE)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7919 + i * 31
			var trazos: Array = [[Vector2(0.0, -8.0), Vector2(0.0, 8.0)]]
			for k in range(2 + rng.randi() % 2):
				var a := Vector2(rng.randi_range(-1, 1) * 4.0, rng.randi_range(-2, 2) * 3.5)
				var b := Vector2(rng.randi_range(-1, 1) * 4.0, rng.randi_range(-2, 2) * 3.5)
				if a.distance_to(b) > 1.0:
					trazos.append([a, b])
			for tr: Array in trazos:
				draw_line(tr[0], tr[1], Color(RUNA, 0.22 * pulso), 5.0)
				draw_line(tr[0], tr[1], Color(1.0, 0.65, 0.25, 0.55 + 0.45 * pulso), 1.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _cara(c: Vector2, r: float) -> void:
		draw_circle(c, r * 0.78, LATON)
		draw_circle(c, r * 0.76, CARA)
		draw_arc(c, r * 0.72, 0.0, TAU, 96, Color(LATON, 0.6), 1.5, true)
		# Marcas de los minutos.
		for i in range(60):
			var dir := Vector2.from_angle(float(i) / 60.0 * TAU - PI * 0.5)
			var largo := 8.0 if i % 5 == 0 else 3.5
			draw_line(c + dir * r * 0.72, c + dir * (r * 0.72 - largo), Color(NUMERAL, 0.8), 1.5 if i % 5 == 0 else 1.0)
		# Números romanos.
		if fuente != null:
			for i in range(12):
				var p := c + Vector2.from_angle(float(i) / 12.0 * TAU - PI * 0.5) * r * 0.54
				var tam := 17
				var s: String = NUMEROS[i]
				var med := fuente.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
				draw_string(fuente, p + Vector2(-med.x * 0.5, tam * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, NUMERAL)

	func _agujas(c: Vector2, r: float) -> void:
		var ang_h := fposmod(hora, 12.0) / 12.0 * TAU - PI * 0.5
		var ang_m := fposmod(hora, 1.0) * TAU - PI * 0.5
		_aguja(c, ang_h, r * 0.38, 9.0)
		_aguja(c, ang_m, r * 0.58, 6.0)
		draw_circle(c, 7.0, LATON_OSCURO)
		draw_circle(c, 5.0, LATON_CLARO)

	func _aguja(c: Vector2, ang: float, largo: float, ancho: float) -> void:
		var d := Vector2.from_angle(ang)
		var p := d.orthogonal()
		var pts := PackedVector2Array([
			c - d * 12.0,
			c + d * largo * 0.28 + p * ancho * 0.5,
			c + d * largo,
			c + d * largo * 0.28 - p * ancho * 0.5,
		])
		draw_colored_polygon(pts, LATON)
		var borde := pts.duplicate()
		borde.append(pts[0])
		draw_polyline(borde, LATON_OSCURO, 1.5, true)


# ------------------------------------------------------------------------------------
# Hora digital con adornos
# ------------------------------------------------------------------------------------

class Pie extends Control:
	var texto: String = "12:00"
	var fuente: Font

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 64.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var tam := 38
		var med := Vector2(100.0, 30.0)
		if fuente != null:
			med = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
			draw_string(fuente, Vector2(c.x - med.x * 0.5, c.y + tam * 0.35), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, NUMERAL)
		# Rayas adornadas a los lados del número.
		for lado in [-1.0, 1.0]:
			var x0: float = c.x + lado * (med.x * 0.5 + 14.0)
			var x1: float = c.x + lado * (med.x * 0.5 + 14.0 + 46.0)
			draw_line(Vector2(x0, c.y), Vector2(x1, c.y), Color(LATON, 0.8), 1.5)
			draw_line(Vector2(x0, c.y + 5.0), Vector2(x1 - lado * 12.0, c.y + 5.0), Color(LATON, 0.45), 1.0)
			draw_circle(Vector2(x1 + lado * 5.0, c.y), 2.5, LATON_CLARO)


# ------------------------------------------------------------------------------------
# Botones redondos con icono (flechas, sol y atardecer)
# ------------------------------------------------------------------------------------

class BotonIcono extends Button:
	const LADO := 64.0
	var tipo: String

	func _init(tipo_: String) -> void:
		tipo = tipo_
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(LADO, LADO)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var vacio := StyleBoxEmpty.new()
		for estilo: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(estilo, vacio)
		mouse_entered.connect(grab_focus)
		for senal: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up]:
			senal.connect(queue_redraw)

	func _draw() -> void:
		var activo := has_focus() or is_hovered()
		var col := LATON_CLARO if activo else LATON
		var c := size * 0.5
		draw_circle(c, 26.0, Color(0.12, 0.08, 0.05, 0.85))
		draw_arc(c, 26.0, 0.0, TAU, 40, col, 2.5, true)
		if activo:
			draw_arc(c, 29.0, 0.0, TAU, 40, Color(RUNA, 0.45), 2.0, true)
		match tipo:
			"izq":
				draw_polyline(PackedVector2Array([c + Vector2(6, -11), c + Vector2(-6, 0), c + Vector2(6, 11)]), col, 3.5, true)
			"der":
				draw_polyline(PackedVector2Array([c + Vector2(-6, -11), c + Vector2(6, 0), c + Vector2(-6, 11)]), col, 3.5, true)
			"sol":
				draw_circle(c, 6.5, col)
				for i in range(8):
					var d := Vector2.from_angle(float(i) / 8.0 * TAU)
					draw_line(c + d * 10.5, c + d * 15.0, col, 2.5)
			"ocaso":
				var base := c + Vector2(0.0, 5.0)
				draw_arc(base, 8.0, PI, TAU, 16, col, 3.5, true)
				draw_line(base + Vector2(-16.0, 0.0), base + Vector2(16.0, 0.0), col, 2.5)
				draw_line(base + Vector2(-9.0, 6.0), base + Vector2(9.0, 6.0), Color(col, 0.6), 2.0)
				for i in range(5):
					var d := Vector2.from_angle(PI + float(i) / 4.0 * PI)
					draw_line(base + d * 12.0, base + d * 16.0, col, 2.5)
