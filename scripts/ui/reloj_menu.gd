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

## Modelo 3D del reloj. Si no está en el proyecto, se usa el reloj dibujado por código.
const RUTA_MODELO := "res://assets/models/reloj_steampunk_3d.glb"

const LATON := Color(0.78, 0.58, 0.24)
const LATON_OSCURO := Color(0.36, 0.24, 0.10)
const LATON_CLARO := Color(0.96, 0.80, 0.45)
const CARA := Color(0.88, 0.80, 0.64)
const TINTA := Color(0.14, 0.09, 0.06)
const RUNA := Color(1.0, 0.55, 0.15)
const NUMERAL := Color(0.93, 0.80, 0.52)

var _hora: float = 12.0
var _esfera ## Esfera3D (modelo) o Esfera (dibujo de respaldo)
var _pie: Pie
var _direccion: int = 0
var _mantenido: float = 0.0
var _primer_boton: Control


func construir(fuente: Font) -> void:
	# Que no se estire a todo el ancho de la columna del menú.
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_constant_override("separation", 0)

	# Como en el diseño: flecha, sol, reloj, atardecer, flecha.
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	add_child(fila)
	var izq := BotonIcono.new("izq")
	izq.button_down.connect(_apretar.bind(-1))
	izq.button_up.connect(_soltar)
	_primer_boton = izq
	var sol := BotonIcono.new("sol")
	sol.pressed.connect(saltar.bind(HORA_MEDIODIA))
	if ResourceLoader.exists(RUTA_MODELO):
		_esfera = Esfera3D.new()
	else:
		_esfera = Esfera.new()
	_esfera.fuente = fuente
	var ocaso := BotonIcono.new("ocaso")
	ocaso.pressed.connect(saltar.bind(HORA_ATARDECER))
	var der := BotonIcono.new("der")
	der.button_down.connect(_apretar.bind(1))
	der.button_up.connect(_soltar)
	for n: Control in [izq, sol, _esfera, ocaso, der]:
		fila.add_child(n)
		if n != _esfera:
			n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# El sol y el atardecer se pegan al reloj.
	sol.custom_minimum_size = Vector2(BotonIcono.LADO, BotonIcono.LADO)

	_pie = Pie.new()
	_pie.fuente = fuente
	_pie.custom_minimum_size = Vector2(_esfera.custom_minimum_size.x + 4.0 * BotonIcono.LADO + 16.0, 64.0)
	add_child(_pie)


## Primer botón que recibe el foco al entrar (el de la flecha izquierda).
func primer_foco() -> Control:
	return _primer_boton


## Se llama al abrir la pantalla: lee la hora actual del juego.
func abrir() -> void:
	_hora = Reloj.hora
	_direccion = 0
	_refrescar()
	if _esfera.has_method("reproducir_caida"):
		_esfera.reproducir_caida()


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
		draw_arc(c, r * 0.72, 0.0, TAU, 96, Color(TINTA, 0.7), 1.5, true)
		draw_arc(c, r * 0.76, 0.0, TAU, 96, LATON_OSCURO, 3.0, true)
		# Marcas de los minutos.
		for i in range(60):
			var dir := Vector2.from_angle(float(i) / 60.0 * TAU - PI * 0.5)
			var largo := 8.0 if i % 5 == 0 else 3.5
			draw_line(c + dir * r * 0.72, c + dir * (r * 0.72 - largo), Color(TINTA, 0.85), 1.5 if i % 5 == 0 else 1.0)
		# Números romanos.
		if fuente != null:
			for i in range(12):
				var p := c + Vector2.from_angle(float(i) / 12.0 * TAU - PI * 0.5) * r * 0.54
				var tam := 17
				var s: String = NUMEROS[i]
				var med := fuente.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
				draw_string(fuente, p + Vector2(-med.x * 0.5, tam * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, TINTA)

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
		draw_colored_polygon(pts, TINTA)
		var borde := pts.duplicate()
		borde.append(pts[0])
		draw_polyline(borde, Color(0.4, 0.28, 0.12), 1.0, true)


# ------------------------------------------------------------------------------------
# El reloj en 3D: cuelga de una cadena y cae al abrir la pantalla
# ------------------------------------------------------------------------------------

class Esfera3D extends SubViewportContainer:
	const ANCHO := 340.0
	const ALTO := 400.0
	## Altura del anillo del reloj en el modelo (donde se engancha la cadena).
	const ANILLO := 1.757
	const PIVOTE_Y := 2.2
	const ALTURA_CAIDA := 6.0
	const GRAVEDAD := 24.0
	## El modelo viene con las agujas marcando las 10:25.
	const HORA_MODELO := 10.0 + 25.0 / 60.0

	var hora: float = 12.0:
		set(v):
			hora = v
			_poner_agujas()
	var fuente: Font ## No se usa; existe para que se parezca a Esfera.

	var _pivote: Node3D
	var _aguja_hora: Node3D
	var _aguja_min: Node3D
	var _y: float = 0.0
	var _vy: float = 0.0
	var _cayendo: bool = false
	var _ang: float = 0.0
	var _w: float = 0.0
	var _giro: float = 0.0
	var _wg: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(ANCHO, ALTO)
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		add_child(vp)

		# Luz y reflejos cálidos para que el metal se vea dorado y no negro.
		var cielo := ProceduralSkyMaterial.new()
		cielo.sky_top_color = Color(0.30, 0.18, 0.09)
		cielo.sky_horizon_color = Color(1.0, 0.78, 0.48)
		cielo.ground_horizon_color = Color(0.55, 0.34, 0.16)
		cielo.ground_bottom_color = Color(0.10, 0.06, 0.03)
		var sky := Sky.new()
		sky.sky_material = cielo
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var sol := DirectionalLight3D.new()
		sol.light_color = Color(1.0, 0.88, 0.7)
		sol.light_energy = 1.3
		sol.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
		vp.add_child(sol)
		var foco := OmniLight3D.new()
		foco.light_color = Color(1.0, 0.75, 0.45)
		foco.light_energy = 2.0
		foco.omni_range = 14.0
		foco.position = Vector3(2.0, 2.0, 5.0)
		vp.add_child(foco)

		var cam := Camera3D.new()
		cam.fov = 36.0
		cam.position = Vector3(0.0, 0.5, 6.5)
		vp.add_child(cam)
		cam.current = true

		# El pivote es el punto de donde cuelga todo; al girarlo, el reloj se balancea.
		_pivote = Node3D.new()
		vp.add_child(_pivote)
		var escena: PackedScene = load(RUTA_MODELO)
		var reloj: Node3D = escena.instantiate()
		reloj.position = Vector3(0.0, -ANILLO, 0.0)
		_pivote.add_child(reloj)
		_aguja_hora = reloj.find_child("HourHand", true, false)
		_aguja_min = reloj.find_child("MinuteHand", true, false)
		_cadena()
		_poner_agujas()
		_colocar()

	func _cadena() -> void:
		var laton := StandardMaterial3D.new()
		laton.albedo_color = Color(0.72, 0.52, 0.24)
		laton.metallic = 1.0
		laton.roughness = 0.35
		for i in range(24):
			var aro := TorusMesh.new()
			aro.inner_radius = 0.10
			aro.outer_radius = 0.26
			aro.rings = 20
			aro.ring_segments = 10
			var mi := MeshInstance3D.new()
			mi.mesh = aro
			mi.material_override = laton
			# Eslabones alternados: uno de frente y el siguiente de canto.
			var b := Basis(Vector3.RIGHT, PI * 0.5)
			if i % 2 == 1:
				b = Basis(Vector3.UP, PI * 0.5) * b
			mi.basis = b.scaled(Vector3(1.0, 1.0, 1.0))
			mi.position = Vector3(0.0, 0.1 + 0.3 * float(i), 0.0)
			_pivote.add_child(mi)

	func _poner_agujas() -> void:
		if _aguja_hora == null or _aguja_min == null:
			return
		# Giran en sentido horario visto de frente (en Godot eso es rotación Z negativa).
		_aguja_hora.rotation.z = -(hora - HORA_MODELO) / 12.0 * TAU
		_aguja_min.rotation.z = -(fposmod(hora, 1.0) - 25.0 / 60.0) * TAU

	## El reloj cae desde arriba, la cadena lo frena de golpe y se balancea hasta quedarse quieto.
	func reproducir_caida() -> void:
		_y = ALTURA_CAIDA
		_vy = 0.0
		_cayendo = true
		_ang = 0.0
		_w = 0.0
		_giro = 0.0
		_wg = 0.0
		_colocar()

	func _colocar() -> void:
		if _pivote == null:
			return
		_pivote.position = Vector3(0.0, PIVOTE_Y + _y, 0.0)
		_pivote.rotation = Vector3(0.0, _giro, _ang)

	func _process(delta: float) -> void:
		if _pivote == null or not is_visible_in_tree():
			return
		var dt := minf(delta, 0.033)
		if _cayendo:
			_vy -= GRAVEDAD * dt
			_y += _vy * dt
			if _y <= 0.0:
				# La cadena se tensa: rebote corto y balanceo.
				_y = 0.0
				_vy *= 0.25
				_cayendo = false
				_w = 2.6
				_wg = 3.5
		else:
			# Resorte amortiguado en vertical.
			_vy += (-140.0 * _y - 7.0 * _vy) * dt
			_y += _vy * dt
		# Balanceo y pequeño giro, amortiguados.
		_w += (-22.0 * _ang - 1.8 * _w) * dt
		_ang += _w * dt
		_wg += (-30.0 * _giro - 2.5 * _wg) * dt
		_giro += _wg * dt
		_colocar()


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
				draw_colored_polygon(PackedVector2Array([c + Vector2(8, -12), c + Vector2(-9, 0), c + Vector2(8, 12)]), col)
			"der":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -12), c + Vector2(9, 0), c + Vector2(-8, 12)]), col)
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
