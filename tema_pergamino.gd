extends RefCounted
## Tema visual "desierto / pergamino" para los menús y pantallas del juego.
## No es un Autoload ni una escena: es un archivo de ayuda que se usa así:
##
##   const Tema = preload("res://tema_pergamino.gd")
##   Tema.estilizar_menu(self)        # menús que ya existen (pausa, menú principal)
##   mi_control.theme = Tema.crear()  # para pantallas nuevas hechas por código
##
## Todo se dibuja por código (no hay imágenes ni fuentes que importar), así que
## para cambiar el aspecto del juego basta con tocar la paleta de aquí abajo.

# ---------------------------------------------------------------- Paleta
const PERGAMINO := Color(0.89, 0.79, 0.59)          # fondo de los paneles
const PERGAMINO_QUEMADO := Color(0.46, 0.30, 0.14)  # bordes envejecidos del papel
const TINTA := Color(0.20, 0.12, 0.06)              # texto oscuro (sobre pergamino)
const TINTA_SUAVE := Color(0.42, 0.30, 0.18)        # texto secundario
const ARENA := Color(0.95, 0.88, 0.70)              # texto claro (sobre cuero)
const CUERO := Color(0.24, 0.15, 0.09)              # botones
const CUERO_CLARO := Color(0.38, 0.25, 0.14)        # botón con el mouse encima
const CUERO_OSCURO := Color(0.14, 0.09, 0.05)       # botón apretado
const DORADO := Color(0.78, 0.58, 0.26)
const DORADO_CLARO := Color(0.97, 0.80, 0.46)
const NOCHE := Color(0.05, 0.03, 0.02)              # fondo oscuro detrás de los paneles

# Tamaño de la imagen del pergamino y del borde que no se estira (en píxeles).
const TAM_PERGAMINO := 96
const BORDE_PERGAMINO := 24

# Se crean una sola vez y se reutilizan en todos los menús.
static var _tema: Theme = null
static var _textura_pergamino: ImageTexture = null


# ---------------------------------------------------------------- Uso público

## Devuelve el tema completo. Asígnalo a un Control y todos sus hijos lo heredan.
static func crear() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = _crear_fuente()
	t.default_font_size = 22
	_estilo_etiquetas(t)
	_estilo_botones(t)
	_estilo_sliders(t)
	_estilo_paneles(t)
	_estilo_separadores(t)
	_estilo_scroll(t)
	_tema = t
	return t


## Aplica el estilo a un menú que ya existe, sin cambiar su lógica.
## Busca los nodos por nombre: "Fondo", "Principal/Botones" y "Opciones/Contenido".
## "raiz" puede ser el Control del menú principal o el CanvasLayer del menú de pausa.
## Con "con_degradado" el fondo pasa a ser un degradado cálido (para el menú principal).
static func estilizar_menu(raiz: Node, con_degradado: bool = false) -> void:
	var tema: Theme = crear()

	# Un Control reparte el tema a sus hijos; un CanvasLayer no tiene "theme",
	# así que se lo damos a cada Control que cuelga de él.
	if raiz is Control:
		(raiz as Control).theme = tema
	else:
		for hijo in raiz.get_children():
			if hijo is Control:
				(hijo as Control).theme = tema

	var fondo := raiz.get_node_or_null("Fondo") as ColorRect
	if fondo != null:
		if con_degradado and raiz is Control:
			fondo.color = NOCHE
			agregar_fondo_degradado(raiz as Control, fondo)
		else:
			fondo.color = Color(NOCHE.r, NOCHE.g, NOCHE.b, 0.72)

	for ruta: String in ["Principal/Botones", "Opciones/Contenido"]:
		var contenedor := raiz.get_node_or_null(ruta) as Control
		if contenedor != null:
			_agregar_divisor_bajo_titulo(contenedor)
			envolver_en_panel(contenedor)


## Mete un nodo dentro de un panel de pergamino, en el mismo lugar donde estaba.
static func envolver_en_panel(nodo: Control) -> PanelContainer:
	var padre: Node = nodo.get_parent()
	var indice: int = nodo.get_index()
	var panel := PanelContainer.new()
	panel.name = "Pergamino"
	padre.add_child(panel)
	padre.move_child(panel, indice)
	nodo.reparent(panel, false)
	return panel


## Agrega un degradado radial (centro cálido, bordes oscuros) justo encima de "despues_de".
static func agregar_fondo_degradado(padre: Control, despues_de: Node) -> void:
	var degradado := Gradient.new()
	degradado.colors = PackedColorArray([Color(0.30, 0.19, 0.10), NOCHE])
	degradado.offsets = PackedFloat32Array([0.0, 1.0])

	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 512
	textura.height = 512

	var rect := TextureRect.new()
	rect.texture = textura
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(rect)
	padre.move_child(rect, despues_de.get_index() + 1)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## El estilo de papel envejecido (se usa para todos los PanelContainer).
static func crear_estilo_pergamino() -> StyleBoxTexture:
	var estilo := StyleBoxTexture.new()
	estilo.texture = _obtener_textura_pergamino()
	estilo.texture_margin_left = BORDE_PERGAMINO
	estilo.texture_margin_right = BORDE_PERGAMINO
	estilo.texture_margin_top = BORDE_PERGAMINO
	estilo.texture_margin_bottom = BORDE_PERGAMINO
	estilo.content_margin_left = 44.0
	estilo.content_margin_right = 44.0
	estilo.content_margin_top = 34.0
	estilo.content_margin_bottom = 38.0
	return estilo


# ---------------------------------------------------------------- Piezas del tema

static func _crear_fuente() -> Font:
	# Una letra con serifa del sistema le da aire de libro antiguo. Se usa la primera
	# que exista; si ninguna está, Godot elige otra por su cuenta.
	var fuente := SystemFont.new()
	fuente.font_names = PackedStringArray([
		"Palatino Linotype", "Book Antiqua", "Georgia", "Cambria", "Times New Roman", "serif"
	])
	return fuente


static func _estilo_etiquetas(t: Theme) -> void:
	t.set_color("font_color", "Label", TINTA)


static func _estilo_botones(t: Theme) -> void:
	t.set_font_size("font_size", "Button", 24)
	t.set_color("font_color", "Button", ARENA)
	t.set_color("font_hover_color", "Button", DORADO_CLARO)
	t.set_color("font_pressed_color", "Button", ARENA.darkened(0.2))
	t.set_color("font_hover_pressed_color", "Button", DORADO_CLARO)
	t.set_color("font_focus_color", "Button", ARENA)
	t.set_color("font_disabled_color", "Button", TINTA_SUAVE)

	t.set_stylebox("normal", "Button", _caja(CUERO, DORADO.darkened(0.4)))
	t.set_stylebox("hover", "Button", _caja(CUERO_CLARO, DORADO_CLARO))
	t.set_stylebox("pressed", "Button", _caja(CUERO_OSCURO, DORADO))
	t.set_stylebox("hover_pressed", "Button", _caja(CUERO_OSCURO, DORADO_CLARO))
	t.set_stylebox("disabled", "Button", _caja(CUERO.darkened(0.3), TINTA_SUAVE))

	# Marco que se ve cuando el botón tiene el foco (por ejemplo al navegar con teclado).
	var foco := _caja(Color(0.0, 0.0, 0.0, 0.0), DORADO_CLARO)
	foco.draw_center = false
	t.set_stylebox("focus", "Button", foco)


static func _estilo_sliders(t: Theme) -> void:
	t.set_stylebox("slider", "HSlider", _barra(CUERO_CLARO.darkened(0.1)))
	t.set_stylebox("grabber_area", "HSlider", _barra(DORADO))
	t.set_stylebox("grabber_area_highlight", "HSlider", _barra(DORADO_CLARO))
	t.set_icon("grabber", "HSlider", _circulo(DORADO, CUERO))
	t.set_icon("grabber_highlight", "HSlider", _circulo(DORADO_CLARO, CUERO_CLARO))
	t.set_icon("grabber_disabled", "HSlider", _circulo(TINTA_SUAVE, CUERO))


static func _estilo_paneles(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", crear_estilo_pergamino())


static func _estilo_separadores(t: Theme) -> void:
	var linea := StyleBoxLine.new()
	linea.color = TINTA_SUAVE
	linea.thickness = 2
	t.set_stylebox("separator", "HSeparator", linea)
	t.set_constant("separation", "HSeparator", 12)


static func _estilo_scroll(t: Theme) -> void:
	var pista := StyleBoxFlat.new()
	pista.bg_color = Color(TINTA_SUAVE.r, TINTA_SUAVE.g, TINTA_SUAVE.b, 0.25)
	pista.set_corner_radius_all(3)
	pista.content_margin_left = 5.0
	pista.content_margin_right = 5.0
	t.set_stylebox("scroll", "VScrollBar", pista)
	t.set_stylebox("scroll_focus", "VScrollBar", pista)

	var asa := StyleBoxFlat.new()
	asa.bg_color = DORADO.darkened(0.2)
	asa.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", asa)
	t.set_stylebox("grabber_pressed", "VScrollBar", asa)

	var asa_resaltada := StyleBoxFlat.new()
	asa_resaltada.bg_color = DORADO
	asa_resaltada.set_corner_radius_all(3)
	t.set_stylebox("grabber_highlight", "VScrollBar", asa_resaltada)


# ---------------------------------------------------------------- Dibujo por código

# Caja de botón: relleno + borde fino con las esquinas apenas redondeadas.
static func _caja(relleno: Color, borde: Color) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = relleno
	caja.border_color = borde
	caja.set_border_width_all(2)
	caja.set_corner_radius_all(4)
	caja.content_margin_left = 20.0
	caja.content_margin_right = 20.0
	caja.content_margin_top = 10.0
	caja.content_margin_bottom = 10.0
	return caja


# Barra delgada para los sliders (el alto sale de los márgenes de arriba y abajo).
static func _barra(color: Color) -> StyleBoxFlat:
	var barra := StyleBoxFlat.new()
	barra.bg_color = color
	barra.set_corner_radius_all(3)
	barra.content_margin_top = 3.0
	barra.content_margin_bottom = 3.0
	return barra


# Perilla redonda del slider: anillo de un color y centro de otro.
static func _circulo(anillo: Color, centro: Color) -> ImageTexture:
	var tam: int = 22
	var imagen := Image.create_empty(tam, tam, false, Image.FORMAT_RGBA8)
	var medio: float = (tam - 1) * 0.5
	for y in range(tam):
		for x in range(tam):
			var distancia: float = Vector2(x - medio, y - medio).length()
			var color: Color = centro if distancia < 6.5 else anillo
			# Suaviza el borde exterior para que no se vea dentado.
			color.a = clampf(10.5 - distancia + 0.5, 0.0, 1.0)
			imagen.set_pixel(x, y, color)
	return ImageTexture.create_from_image(imagen)


# Imagen del papel: color arena con manchas suaves, borde "quemado" y una línea de tinta.
# Se usa como 9-slice: las esquinas y los bordes no se deforman al estirar el panel.
static func _obtener_textura_pergamino() -> ImageTexture:
	if _textura_pergamino != null:
		return _textura_pergamino

	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.04
	ruido.seed = 7

	var imagen := Image.create_empty(TAM_PERGAMINO, TAM_PERGAMINO, false, Image.FORMAT_RGBA8)
	for y in range(TAM_PERGAMINO):
		for x in range(TAM_PERGAMINO):
			# Distancia en píxeles hasta el borde más cercano.
			var al_borde: float = float(mini(mini(x, y), mini(TAM_PERGAMINO - 1 - x, TAM_PERGAMINO - 1 - y)))
			var quemado: float = 1.0 - smoothstep(0.0, float(BORDE_PERGAMINO), al_borde)
			var manchas: float = (ruido.get_noise_2d(float(x), float(y)) * 0.5 + 0.5) * 0.12
			var color: Color = PERGAMINO.darkened(manchas)
			color = color.lerp(PERGAMINO_QUEMADO, quemado * 0.85)
			if al_borde < 2.0:
				color = TINTA
			color.a = 1.0
			imagen.set_pixel(x, y, color)

	_textura_pergamino = ImageTexture.create_from_image(imagen)
	return _textura_pergamino


# Raya fina bajo el título de un menú (si el primer hijo del contenedor es un Label).
static func _agregar_divisor_bajo_titulo(contenedor: Control) -> void:
	if contenedor.get_child_count() > 0 and contenedor.get_child(0) is Label:
		var linea := HSeparator.new()
		contenedor.add_child(linea)
		contenedor.move_child(linea, 1)
