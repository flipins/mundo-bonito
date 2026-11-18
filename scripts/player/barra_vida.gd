class_name BarraVida
extends CanvasLayer
## HUD Mundo Bonito — v24 RUNA METAMÓRFICA ÚNICA. Tamaño FIJO 130 %.
## El MARCO es arte PNG transparente; la VIDA es un shader animado.
## Magia: dos semicírculos abiertos en UN SOLO sello, detrás del marco.
##
## Integrado con los sistemas reales del juego:
##   Inventario.objeto_agregado(id) / Inventario.objeto_quitado(id)
##   UAL1_Standard.con_espada
##   get_tree().get_first_node_in_group("barra_vida").recibir_dano(100)
##
## Rutas necesarias:
##   res://assets/hud/marco_barra_fina.png
##   res://assets/hud/marco_medallon.png
##   res://assets/hud/espada_interior.png

signal vida_cambiada(actual: int, maximo: int)
signal murio

@export var vida_maxima: int = 1000

# Tamaño definitivo: 130 %. Se aplica a TODO el HUD.
# No se lee ni se guarda ninguna preferencia del antiguo deslizador.
const ESCALA_HUD: float = 1.30

@export_group("Posición")
@export var margen_izquierdo: float = 16.0
@export var margen_superior: float = 16.0

@export_group("Proporciones")
## Diámetro del medallón, sin deformar la textura.
@export_range(95.0, 180.0, 1.0) var diametro_medallon: float = 124.0
## Longitud del marco horizontal, sin alterar el tamaño del medallón.
@export_range(300.0, 580.0, 5.0) var largo_barra: float = 410.0
## Grosor del marco horizontal (no agranda el medallón).
@export_range(18.0, 34.0, 1.0) var grosor_barra: float = 23.0

@export_group("Ajuste fino del relleno")
## Más margen = el rojo termina antes del remate derecho.
@export_range(10.0, 38.0, 0.5) var margen_derecho_relleno: float = 23.0
## Controla únicamente la altura de la sangre, no el grosor del marco.
@export_range(0.40, 0.75, 0.01) var proporcion_alto_relleno: float = 0.61
## Desplazamiento vertical desde el centro del marco: positivo = abajo.
@export_range(-2.0, 5.0, 0.25) var desplazamiento_y_relleno: float = 2.9

@export_group("Animación")
@export_range(1.0, 20.0, 0.5) var suavizado: float = 8.0
@export_range(0.4, 8.0, 0.2) var retardo_dano: float = 2.4
@export_range(0.0, 1.0, 0.05) var espera_dano: float = 0.26
@export var activar_efectos: bool = true
@export var mostrar_halo_arcano: bool = true

@export_group("Magia y sangre viva")
## Multiplica la intensidad de los reflejos y la circulación interior.
@export_range(0.0, 2.0, 0.05) var intensidad_sangre: float = 1.20
## Velocidad del movimiento de la sangre (sin afectar la vida real).
@export_range(0.25, 3.0, 0.05) var velocidad_sangre: float = 1.0
## Brillo del sello semicircular y sus runas.
@export_range(0.0, 2.0, 0.05) var intensidad_runas: float = 1.45
## Brillo de las runas del centro (sin piedras ni círculos nuevos).
@export_range(0.0, 2.0, 0.05) var intensidad_runas_centro: float = 1.30
## Movimiento lento y solemne: 0.35 es el valor recomendado.
@export_range(0.10, 1.0, 0.05) var velocidad_runas: float = 0.35
## Ajusta la posición horizontal del único sello sin cambiar el HUD.
@export_range(0.7, 1.5, 0.05) var separacion_sellos: float = 1.0
## Desplaza todos los sellos a la izquierda (negativo) o derecha (positivo).
## Se ajusta en el Inspector; no agrega un control al menú de Opciones.
@export_range(-35.0, 50.0, 1.0) var ajuste_horizontal_sellos: float = 0.0
## Pequeñas motas incandescentes dentro del canal rojo.
@export var mostrar_chispas_sangre: bool = true

@export_group("Espada")
@export var id_espada: StringName = &"espada"
@export var empieza_con_espada: bool = false

const TEX_BARRA: Texture2D = preload("res://assets/hud/marco_barra_fina.png")
const TEX_MEDALLON: Texture2D = preload("res://assets/hud/marco_medallon.png")
const TEX_ESPADA: Texture2D = preload("res://assets/hud/espada_interior.png")

# Únicamente colorea el canal central de la barra; no modifica las imágenes.
# Tiene: márgenes redondeados, vetas de sangre, reflejos, daño retardado y pulso bajo.
const SHADER_SANGRE: String = """
shader_type canvas_item;
render_mode blend_mix;

uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform float retraso : hint_range(0.0, 1.0) = 1.0;
uniform float golpe : hint_range(0.0, 1.0) = 0.0;
uniform float curacion : hint_range(0.0, 1.0) = 0.0;
uniform float pulso_bajo : hint_range(0.0, 1.0) = 0.0;
uniform vec2 dimensiones = vec2(350.0, 14.0);
uniform float intensidad = 1.20;
uniform float velocidad = 1.0;

// Ruido suave que se mueve continuamente dentro del cauce.
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm(vec2 p) {
    float n = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        n += ruido(p) * a;
        p *= 2.12;
        a *= 0.5;
    }
    return n;
}

float redondeado(vec2 p, vec2 size, float radius) {
    vec2 q = abs(p - size * 0.5) - (size * 0.5 - vec2(radius));
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

// Fina veta ondulante que viaja como un latido, sin mover el marco.
float veta(vec2 uv, float fase, float frecuencia, float amplitud) {
    float curva = 0.5 + 0.18 * sin(uv.x * frecuencia - fase);
    curva += 0.06 * sin(uv.x * frecuencia * 2.3 + fase * 0.71);
    return exp(-pow((uv.y - curva) / amplitud, 2.0));
}

void fragment() {
    vec2 uv = UV;
    vec2 px = uv * dimensiones;
    float t = TIME * velocidad;
    float mascara = 1.0 - smoothstep(
        -0.75, 0.90, redondeado(px, dimensiones, 0.85)
    );

    // Se calculan por separado el valor real y la estela de daño.
    float sangre_actual = 1.0 - smoothstep(
        vida - 0.002, vida + 0.002, uv.x
    );
    float sangre_tardia = 1.0 - smoothstep(
        retraso - 0.002, retraso + 0.002, uv.x
    );
    float zona_dano = clamp(sangre_tardia - sangre_actual, 0.0, 1.0);

    // Dos escalas de corriente, una lenta y otra nerviosa.
    vec2 corriente = vec2(uv.x * 31.0 - t * 1.08,
                         uv.y * 3.8 + sin(uv.x * 23.0 + t) * 0.24);
    float remolino = fbm(corriente);
    float corriente_fina = fbm(vec2(
        uv.x * 83.0 + t * 1.65,
        uv.y * 10.0 - t * 0.35
    ));
    float latido = 0.5 + 0.5 * sin(t * 2.9);

    // Rojo oscuro de fondo con vasos internos que circulan.
    vec3 sangre = vec3(0.33, 0.007, 0.014);
    sangre += vec3(0.24, 0.025, 0.014) * remolino;
    sangre += vec3(0.19, 0.013, 0.012) * corriente_fina;
    sangre += vec3(0.080, 0.006, 0.010) * latido;

    // Dos filamentos fluidos se cruzan y se desplazan de forma continua.
    float hilo_a = veta(uv, t * 1.8, 27.0, 0.13);
    float hilo_b = veta(uv + vec2(0.0, 0.32), -t * 1.3, 39.0, 0.14);
    sangre += vec3(0.13, 0.014, 0.010) * hilo_a * intensidad;
    sangre += vec3(0.092, 0.006, 0.013) * hilo_b * intensidad;

    // Sombras serpenteantes: profundidad, no una textura roja plana.
    float sombra = veta(
        uv + vec2(0.0, 0.12 * sin(t * 0.7)),
        t * 0.9, 19.0, 0.075
    );
    sangre *= 1.0 - 0.14 * sombra * intensidad;

    // Reflejos líquidos longitudinales con un recorrido propio.
    float brillo_superior = exp(-pow((uv.y - 0.19) * 9.5, 2.0));
    brillo_superior *= 0.68 + 0.32 * sin(t * 1.9 + uv.x * 18.0);
    sangre += vec3(0.18, 0.023, 0.017) * brillo_superior * intensidad;

    // Destellos que atraviesan la barra a distintas velocidades.
    float barrido_a = fract(t * 0.085);
    float barrido_b = fract(t * 0.052 + 0.55);
    float linea_a = exp(-pow((uv.x - barrido_a) * 65.0, 2.0));
    float linea_b = exp(-pow((uv.x - barrido_b) * 90.0, 2.0));
    float diagonal = (0.5 + 0.5 * sin(uv.y * 7.0 + uv.x * 41.0 - t * 3.0));
    sangre += vec3(0.28, 0.058, 0.028) * linea_a * intensidad;
    sangre += vec3(0.16, 0.027, 0.021) * linea_b * diagonal * intensidad;

    // Una cresta viva en la superficie del líquido.
    float cresta = sin(uv.x * 70.0 - t * 4.3 + remolino * 4.0);
    cresta = smoothstep(0.55, 0.95, cresta);
    sangre += vec3(0.046, 0.009, 0.010) * cresta * intensidad;

    // Daño retardado: cobre oscuro que se consume gradualmente.
    vec3 vacio = vec3(0.027, 0.013, 0.017);
    vec3 cobre = vec3(0.49, 0.19, 0.057) * (
        0.75 + 0.25 * corriente_fina
    );
    vec3 resultante = mix(vacio, cobre, zona_dano);
    resultante = mix(resultante, sangre, sangre_actual);

    // Reacciones a eventos: daño, curación y vida crítica.
    resultante += vec3(0.28, 0.06, 0.032) * golpe * sangre_actual;
    resultante += vec3(0.08, 0.19, 0.060) * curacion * sangre_actual;
    resultante += vec3(0.19, 0.012, 0.013) * pulso_bajo * sangre_actual;

    // Volumen interno y brillo final, conservando bordes nítidos.
    float volumen = 0.85 + 0.15 * (1.0 - uv.y);
    resultante *= volumen;
    COLOR = vec4(clamp(resultante, vec3(0.0), vec3(1.0)), mascara);
}
"""

# Ya no hay tamaños fijos descoordinados: la barra, la sangre y el
# medallón se calculan juntos en _crear_interfaz().

var vida: int = 0
var _mostrada: float = 0.0
var _retrasada: float = 0.0
var _demora_dano: float = 0.0

var _contenedor: Control
var _aro: HaloArcano
var _liquido: ColorRect
var _chispas: ChispasSangre
var _material_liquido: ShaderMaterial
var _barra: ImagenHUD
var _medallon: ImagenHUD
var _espada: ImagenHUD
var _tween_espada: Tween
var _tween_entrada: Tween

var _tiene_espada: bool = false
var _forzar_espada: bool = false
var _maniqui: Node = null
var _tiempo_revision: float = 0.0
var _impacto: float = 0.0
var _curacion: float = 0.0
var _brillo_espada: float = 0.0
var _sacudida: float = 0.0
var _tiempo: float = 0.0
var _energia_baja: float = 0.0


func _ready() -> void:
	add_to_group(&"barra_vida")
	layer = 9
	vida_maxima = maxi(1, vida_maxima)
	vida = vida_maxima
	_mostrada = float(vida)
	_retrasada = float(vida)
	_tiene_espada = empieza_con_espada

	_crear_interfaz()
	if not Inventario.objeto_agregado.is_connected(_al_agregar_objeto):
		Inventario.objeto_agregado.connect(_al_agregar_objeto)
	if not Inventario.objeto_quitado.is_connected(_al_quitar_objeto):
		Inventario.objeto_quitado.connect(_al_quitar_objeto)
	_sincronizar_espada(true)
	_actualizar_liquido()
	_entrada_suave()


func _crear_interfaz() -> void:
	# Un único sistema de medidas mantiene alineados el marco y el líquido.
	var diametro: float = maxf(95.0, diametro_medallon)
	var largo: float = maxf(300.0, largo_barra)
	var grosor: float = maxf(18.0, grosor_barra)

	var medallon_tam := Vector2(diametro, diametro)
	var barra_pos := Vector2(diametro * 0.70, (diametro - grosor) * 0.5)
	var barra_tam := Vector2(largo, grosor)

	# Encaje fino del relleno respecto al marco en la captura v12:
	# había un hueco debajo y los últimos píxeles invadían el remate.
	# Aumentamos la altura, desplazamos suavemente hacia abajo y dejamos
	# más espacio a la punta decorativa. Los valores se ajustan en Inspector.
	var margen_izq_liquido: float = maxf(10.0, grosor * 0.52)
	var margen_der_liquido: float = margen_derecho_relleno
	var alto_liquido: float = clampf(grosor * proporcion_alto_relleno, 9.0, 22.0)
	var liquido_pos := barra_pos + Vector2(
		margen_izq_liquido,
		(grosor - alto_liquido) * 0.5 + desplazamiento_y_relleno
	)
	var liquido_tam := Vector2(
		maxf(24.0, largo - margen_izq_liquido - margen_der_liquido),
		alto_liquido
	)
	var panel_tam := Vector2(barra_pos.x + largo + 16.0, diametro + 16.0)

	_contenedor = Control.new()
	_contenedor.name = "HUD_Gotico_Final_130"
	_contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenedor.position = Vector2(margen_izquierdo, margen_superior)
	_contenedor.custom_minimum_size = panel_tam
	_contenedor.size = panel_tam
	_contenedor.scale = Vector2.ONE * ESCALA_HUD
	add_child(_contenedor)

	_aro = HaloArcano.new()
	_aro.name = "Sellos_Arcanos_Desplazados"
	_aro.position = Vector2.ZERO
	_aro.size = panel_tam
	_aro.centro = medallon_tam * 0.5
	_aro.radio_base = diametro * 0.44
	_aro.intensidad = intensidad_runas
	_aro.intensidad_centro = intensidad_runas_centro
	_aro.velocidad = velocidad_runas
	_aro.separacion = separacion_sellos
	_aro.ajuste_horizontal = ajuste_horizontal_sellos
	_aro.borde_inferior_barra = barra_pos.y + grosor
	_aro.visible = mostrar_halo_arcano
	_aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Los sellos se pintan primero: medallón y marco los TAPA de forma natural.
	_contenedor.add_child(_aro)

	var shader := Shader.new()
	shader.code = SHADER_SANGRE
	_material_liquido = ShaderMaterial.new()
	_material_liquido.shader = shader
	_material_liquido.set_shader_parameter("dimensiones", liquido_tam)

	# Primero la sangre, después el marco; el PNG sigue siendo decorativo.
	_liquido = ColorRect.new()
	_liquido.name = "Vida_Dinamica_Por_Codigo"
	_liquido.color = Color.WHITE
	_liquido.position = liquido_pos
	_liquido.size = liquido_tam
	_liquido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_liquido.material = _material_liquido
	_contenedor.add_child(_liquido)

	# Los puntos luminosos se dibujan después del shader y bajo el marco PNG.
	_chispas = ChispasSangre.new()
	_chispas.name = "Motas_de_sangre_viva"
	_chispas.position = liquido_pos
	_chispas.size = liquido_tam
	_chispas.velocidad = velocidad_sangre
	_chispas.intensidad = intensidad_sangre
	_chispas.visible = activar_efectos and mostrar_chispas_sangre
	_chispas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenedor.add_child(_chispas)

	# El marco solo se estira a lo largo del eje horizontal previsto.
	_barra = _crear_textura(
		"Marco_Gotico_Barra", TEX_BARRA, barra_pos, barra_tam
	)
	# El medallón y el ícono respetan el aspecto original de sus PNG.
	_medallon = _crear_textura(
		"Medallon_Gotico", TEX_MEDALLON, Vector2.ZERO, medallon_tam, true
	)
	# Nada de poner aquí los sellos encima del marco: se mantienen DETRÁS.

	var espada_tam := Vector2(diametro * 0.37, diametro * 0.63)
	var espada_pos := (medallon_tam - espada_tam) * 0.5
	_espada = _crear_textura(
		"Icono_Espada_Separado", TEX_ESPADA, espada_pos, espada_tam, true
	)
	_espada.pivot_offset = espada_tam * 0.5
	_espada.modulate.a = 0.0
	_espada.scale = Vector2.ONE


func _crear_textura(
	nombre: String, textura: Texture2D, ubicacion: Vector2,
	tamano: Vector2, conservar_aspecto: bool = false
) -> ImagenHUD:
	var nodo := ImagenHUD.new()
	nodo.name = nombre
	nodo.textura = textura
	nodo.conservar_aspecto = conservar_aspecto
	nodo.custom_minimum_size = Vector2.ZERO
	nodo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenedor.add_child(nodo)
	nodo.position = ubicacion
	nodo.size = tamano
	nodo.queue_redraw()
	return nodo


func _entrada_suave() -> void:
	_contenedor.position.x = margen_izquierdo - 27.0
	_contenedor.modulate.a = 0.0
	_tween_entrada = create_tween().set_parallel(true)
	_tween_entrada.tween_property(_contenedor, "position:x", margen_izquierdo, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_entrada.tween_property(_contenedor, "modulate:a", 1.0, 0.52).set_trans(Tween.TRANS_CUBIC)


func _process(delta: float) -> void:
	_tiempo += delta
	_actualizar_vida(delta)
	_actualizar_efectos(delta)
	_actualizar_liquido()

	if not _forzar_espada:
		_tiempo_revision -= delta
		if _tiempo_revision <= 0.0:
			_tiempo_revision = 0.45
			_sincronizar_espada()


func _actualizar_vida(delta: float) -> void:
	var objetivo := float(vida)
	if not is_equal_approx(_mostrada, objetivo):
		_mostrada = lerpf(_mostrada, objetivo, clampf(delta * suavizado, 0.0, 1.0))
		if absf(_mostrada - objetivo) < 0.35:
			_mostrada = objetivo

	if _retrasada < _mostrada:
		_retrasada = _mostrada
	elif _retrasada > _mostrada:
		_demora_dano = maxf(0.0, _demora_dano - delta)
		if _demora_dano <= 0.0:
			_retrasada = lerpf(_retrasada, _mostrada, clampf(delta * retardo_dano, 0.0, 1.0))
			if absf(_retrasada - _mostrada) < 0.35:
				_retrasada = _mostrada

	var fraccion := _mostrada / float(vida_maxima)
	var objetivo_pulso := 1.0 if fraccion < 0.23 else 0.0
	_energia_baja = lerpf(_energia_baja, objetivo_pulso, clampf(delta * 2.0, 0.0, 1.0))


func _actualizar_efectos(delta: float) -> void:
	_impacto = move_toward(_impacto, 0.0, delta * 2.8)
	_curacion = move_toward(_curacion, 0.0, delta * 1.8)
	_brillo_espada = move_toward(_brillo_espada, 0.0, delta * 1.3)
	_sacudida = move_toward(_sacudida, 0.0, delta * 3.1)

	var alza := 0.0
	if activar_efectos:
		alza = sin(_tiempo * 70.0) * _sacudida * 1.5
	_contenedor.position.y = margen_superior + alza

	if _aro != null:
		_aro.brillo = _brillo_espada
		_aro.alerta = _energia_baja
		_aro.intensidad = intensidad_runas
		_aro.intensidad_centro = intensidad_runas_centro
		_aro.impacto = _impacto if activar_efectos else 0.0
		_aro.sanacion = _curacion if activar_efectos else 0.0
		_aro.separacion = separacion_sellos
		_aro.ajuste_horizontal = ajuste_horizontal_sellos
		_aro.velocidad = velocidad_runas if activar_efectos else 0.0
		_aro.visible = mostrar_halo_arcano

	if _espada != null:
		# El símbolo se mueve un poco; el marco y la barra no giran.
		_espada.rotation = sin(_tiempo * 1.8) * 0.022
		if _tween_espada == null or not _tween_espada.is_running():
			_espada.scale = Vector2.ONE * (1.0 + sin(_tiempo * 2.0) * 0.009)


func _actualizar_liquido() -> void:
	if _material_liquido == null:
		return
	_material_liquido.set_shader_parameter("vida", clampf(_mostrada / float(vida_maxima), 0.0, 1.0))
	_material_liquido.set_shader_parameter("retraso", clampf(_retrasada / float(vida_maxima), 0.0, 1.0))
	_material_liquido.set_shader_parameter("golpe", _impacto if activar_efectos else 0.0)
	_material_liquido.set_shader_parameter("curacion", _curacion if activar_efectos else 0.0)
	_material_liquido.set_shader_parameter("pulso_bajo", _energia_baja * (0.5 + 0.5 * sin(_tiempo * 5.7)))
	_material_liquido.set_shader_parameter("intensidad", intensidad_sangre if activar_efectos else 0.0)
	_material_liquido.set_shader_parameter("velocidad", velocidad_sangre if activar_efectos else 0.0)
	if _chispas != null:
		_chispas.fraccion = clampf(_mostrada / float(vida_maxima), 0.0, 1.0)
		_chispas.velocidad = velocidad_sangre
		_chispas.intensidad = intensidad_sangre
		_chispas.golpe = _impacto
		_chispas.curacion = _curacion
		_chispas.visible = activar_efectos and mostrar_chispas_sangre


# ------------------------------------------------------------------------- VIDA
func recibir_dano(cantidad: int) -> void:
	if vida <= 0 or cantidad <= 0:
		return
	vida = maxi(vida - cantidad, 0)
	_demora_dano = espera_dano
	if activar_efectos:
		_impacto = 1.0
		_sacudida = 1.0
	vida_cambiada.emit(vida, vida_maxima)
	if vida == 0:
		murio.emit()


func curar(cantidad: int) -> void:
	if vida <= 0 or cantidad <= 0:
		return
	vida = mini(vida + cantidad, vida_maxima)
	if activar_efectos:
		_curacion = 1.0
	vida_cambiada.emit(vida, vida_maxima)


func restaurar() -> void:
	vida = vida_maxima
	_mostrada = float(vida)
	_retrasada = float(vida)
	_demora_dano = 0.0
	_curacion = 1.0
	_actualizar_liquido()
	vida_cambiada.emit(vida, vida_maxima)


# -------------------------------------------------------------------- INVENTARIO
func set_tiene_espada(activa: bool) -> void:
	_forzar_espada = true
	_aplicar_espada(activa)


func equipar_espada() -> void:
	set_tiene_espada(true)


func desequipar_espada() -> void:
	set_tiene_espada(false)


func seguir_inventario() -> void:
	_forzar_espada = false
	_sincronizar_espada()


func _al_agregar_objeto(id: StringName) -> void:
	if id == id_espada and not _forzar_espada:
		_aplicar_espada(true)


func _al_quitar_objeto(id: StringName) -> void:
	if id == id_espada and not _forzar_espada:
		_sincronizar_espada()


func _sincronizar_espada(instantaneo: bool = false) -> void:
	if _forzar_espada:
		return
	var en_inventario: bool = Inventario.tiene(id_espada)

	if not is_instance_valid(_maniqui):
		_maniqui = null
		var escena := get_tree().current_scene
		if is_instance_valid(escena):
			_maniqui = escena.find_child("UAL1_Standard", true, false)

	var en_mano: bool = false
	if is_instance_valid(_maniqui):
		var estado: Variant = _maniqui.get("con_espada")
		if estado is bool:
			en_mano = estado

	_aplicar_espada(en_inventario or en_mano, instantaneo)


func _aplicar_espada(activa: bool, instantaneo: bool = false) -> void:
	if _tiene_espada == activa and not instantaneo:
		return
	_tiene_espada = activa
	if not is_instance_valid(_espada):
		return

	if _tween_espada != null:
		_tween_espada.kill()

	if instantaneo:
		_espada.modulate.a = 1.0 if activa else 0.0
		_espada.scale = Vector2.ONE
		return

	_tween_espada = create_tween().set_parallel(true)
	_tween_espada.tween_property(_espada, "modulate:a", 1.0 if activa else 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_espada.scale = Vector2.ONE * (0.65 if activa else 1.0)
	_tween_espada.tween_property(_espada, "scale", Vector2.ONE if activa else Vector2.ONE * 0.83, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if activa:
		_brillo_espada = 1.0


# ---------------------------------------------------- SELLOS ARCANOS EXCÉNTRICOS
class HaloArcano extends Control:
	## UN sello hecho de DOS semicírculos ABIERTOS.
	## Las runas, marcas y chispas respetan el tramo abierto (sin anillos de 360°).
	## Detrás del medallón y de la barra, sin modificar la sangre.
	## El líquido rojo NO depende de esta clase.
	var _tiempo: float = 0.0
	var _tiempo_centro: float = 0.0
	var brillo: float = 0.0
	var alerta: float = 0.0
	var impacto: float = 0.0
	var sanacion: float = 0.0
	var intensidad: float = 1.45
	var intensidad_centro: float = 1.30
	var velocidad: float = 0.35
	var separacion: float = 1.0
	var ajuste_horizontal: float = 0.0
	var centro: Vector2 = Vector2(62.0, 62.0)
	var radio_base: float = 54.0
	var borde_inferior_barra: float = 74.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		_tiempo += delta * velocidad
		# Los símbolos centrales laten independientemente de los arcos lentos.
		if velocidad > 0.0:
			_tiempo_centro += delta
		queue_redraw()

	func _draw() -> void:
		if intensidad <= 0.001:
			return

		# Mantiene la posición horizontal aprobada. Subimos un poco el arco:
		# su extremo derecho llega justo bajo el marco, sin dejar un hueco.
		# El extremo izquierdo se oculta naturalmente bajo el medallón.
		var sello := centro + Vector2(
			radio_base * 0.84 * separacion + ajuste_horizontal,
			radio_base * 0.43
		)
		_dibujar_semicirculos(sello, radio_base * 0.94)
		_dibujar_chispas_semicirculo(sello, radio_base * 0.94)
		if intensidad_centro > 0.001:
			_dibujar_runa_morfica(sello, radio_base * 0.94)

	func _oro(opacidad: float, rojizo: bool = false) -> Color:
		var respiracion: float = 0.94 + 0.06 * sin(_tiempo * 1.6)
		var extra: float = 0.16 * brillo + 0.08 * alerta
		var alfa: float = clampf((opacidad * respiracion + extra) * intensidad, 0.0, 0.92)
		if rojizo:
			return Color(1.0, 0.43, 0.24, alfa)
		return Color(1.0, 0.78, 0.42, alfa)

	func _punto_eliptico(c: Vector2, rx: float, ry: float,
			angulo: float, imperfeccion: float = 0.0) -> Vector2:
		# Enderezamos el círculo. El eje Y se acerca al eje X, dejando una
		# deformación artesanal leve sin crear óvalos muy achatados.
		var ry_alineado: float = lerpf(ry, rx, 0.86)
		var temblor: float = (
			0.51 * sin(angulo * 3.0 + 0.63)
			+ 0.31 * sin(angulo * 7.0 - 1.12)
			+ 0.18 * sin(angulo * 11.0 + 2.25)
		)
		var escala: float = 1.0 + temblor * imperfeccion
		return c + Vector2(cos(angulo) * rx * escala,
			sin(angulo) * ry_alineado * escala)

	func _arco(c: Vector2, rx: float, ry: float,
			desde: float, hasta: float, opacidad: float,
			grosor: float = 1.0, imperfeccion: float = 0.015,
			bruma: bool = false) -> void:
		# Cada tramo es una curva poligonal fina y sin círculo completo.
		var pasos: int = maxi(4, int(ceil(absf(hasta - desde) * maxf(rx, ry) / 3.1)))
		var pts := PackedVector2Array()
		for paso in range(pasos + 1):
			var a: float = lerpf(desde, hasta, float(paso) / float(pasos))
			pts.append(_punto_eliptico(c, rx, ry, a, imperfeccion))
		if bruma:
			draw_polyline(pts, _oro(opacidad * 0.14), grosor + 4.0, true)
		draw_polyline(pts, _oro(opacidad), grosor, true)

	func _linea(a: Vector2, b: Vector2, opacidad: float,
			grosor: float = 0.9) -> void:
		draw_line(a, b, _oro(opacidad), grosor, true)

	func _glifo(c: Vector2, rx: float, ry: float,
			angulo: float, tamano: float, opacidad: float, tipo: int) -> void:
		var p := _punto_eliptico(c, rx, ry, angulo, 0.016)
		var radial := Vector2.from_angle(angulo)
		var tangente := radial.orthogonal()
		var r := radial * tamano
		var t := tangente * tamano
		# Cinco alfabetos geométricos, no caracteres de una fuente externa.
		match tipo % 6:
			0: # Runa bifurcada
				_linea(p - r, p + r, opacidad)
				_linea(p, p + r * 0.60 + t * 0.55, opacidad)
			1: # Runa angular
				_linea(p - t * 0.60, p + r * 0.95, opacidad)
				_linea(p + r * 0.95, p + t * 0.60, opacidad)
				_linea(p + t * 0.60, p - r * 0.65, opacidad * 0.72)
			2: # Runa partida
				_linea(p - r, p - r * 0.08, opacidad)
				_linea(p + r * 0.28, p + r, opacidad)
				_linea(p - t * 0.70, p + t * 0.70, opacidad)
			3: # Runa con cruz irregular
				_linea(p - r * 0.90, p + r * 0.90, opacidad)
				_linea(p - t * 0.65 - r * 0.24, p + t * 0.65 + r * 0.22, opacidad)
			4: # Sello tipo espina
				_linea(p - r, p + r, opacidad)
				_linea(p - r * 0.45, p + t * 0.55, opacidad)
				_linea(p + r * 0.25, p - t * 0.63, opacidad)
			5: # Chevron doble
				_linea(p - t * 0.55 - r * 0.6, p + r * 0.75, opacidad)
				_linea(p + r * 0.75, p + t * 0.55 - r * 0.6, opacidad)

	func _marca_radial(c: Vector2, angulo: float, rx: float,
			ry: float, opacidad: float, largo: float = 3.0) -> void:
		var p := _punto_eliptico(c, rx, ry, angulo, 0.02)
		var eje := Vector2.from_angle(angulo)
		_linea(p - eje * largo * 0.3, p + eje * largo * 0.7, opacidad, 0.8)

	func _diamante(c: Vector2, angulo: float, rx: float,
			ry: float, tamano: float, opacidad: float) -> void:
		var p := _punto_eliptico(c, rx, ry, angulo, 0.025)
		var eje := Vector2.from_angle(angulo)
		var tan := eje.orthogonal()
		var a := p + eje * tamano
		var b := p + tan * tamano * 0.57
		var d := p - eje * tamano
		var e := p - tan * tamano * 0.57
		_linea(a, b, opacidad)
		_linea(b, d, opacidad)
		_linea(d, e, opacidad)
		_linea(e, a, opacidad)

	# Solo se utilizan estos ~165° de arco, jamás los 360°.
	# El comienzo está a la derecha, pasa por abajo y termina abajo a la izquierda.
	const INICIO_SEMICIRCULO: float = -0.24
	const FIN_SEMICIRCULO: float = 2.64

	func _dibujar_semicirculos(c: Vector2, r: float) -> void:
		# Los dos arcos conservan SIEMPRE la abertura superior: nada gira
		# como un anillo completo y no reaparece un círculo de 360 grados.
		var pulso: float = 0.5 + 0.5 * sin(_tiempo * 1.15)
		var invertido: float = 0.5 + 0.5 * sin(_tiempo * 0.93 + 2.0)

		# Arco exterior principal, con un pequeño halo dorado.
		_arco(
			c, r, r * 0.96,
			INICIO_SEMICIRCULO, FIN_SEMICIRCULO,
			0.48 + pulso * 0.12, 1.40, 0.010, true
		)
		# Segundo semicírculo interior claramente separado.
		_arco(
			c, r * 0.70, r * 0.67,
			INICIO_SEMICIRCULO + 0.19, FIN_SEMICIRCULO - 0.19,
			0.28 + invertido * 0.11, 0.95, 0.008
		)

		# Grabados de orfebrería: tres bandas parciales que NO completan
		# un tercer anillo. Cada banda ocupa solo unos pocos grados.
		for banda in range(3):
			var f: float = float(banda)
			var comienzo: float = lerpf(
				INICIO_SEMICIRCULO + 0.30,
				FIN_SEMICIRCULO - 0.50, (f + 0.18) / 3.0
			)
			_arco(
				c, r * 0.91, r * 0.87, comienzo, comienzo + 0.30,
				0.16 + 0.07 * pulso, 0.75, 0.006
			)

		# Muescas perpendiculares finas en el borde externo, más pequeñas
		# que las runas para crear detalle sin desorden visual.
		for i in range(23):
			var t: float = (float(i) + 0.5) / 23.0
			var angulo: float = lerpf(
				INICIO_SEMICIRCULO + 0.08,
				FIN_SEMICIRCULO - 0.09, t
			)
			var radio_in: float = r * (0.955 if i % 4 != 0 else 0.925)
			var radio_out: float = r * (1.020 if i % 4 != 0 else 1.055)
			var a: Vector2 = _punto_eliptico(c, radio_in, radio_in * 0.96, angulo)
			var b: Vector2 = _punto_eliptico(c, radio_out, radio_out * 0.96, angulo)
			_linea(a, b, 0.20 + 0.06 * pulso, 0.68)

		# Runas distribuidas solo en la media corona; cada una pulsa
		# independientemente y alguna emite un destello breve.
		for i in range(10):
			var f: float = float(i)
			var t: float = f / 9.0
			var angulo: float = lerpf(
				INICIO_SEMICIRCULO + 0.23,
				FIN_SEMICIRCULO - 0.25, t
			)
			angulo += sin(_tiempo * 0.65 + f * 0.75) * 0.009
			var ola: float = 0.5 + 0.5 * sin(_tiempo * 1.75 - f * 0.79)
			var fuerza: float = 0.27 + ola * 0.27
			_glifo(c, r * 0.835, r * 0.79, angulo, 2.15 + ola * 0.34, fuerza, i)
			if i % 3 == 0:
				_marca_radial(c, angulo + 0.04, r * 0.77, r * 0.73,
					0.22 + ola * 0.18, 2.3)

		# Tres remaches unen visualmente ambas curvas sin cerrarlas.
		for i in range(3):
			var t: float = (float(i) + 1.0) / 4.0
			var a: float = lerpf(
				INICIO_SEMICIRCULO + 0.1,
				FIN_SEMICIRCULO - 0.10, t
			)
			var p: Vector2 = _punto_eliptico(c, r * 0.795, r * 0.763, a)
			draw_circle(p, 1.10, _oro(0.22 + 0.12 * pulso))
			draw_circle(p, 0.44, _oro(0.48 + 0.15 * pulso))

		# Rastro de energía desplazándose por el arco externo. La línea
		# principal permanece quieta y el brillo recorre un tramo de 0.18 rad.
		var viaje: float = fposmod(_tiempo * 0.14, 1.0)
		var desde: float = lerpf(
			INICIO_SEMICIRCULO + 0.10,
			FIN_SEMICIRCULO - 0.33, viaje
		)
		_arco(c, r, r * 0.96, desde, desde + 0.20,
			0.35 + 0.16 * pulso, 2.05, 0.006, true)

		# Eco más tenue que avanza por el arco interior en sentido opuesto.
		var regreso: float = 1.0 - fposmod(_tiempo * 0.105 + 0.40, 1.0)
		var inicio_eco: float = lerpf(
			INICIO_SEMICIRCULO + 0.30,
			FIN_SEMICIRCULO - 0.49, regreso
		)
		_arco(c, r * 0.70, r * 0.67, inicio_eco, inicio_eco + 0.15,
			0.23 + invertido * 0.17, 1.3, 0.005)

		# Remates fijos en ambos extremos abiertos; parecen metal encantado.
		_diamante(c, INICIO_SEMICIRCULO, r, r * 0.96, 2.4, 0.43)
		_diamante(c, FIN_SEMICIRCULO, r, r * 0.96, 2.4, 0.37)
		_dibujar_union_barra(c, r, pulso)

	func _dibujar_union_barra(c: Vector2, r: float, pulso: float) -> void:
		# El extremo derecho del arco cae justo bajo el borde inferior del
		# marco PNG. Estas dos pequeñas abrazaderas doradas dan continuidad.
		# Se pintan ANTES del PNG, evitando invadir la barra o la sangre.
		var extremo: Vector2 = _punto_eliptico(
			c, r, r * 0.96, INICIO_SEMICIRCULO, 0.010
		)
		var fijacion := Vector2(extremo.x - 1.3, borde_inferior_barra - 2.3)
		_linea(extremo, fijacion, 0.56 + 0.13 * pulso, 1.25)
		_linea(extremo + Vector2(-2.8, 1.2),
			fijacion + Vector2(-2.8, -0.2), 0.28 + 0.09 * pulso, 0.7)
		_linea(fijacion + Vector2(-5.2, 0.0),
			fijacion + Vector2(6.3, 0.0), 0.26 + 0.08 * pulso, 0.85)
		draw_circle(extremo, 1.75, _oro(0.22 + 0.12 * pulso))
		draw_circle(extremo, 0.65, _oro(0.54 + 0.16 * pulso))

	func _dibujar_chispas_semicirculo(c: Vector2, r: float) -> void:
		# Siete motas pasan por el arco ABIERTO, reaparecen al inicio y
		# nunca dibujan puntos en el espacio superior vacío.
		for i in range(7):
			var indice: float = float(i)
			var avance: float = fposmod(
				_tiempo * (0.15 + indice * 0.009) + indice / 7.0, 1.0
			)
			var angulo: float = lerpf(
				INICIO_SEMICIRCULO + 0.06,
				FIN_SEMICIRCULO - 0.06, avance
			)
			var camino: float = r * (0.975 if i % 3 != 0 else 0.715)
			var p: Vector2 = _punto_eliptico(
				c, camino, camino * 0.96, angulo, 0.005
			)
			var destello: float = 0.5 + 0.5 * sin(
				_tiempo * 2.4 + indice * 1.8
			)
			# Aura, núcleo y estela discreta.
			draw_circle(p, 2.5, _oro(0.055 + destello * 0.055))
			draw_circle(p, 0.88, _oro(0.26 + destello * 0.31))
			if i % 2 == 0:
				var atras: float = maxf(INICIO_SEMICIRCULO + 0.05,
					angulo - 0.040)
				var cola: Vector2 = _punto_eliptico(
					c, camino, camino * 0.96, atras, 0.005
				)
				_linea(cola, p, 0.12 + destello * 0.16, 0.80)


	# --------------------------------------------- RUNA CENTRAL (V24)
	# Una sola runa, centrada dentro del semicírculo, que cambia de forma.
	# No hay constelación de símbolos ni piedra central.
	func _trazo_runa(p: Vector2, a: Vector2, b: Vector2,
			tamano: float, giro: float, brillo_linea: float,
			grosor: float = 1.0) -> void:
		var inicio: Vector2 = p + (a * tamano).rotated(giro)
		var fin: Vector2 = p + (b * tamano).rotated(giro)
		# Halo suave bajo una línea dorada definida; conserva estética medieval.
		draw_line(inicio, fin, _oro(brillo_linea * 0.13), grosor + 2.0, true)
		draw_line(inicio, fin, _oro(brillo_linea), grosor, true)

	func _simbolo_runa(p: Vector2, tamano: float, giro: float,
			fuerza: float, tipo: int) -> void:
		# Alfabeto angular con cinco variantes; cada trazo es una línea.
		# No usamos draw_colored_polygon ni texturas en estas runas.
		var trazos: Array[Vector2] = []
		match tipo % 5:
			0: # Runa principal: asta, dos alas y puntas inferiores.
				trazos = [
					Vector2(0, -1), Vector2(0, 1),
					Vector2(-0.77, -0.61), Vector2(0, 0.05),
					Vector2(0.77, -0.61), Vector2(0, 0.05),
					Vector2(-0.50, 0.50), Vector2(0, 0.10),
					Vector2(0.50, 0.50), Vector2(0, 0.10),
					Vector2(-0.27, 0.77), Vector2(0.27, 0.77),
				]
			1: # Runa partida en zigzag.
				trazos = [
					Vector2(-0.54, -0.91), Vector2(0.47, -0.91),
					Vector2(0.47, -0.91), Vector2(-0.44, 0.01),
					Vector2(-0.44, 0.01), Vector2(0.57, 0.94),
					Vector2(-0.48, 0.77), Vector2(0.57, 0.77),
				]
			2: # Runa tipo espiga con un asta bifurcada.
				trazos = [
					Vector2(0, -1), Vector2(0, 1),
					Vector2(-0.65, -0.61), Vector2(0, -0.04),
					Vector2(0.65, -0.61), Vector2(0, -0.04),
					Vector2(-0.60, 0.43), Vector2(0, 0.81),
				]
			3: # Runa doble punta abierta.
				trazos = [
					Vector2(-0.53, -0.84), Vector2(0.50, 0.04),
					Vector2(0.50, 0.04), Vector2(-0.54, 0.92),
					Vector2(-0.53, -0.84), Vector2(-0.53, 0.92),
					Vector2(0.50, -0.64), Vector2(0.50, 0.57),
				]
			4: # Runa tridente, con sección horizontal cortada.
				trazos = [
					Vector2(0, -1), Vector2(0, 1),
					Vector2(-0.61, -0.74), Vector2(-0.61, 0.15),
					Vector2(-0.61, 0.15), Vector2(0, 0.51),
					Vector2(0.61, -0.74), Vector2(0.61, 0.15),
					Vector2(0.61, 0.15), Vector2(0, 0.51),
				]

		for j in range(0, trazos.size(), 2):
			_trazo_runa(
				p, trazos[j], trazos[j + 1],
				tamano, giro, fuerza, 1.2 if tipo == 0 else 0.90
			)

	func _suavizar_fase(x: float) -> float:
		# Curva suave 0->1 para la metamorfosis visual.
		return x * x * (3.0 - 2.0 * x)

	func _dibujar_runa_morfica(c: Vector2, r: float) -> void:
		var t: float = _tiempo_centro
		var reaccion: float = clampf(
			impacto * 0.75 + sanacion * 0.46 + alerta * 0.35,
			0.0, 1.0
		)
		var multiplicador: float = intensidad_centro * (1.0 + reaccion * 0.35)

		# Queda centrada en el hueco del semicírculo.
		var foco: Vector2 = c + Vector2(r * 0.04, r * 0.20)
		foco.y += sin(t * 1.18) * 0.75

		# La runa cambia de forma suavemente entre los 5 símbolos definidos.
		var ciclo: float = t * 0.22
		var fase_total: float = fposmod(ciclo, 5.0)
		var tipo_actual: int = int(floor(fase_total)) % 5
		var tipo_siguiente: int = (tipo_actual + 1) % 5
		var transicion: float = _suavizar_fase(fase_total - floor(fase_total))

		# Respira, pero no gira como un molino.
		var latido: float = 0.5 + 0.5 * sin(t * 2.05)
		var oscilacion: float = sin(t * 0.72) * 0.060
		var tam_base: float = r * (0.185 + 0.014 * latido)

		# Dos capas luminosas: la forma actual se desvanece mientras la siguiente aparece.
		_simbolo_runa(
			foco, tam_base, oscilacion,
			(0.22 + (1.0 - transicion) * 0.55 + latido * 0.18) * multiplicador,
			tipo_actual
		)
		_simbolo_runa(
			foco, tam_base * (0.985 + transicion * 0.03), oscilacion * 1.12,
			(0.18 + transicion * 0.52 + latido * 0.12) * multiplicador,
			tipo_siguiente
		)

		# Núcleo de energía discreto, solo luz, para que destaque el cambio.
		var halo: float = 0.5 + 0.5 * sin(t * 2.7)
		draw_circle(foco, 0.70 + halo * 0.18,
			_oro((0.10 + halo * 0.10) * multiplicador))
		draw_circle(foco, 0.28 + halo * 0.10,
			_oro((0.32 + halo * 0.18) * multiplicador))

		# Dos filamentos conectan la runa al arco interior, reforzando el encaje.
		for i in range(2):
			var angulo: float = 0.67 if i == 0 else 1.75
			var anclaje: Vector2 = _punto_eliptico(
				c, r * 0.69, r * 0.66, angulo, 0.006
			)
			var origen: Vector2 = foco + Vector2(
				r * (0.15 if i == 0 else -0.15), r * 0.08
			)
			var alternancia: float = 0.5 + 0.5 * sin(t * 1.62 + float(i) * PI)
			var punto_medio: Vector2 = origen.lerp(anclaje, 0.50)
			var opacidad: float = (0.08 + 0.22 * alternancia) * multiplicador
			_linea(origen, origen.lerp(punto_medio, 0.82), opacidad, 0.72)
			_linea(punto_medio.lerp(anclaje, 0.20), anclaje,
				opacidad * 0.58, 0.62)

		# Motas puntuales muy sutiles para que respire el centro sin recargar.
		for i in range(4):
			var f: float = float(i)
			var brillo_mota: float = pow(maxf(0.0, sin(t * 2.1 - f * 1.5)), 3.0)
			var p: Vector2 = foco + Vector2(
				sin(f * 2.24 + t * 0.20) * r * 0.16,
				cos(f * 1.73 + t * 0.24) * r * 0.08
			)
			draw_circle(p, 0.48,
				_oro((0.10 + brillo_mota * 0.30) * multiplicador))


# ----------------------------------------------------------------- CHISPAS ROJAS
class ChispasSangre extends Control:
	## Mota/filamento adicional encima del shader, pero debajo del PNG.
	## Todo se limita al relleno existente y a la fracción de vida visible.
	var _tiempo: float = 0.0
	var fraccion: float = 1.0
	var velocidad: float = 1.0
	var intensidad: float = 1.0
	var golpe: float = 0.0
	var curacion: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		_tiempo += delta * velocidad
		queue_redraw()

	func _draw() -> void:
		if fraccion < 0.01 or intensidad <= 0.0:
			return
		if size.x <= 0.0 or size.y <= 0.0:
			return

		# Mantiene las chispas contenidas cuando la barra está casi vacía.
		var limite: float = size.x * fraccion
		var margen_y: float = minf(2.0, size.y * 0.15)
		for i in range(30):
			var id := float(i)
			var movimiento := _tiempo * (0.065 + 0.006 * float(i % 4))
			var fase := fposmod(id * 0.618034 + movimiento, 1.0)
			var x := 2.0 + fase * maxf(0.0, size.x - 4.0)
			if x >= limite - 2.0:
				continue

			var oscilacion := 0.5 + 0.5 * sin(_tiempo * 2.1 + id * 1.72)
			var y := margen_y + (size.y - margen_y * 2.0) * (
				0.19 + 0.61 * oscilacion
			)
			var titilar := 0.5 + 0.5 * sin(_tiempo * 4.0 + id * 2.34)
			var fuerza := (0.12 + 0.28 * titilar) * intensidad
			fuerza += golpe * 0.17 + curacion * 0.10

			var posicion := Vector2(x, y)
			var radio := 0.55 + 0.30 * sin(id * 1.8) * sin(id * 1.8)
			draw_circle(posicion, radio + 1.25,
				Color(0.98, 0.22, 0.075, clampf(fuerza * 0.22, 0.0, 0.45)))
			draw_circle(posicion, radio,
				Color(1.0, 0.65, 0.31, clampf(fuerza, 0.0, 0.75)))

			# Algunas partículas dibujan una cola diminuta dentro de la sangre.
			if i % 3 == 0:
				var cola := minf(3.0, maxf(0.0, x - 1.0))
				draw_line(Vector2(x - cola, y), posicion,
					Color(0.95, 0.26, 0.10, clampf(fuerza * 0.45, 0.0, 0.6)),
					0.8, true)


# ---------------------------------------------------------------------- IMAGENES
class ImagenHUD extends Control:
	## Se limita el tamaño para evitar el escalado gigante de las versiones viejas.
	## El medallón y la espada conservan la proporción original de su PNG.
	var textura: Texture2D
	var conservar_aspecto: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		if textura == null or size.x <= 0.0 or size.y <= 0.0:
			return

		var destino := Rect2(Vector2.ZERO, size)
		if conservar_aspecto:
			var original := textura.get_size()
			if original.x > 0.0 and original.y > 0.0:
				var factor := minf(size.x / original.x, size.y / original.y)
				var final_tam := original * factor
				destino = Rect2((size - final_tam) * 0.5, final_tam)

		draw_texture_rect(textura, destino, false)
