extends Node
## Opciones de rendimiento y contador de FPS.
##
## Lo crea el autoload "Ajustes" (queda disponible como Ajustes.rendimiento), así que funciona
## en todas las escenas sin tocar Project Settings. Guarda sus valores en user://rendimiento.cfg.
##
## Atajo: F3 muestra u oculta el contador de FPS en cualquier momento.
##
## El contador muestra los FPS, cuánto tarda el CPU y la GPU en dibujar cada frame, la resolución
## real a la que se dibuja, cuántas llamadas de dibujo y triángulos hay, la memoria de video,
## la frecuencia de la pantalla y qué gráfica está usando el juego (integrada o dedicada).

## Se emite cada vez que cambia una opción.
signal cambiado

const RUTA_ARCHIVO := "user://rendimiento.cfg"
const META_ORIGINAL := &"rendimiento_original"

## Escalas de resolución 3D disponibles (1.0 = resolución completa). La interfaz siempre se
## dibuja a resolución completa; solo el mundo 3D baja de resolución.
const ESCALAS: Array[float] = [1.0, 0.85, 0.75, 0.6, 0.5]

var mostrar_fps: bool = false
var escala_indice: int = 0
var sombras: bool = true
var niebla_volumetrica: bool = true
var ssao: bool = true
var glow: bool = true
var vsync: bool = true

var _capa: CanvasLayer
var _etiqueta: Label
var _info_gpu: String = ""
var _acumulado: float = 0.0


func _ready() -> void:
	# Tiene que seguir funcionando con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_info_gpu = _leer_info_gpu()
	_crear_contador()
	cargar()
	# Cada vez que entra un WorldEnvironment al árbol (al cambiar de escena) se le aplican las opciones.
	get_tree().node_added.connect(_on_nodo_agregado)
	aplicar_todo()


func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F3:
		alternar(&"mostrar_fps")
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < 0.25:
		return
	_acumulado = 0.0
	_etiqueta.text = _armar_texto()


# ---------------------------------------------------------------- Opciones (para armar el menú)

## Opciones en el orden en que se muestran: id y título.
func opciones() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	lista.append({"id": &"mostrar_fps", "titulo": "Mostrar FPS"})
	lista.append({"id": &"escala", "titulo": "Resolución 3D"})
	lista.append({"id": &"sombras", "titulo": "Sombras"})
	lista.append({"id": &"niebla", "titulo": "Niebla volumétrica"})
	lista.append({"id": &"ssao", "titulo": "Oclusión ambiental"})
	lista.append({"id": &"glow", "titulo": "Resplandor"})
	lista.append({"id": &"vsync", "titulo": "VSync"})
	return lista


## Texto del botón de una opción, con su valor actual.
func texto(id: StringName) -> String:
	match id:
		&"mostrar_fps":
			return "Mostrar FPS (F3): %s" % _si_no(mostrar_fps)
		&"escala":
			return "Resolución 3D: %d%%" % roundi(_escala_actual() * 100.0)
		&"sombras":
			return "Sombras: %s" % _si_no(sombras)
		&"niebla":
			return "Niebla volumétrica: %s" % _si_no(niebla_volumetrica)
		&"ssao":
			return "Oclusión ambiental (SSAO): %s" % _si_no(ssao)
		&"glow":
			return "Resplandor (Glow): %s" % _si_no(glow)
		&"vsync":
			return "VSync: %s" % _si_no(vsync)
	return String(id)


## Cambia una opción al siguiente valor (las de sí/no se invierten; la resolución recorre sus escalas).
func alternar(id: StringName) -> void:
	match id:
		&"mostrar_fps":
			mostrar_fps = not mostrar_fps
			_aplicar_contador()
		&"escala":
			escala_indice = (escala_indice + 1) % ESCALAS.size()
			_aplicar_escala()
		&"sombras":
			# No hay nada que aplicar aquí: ciclo_dia.gd lee este valor en cada frame.
			sombras = not sombras
		&"niebla":
			niebla_volumetrica = not niebla_volumetrica
			_aplicar_entornos()
		&"ssao":
			ssao = not ssao
			_aplicar_entornos()
		&"glow":
			glow = not glow
			_aplicar_entornos()
		&"vsync":
			vsync = not vsync
			_aplicar_vsync()
	guardar()
	cambiado.emit()


func aplicar_todo() -> void:
	_aplicar_escala()
	_aplicar_vsync()
	_aplicar_contador()
	_aplicar_entornos()


# ---------------------------------------------------------------- Guardar y cargar

func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rendimiento", "mostrar_fps", mostrar_fps)
	cfg.set_value("rendimiento", "escala_indice", escala_indice)
	cfg.set_value("rendimiento", "sombras", sombras)
	cfg.set_value("rendimiento", "niebla_volumetrica", niebla_volumetrica)
	cfg.set_value("rendimiento", "ssao", ssao)
	cfg.set_value("rendimiento", "glow", glow)
	cfg.set_value("rendimiento", "vsync", vsync)
	cfg.save(RUTA_ARCHIVO)


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_ARCHIVO) != OK:
		return # Primera vez que se abre el juego: se quedan los valores por defecto.
	mostrar_fps = bool(cfg.get_value("rendimiento", "mostrar_fps", false))
	escala_indice = clampi(int(cfg.get_value("rendimiento", "escala_indice", 0)), 0, ESCALAS.size() - 1)
	sombras = bool(cfg.get_value("rendimiento", "sombras", true))
	niebla_volumetrica = bool(cfg.get_value("rendimiento", "niebla_volumetrica", true))
	ssao = bool(cfg.get_value("rendimiento", "ssao", true))
	glow = bool(cfg.get_value("rendimiento", "glow", true))
	vsync = bool(cfg.get_value("rendimiento", "vsync", true))


# ---------------------------------------------------------------- Aplicar cada opción

func _escala_actual() -> float:
	return ESCALAS[clampi(escala_indice, 0, ESCALAS.size() - 1)]


func _aplicar_escala() -> void:
	var raiz: Window = get_tree().root
	var escala: float = _escala_actual()
	raiz.scaling_3d_scale = escala
	# Por debajo del 100 % se reescala con FSR, que se ve mucho mejor que un simple estiramiento.
	if escala < 0.999:
		raiz.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	else:
		raiz.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR


func _aplicar_vsync() -> void:
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _aplicar_contador() -> void:
	_etiqueta.visible = mostrar_fps
	set_process(mostrar_fps)
	# Medir el tiempo de render cuesta un poco, así que solo se hace con el contador visible.
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), mostrar_fps)
	if mostrar_fps:
		_etiqueta.text = _armar_texto()
		_acumulado = 0.0


func _aplicar_entornos() -> void:
	for nodo in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_aplicar_entorno(nodo as WorldEnvironment)


func _on_nodo_agregado(nodo: Node) -> void:
	if nodo is WorldEnvironment:
		# En diferido, para que ciclo_dia.gd ya haya hecho su copia del Environment.
		_aplicar_entorno.call_deferred(nodo)


func _aplicar_entorno(mundo: WorldEnvironment) -> void:
	if mundo == null or not is_instance_valid(mundo):
		return
	var entorno: Environment = mundo.environment
	if entorno == null:
		return
	# Se guarda cómo estaba cada efecto en la escena: apagar una opción lo apaga, y encenderla
	# lo deja como lo diseñaste (si en esa escena ya estaba apagado, sigue apagado).
	if not entorno.has_meta(META_ORIGINAL):
		entorno.set_meta(META_ORIGINAL, {
			"niebla": entorno.volumetric_fog_enabled,
			"ssao": entorno.ssao_enabled,
			"glow": entorno.glow_enabled,
		})
	var original: Dictionary = entorno.get_meta(META_ORIGINAL)
	entorno.volumetric_fog_enabled = bool(original["niebla"]) and niebla_volumetrica
	entorno.ssao_enabled = bool(original["ssao"]) and ssao
	entorno.glow_enabled = bool(original["glow"]) and glow


# ---------------------------------------------------------------- Contador de FPS

func _crear_contador() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 100
	add_child(_capa)

	_etiqueta = Label.new()
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_etiqueta.add_theme_font_size_override("font_size", 18)
	_etiqueta.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_etiqueta.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_etiqueta.add_theme_constant_override("outline_size", 6)
	# Pegado arriba a la derecha: si el texto crece, crece hacia la izquierda.
	_etiqueta.anchor_left = 1.0
	_etiqueta.anchor_right = 1.0
	_etiqueta.offset_left = -16.0
	_etiqueta.offset_right = -14.0
	_etiqueta.offset_top = 10.0
	_etiqueta.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_etiqueta.visible = false
	_capa.add_child(_etiqueta)


func _armar_texto() -> String:
	var fps: int = int(Engine.get_frames_per_second())
	var ms: float = 1000.0 / maxf(float(fps), 1.0)

	# Tiempo que tarda el render en el CPU y en la GPU (la GPU puede no reportarlo en algunos equipos).
	var rid: RID = get_viewport().get_viewport_rid()
	var cpu: float = RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var gpu_texto: String = "no disponible"
	if gpu > 0.0:
		gpu_texto = "%.1f ms" % gpu

	# Resolución real a la que se dibuja el mundo 3D.
	var px: Vector2i = Vector2i(Vector2(get_window().size) * _escala_actual())

	var llamadas: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var triangulos: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var memoria: int = roundi(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)

	var lineas := PackedStringArray()
	lineas.append("%d FPS  (%.1f ms por frame)" % [fps, ms])
	lineas.append("Render: CPU %.1f ms  ·  GPU %s" % [cpu, gpu_texto])
	lineas.append("Dibuja a %d×%d (%d%%)" % [px.x, px.y, roundi(_escala_actual() * 100.0)])
	lineas.append("Llamadas de dibujo %s  ·  Triángulos %s" % [_miles(llamadas), _miles(triangulos)])
	lineas.append("Memoria de video: %d MB" % memoria)
	var hz: float = DisplayServer.screen_get_refresh_rate()
	if hz > 0.0:
		var con_vsync: bool = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
		lineas.append("Pantalla %d Hz  ·  VSync %s" % [roundi(hz), _si_no(con_vsync)])
	lineas.append(_info_gpu)
	return "\n".join(lineas)


# Nombre de la gráfica y de qué tipo es: así se ve enseguida si el juego usa la integrada por error.
func _leer_info_gpu() -> String:
	var tipo: String = "tipo desconocido"
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			tipo = "integrada"
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			tipo = "dedicada"
		RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
			tipo = "virtual"
		RenderingDevice.DEVICE_TYPE_CPU:
			tipo = "por software (CPU)"
	return "%s (%s)  ·  %s" % [
		RenderingServer.get_video_adapter_name(),
		tipo,
		RenderingServer.get_current_rendering_driver_name(),
	]


func _si_no(valor: bool) -> String:
	return "Sí" if valor else "No"


# 1234567 -> "1.234.567"
func _miles(numero: int) -> String:
	var digitos: String = str(absi(numero))
	var resultado: String = ""
	var contador: int = 0
	for i in range(digitos.length() - 1, -1, -1):
		resultado = digitos[i] + resultado
		contador += 1
		if contador % 3 == 0 and i > 0:
			resultado = "." + resultado
	return resultado
