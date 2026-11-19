extends CanvasLayer
## Pantalla de muerte: fundido negro, humo inferior y mensaje.
## Añadir como hijo de la escena jugable (Node > CanvasLayer).
## Se conecta automáticamente a BarraVida.murio.

const HUMO_SHADER := """
shader_type canvas_item;
render_mode blend_mix;

// Niebla multicapa con deformación continua; sin texturas externas.
uniform float intensidad : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
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
    float total = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 6; i++) {
        total += noise2(p) * amp;
        p = mat2(vec2(1.63, 1.17), vec2(-1.17, 1.63)) * p;
        amp *= 0.5;
    }
    return total;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * 0.11;
    // Escala ajustada al aspecto: evita estirar el ruido en monitores anchos.
    vec2 p = vec2(uv.x * 4.2, uv.y * 2.3);
    vec2 warp = vec2(
        fbm(p * 0.75 + vec2(t * 0.31, -t * 0.21)),
        fbm(p * 0.75 + vec2(5.4 - t * 0.22, 2.1 - t * 0.29))
    );
    vec2 q = p + (warp - 0.5) * 1.3;
    float capa_grande = fbm(q * 1.15 + vec2(t * 0.20, -t * 0.35));
    float capa_fina = fbm(q * 2.5 + vec2(-t * 0.13, -t * 0.55));
    float densidad = capa_grande * 0.78 + capa_fina * 0.22;

    // La niebla se concentra abajo y se disuelve gradualmente hacia el centro.
    float altura = smoothstep(0.08, 0.95, uv.y);
    float nube = smoothstep(0.31, 0.73, densidad + altura * 0.26);
    float transparencia = nube * altura * 0.56;
    float luminosidad = 0.22 + densidad * 0.27;
    COLOR = vec4(vec3(luminosidad * 0.87, luminosidad * 0.89, luminosidad),
        transparencia * intensidad);
}
"""

var _fondo: ColorRect
var _humo: ColorRect
var _texto: Label
var _boton: Button
var _activo := false
var _conectado := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_fondo = ColorRect.new()
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.color = Color(0.0, 0.0, 0.0, 1.0)
	_fondo.modulate.a = 0.0
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)

	_humo = ColorRect.new()
	_humo.anchor_left = 0.0
	_humo.anchor_right = 1.0
	_humo.anchor_top = 0.55
	_humo.anchor_bottom = 1.0
	_humo.offset_left = 0.0
	_humo.offset_right = 0.0
	_humo.offset_top = 0.0
	_humo.offset_bottom = 0.0
	var material_humo := ShaderMaterial.new()
	var shader_humo := Shader.new()
	shader_humo.code = HUMO_SHADER
	material_humo.shader = shader_humo
	_humo.material = material_humo
	_humo.modulate.a = 0.0
	_humo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_humo)

	_texto = Label.new()
	_texto.text = "HAS MUERTO"
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_texto.anchor_left = 0.0
	_texto.anchor_right = 1.0
	_texto.offset_left = 0.0
	_texto.offset_right = 0.0
	_texto.offset_top = -22.0
	_texto.offset_bottom = 22.0
	_texto.add_theme_font_size_override("font_size", 36)
	_texto.add_theme_color_override("font_color", Color(0.88, 0.84, 0.79))
	_texto.modulate.a = 0.0
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texto)

	_boton = Button.new()
	_boton.text = "REINTENTAR"
	_boton.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_boton.offset_left = -100.0
	_boton.offset_right = 100.0
	_boton.offset_top = 65.0
	_boton.offset_bottom = 110.0
	_boton.modulate.a = 0.0
	_boton.visible = false
	_boton.pressed.connect(_reiniciar)
	add_child(_boton)

	# El HUD puede aparecer después que esta pantalla: buscamos hasta encontrarlo.
	set_process(true)

func _process(_delta: float) -> void:
	if _conectado:
		set_process(false)
		return
	var barra := get_tree().get_first_node_in_group("barra_vida")
	if barra != null and barra.has_signal("murio"):
		barra.connect("murio", Callable(self, "_morir"))
		_conectado = true
		set_process(false)

func _morir() -> void:
	if _activo:
		return
	_activo = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var animacion := create_tween()
	animacion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	animacion.tween_property(_fondo, "modulate:a", 1.0, 1.15)
	animacion.tween_property(_humo, "modulate:a", 1.0, 1.2)
	animacion.parallel().tween_property(_texto, "modulate:a", 1.0, 0.9)
	animacion.tween_callback(_mostrar_reintento)

func _mostrar_reintento() -> void:
	get_tree().paused = true
	_boton.visible = true
	var animacion := create_tween()
	animacion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	animacion.tween_property(_boton, "modulate:a", 1.0, 0.5)
	_boton.grab_focus()

func _reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
