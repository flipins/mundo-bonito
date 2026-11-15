@tool
extends Node3D
## Cadáver con la espada vieja clavada en la arena, al final del sendero.
## Lo crea props_recorrido.gd (función _cadaver_y_espada).
## Guardar como: res://scripts/world/cadaver_espada.gd
##
## CADÁVER: si existe el archivo ARCHIVO_CADAVER se usa ese modelo (se escala solo).
## Si no existe, se arma uno provisional con formas simples para que puedas probar todo.
## ESPADA: usa el mismo sistema que grieta_desierto.gd (recogible.gd + interactor.gd).

## Se emite al recoger la espada (para que el gestor del tutorial avance).
signal espada_recogida

const RUTA_RECOGIBLE := "res://scripts/objects/recogible.gd"

# --- Cadáver ---
const ARCHIVO_CADAVER := "res://assets/models/cadaver/cadaver.glb"
## Largo del cadáver (su dimensión más grande), en metros.
const LARGO_CADAVER := 1.8
## Rotación del modelo en grados (X, Y, Z) por si viene de pie o mirando hacia otro lado.
const ROTACION_MODELO := Vector3(0.0, 0.0, 0.0)
## Hacia dónde apunta el cuerpo sobre la arena, en grados.
const GIRO_CADAVER := 70.0
## Cuánto queda enterrado en la arena, en metros.
const HUNDIMIENTO_CADAVER := 0.08

# --- Espada ---
const ARCHIVO_ESPADA := "res://assets/models/espada/暗影古剑.glb"
const LARGO_ESPADA := 1.5
## Cuánto de la hoja queda clavada en la arena, en metros.
const HUNDIMIENTO_ESPADA := 0.45
const INCLINACION_ESPADA := 10.0
## true = acero negro como en el menú. false = texturas originales del modelo.
const ACERO_NEGRO := false
const ID_ESPADA := &"espada"
const NOMBRE_ESPADA := "Espada vieja"
const TEXTO_PROMPT := "Tomar espada vieja"
## Vacío = no sale ningún mensaje al recogerla.
const MENSAJE := ""
const ANIM_RECOGER := &"PickUp_Table"
const LARGO_EN_MANO := 1.0
## true = la espada no se puede tomar hasta que termine el tutorial de controles (TutorialControles).
const ESPERAR_AL_TUTORIAL := true
## Dónde queda la espada respecto al cadáver (X a su lado, Z a lo largo del cuerpo).
const POSICION_ESPADA := Vector3(0.85, 0.0, -0.3)

var _terreno
var _rng := RandomNumberGenerator.new()


## pos_xz = punto (X, Z) donde queda el cadáver, en el espacio del terreno.
func construir(terreno, pos_xz: Vector2) -> void:
	_terreno = terreno
	_rng.seed = 7
	var n: Vector3 = _normal(pos_xz.x, pos_xz.y)
	var y: float = _h(pos_xz.x, pos_xz.y) - HUNDIMIENTO_CADAVER
	var giro := Basis(Vector3.UP, deg_to_rad(GIRO_CADAVER))
	var base: Basis = Basis(Quaternion(Vector3.UP, n)) * giro

	var cuerpo := Node3D.new()
	cuerpo.name = "Cadaver"
	cuerpo.transform = Transform3D(base, Vector3(pos_xz.x, y, pos_xz.y))
	add_child(cuerpo)
	_crear_cadaver(cuerpo)

	var lado: Vector3 = base * POSICION_ESPADA
	var ex: float = pos_xz.x + lado.x
	var ez: float = pos_xz.y + lado.z
	_crear_espada(Vector3(ex, _h(ex, ez), ez))


# ------------------------------------------------------------------------------------
# Terreno
# ------------------------------------------------------------------------------------

func _h(x: float, z: float) -> float:
	return _terreno.altura_base(x, z)


func _normal(x: float, z: float) -> Vector3:
	var dhdx: float = (_h(x + 0.5, z) - _h(x - 0.5, z)) / 1.0
	var dhdz: float = (_h(x, z + 0.5) - _h(x, z - 0.5)) / 1.0
	return Vector3(-dhdx, 1.0, -dhdz).normalized()


# ------------------------------------------------------------------------------------
# Cadáver
# ------------------------------------------------------------------------------------

func _crear_cadaver(cuerpo: Node3D) -> void:
	if ResourceLoader.exists(ARCHIVO_CADAVER):
		var escena := load(ARCHIVO_CADAVER) as PackedScene
		if escena != null:
			var modelo := escena.instantiate() as Node3D
			if modelo != null:
				cuerpo.add_child(modelo)
				var medida: AABB = _aabb_de(modelo)
				var giro := Basis.from_euler(ROTACION_MODELO * (PI / 180.0))
				var caja: AABB = Transform3D(giro, Vector3.ZERO) * medida
				var mayor: float = maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
				var k: float = LARGO_CADAVER / maxf(mayor, 0.001)
				var c: Vector3 = caja.get_center()
				modelo.transform = Transform3D(
						giro * Basis.from_scale(Vector3.ONE * k),
						Vector3(-c.x * k, -caja.position.y * k, -c.z * k))
				return
	_cadaver_provisional(cuerpo)


# Cuerpo tendido boca arriba con la cabeza hacia -Z. Provisional: reemplázalo por un modelo.
func _cadaver_provisional(cuerpo: Node3D) -> void:
	var piel := _material(Color(0.42, 0.33, 0.25), 0.95)
	var tela := _material(Color(0.36, 0.30, 0.22), 1.0)
	# Cabeza, tronco con túnica y cadera.
	_esfera(cuerpo, Vector3(0.0, 0.12, -0.70), 0.11, piel)
	_caja(cuerpo, Vector3(0.40, 0.18, 0.54), Vector3(0.0, 0.11, -0.27), tela)
	_caja(cuerpo, Vector3(0.32, 0.15, 0.20), Vector3(0.0, 0.09, 0.08), tela)
	# Brazos: el izquierdo abierto, el derecho sobre el vientre.
	_miembro(cuerpo, Vector3(-0.24, 0.12, -0.46), Vector3(-0.38, 0.07, -0.22), 0.045, piel)
	_miembro(cuerpo, Vector3(-0.38, 0.07, -0.22), Vector3(-0.32, 0.05, 0.02), 0.04, piel)
	_miembro(cuerpo, Vector3(0.24, 0.12, -0.46), Vector3(0.34, 0.08, -0.20), 0.045, piel)
	_miembro(cuerpo, Vector3(0.34, 0.08, -0.20), Vector3(0.14, 0.15, -0.12), 0.04, piel)
	# Piernas y pies.
	_miembro(cuerpo, Vector3(-0.12, 0.09, 0.12), Vector3(-0.14, 0.08, 0.52), 0.065, tela)
	_miembro(cuerpo, Vector3(-0.14, 0.08, 0.52), Vector3(-0.18, 0.06, 0.92), 0.055, tela)
	_miembro(cuerpo, Vector3(0.12, 0.09, 0.12), Vector3(0.20, 0.09, 0.50), 0.065, tela)
	_miembro(cuerpo, Vector3(0.20, 0.09, 0.50), Vector3(0.12, 0.06, 0.94), 0.055, tela)
	_caja(cuerpo, Vector3(0.10, 0.06, 0.22), Vector3(-0.18, 0.04, 1.02), piel)
	_caja(cuerpo, Vector3(0.10, 0.06, 0.22), Vector3(0.12, 0.04, 1.04), piel)
	# Tiras de tela rasgada sobre la arena.
	for i in range(5):
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var tira := Vector3(_rng.randf_range(0.08, 0.16), 0.012, _rng.randf_range(0.25, 0.5))
		var pos := Vector3(lado * _rng.randf_range(0.24, 0.34), 0.012, _rng.randf_range(-0.1, 0.6))
		_caja(cuerpo, tira, pos, tela, _rng.randf_range(-0.6, 0.6))


func _material(color: Color, rugosidad: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	return m


func _esfera(padre: Node3D, pos: Vector3, radio: float, mat: Material) -> void:
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 12
	malla.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	padre.add_child(mi)


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, mat: Material, giro_y: float = 0.0) -> void:
	var malla := BoxMesh.new()
	malla.size = tam
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, giro_y), pos)
	padre.add_child(mi)


# Cápsula que va de un punto a otro (brazos y piernas).
func _miembro(padre: Node3D, a: Vector3, b: Vector3, radio: float, mat: Material) -> void:
	var dir: Vector3 = b - a
	var malla := CapsuleMesh.new()
	malla.radius = radio
	malla.height = dir.length() + radio * 2.0
	malla.radial_segments = 8
	malla.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir.normalized())), (a + b) * 0.5)
	padre.add_child(mi)


# ------------------------------------------------------------------------------------
# Espada (misma mecánica que en grieta_desierto.gd)
# ------------------------------------------------------------------------------------

func _crear_espada(pos: Vector3) -> void:
	# En el editor solo se dibuja; al jugar es un objeto recogible.
	var raiz: Node3D
	if Engine.is_editor_hint():
		raiz = Node3D.new()
	else:
		var recogible := StaticBody3D.new()
		recogible.set_script(load(RUTA_RECOGIBLE))
		recogible.set("id_objeto", ID_ESPADA)
		recogible.set("nombre_objeto", NOMBRE_ESPADA)
		recogible.set("texto_prompt", TEXTO_PROMPT)
		recogible.set("mensaje", MENSAJE)
		recogible.connect(&"interactuado", _al_recoger)
		raiz = recogible
	raiz.name = "Espada"
	add_child(raiz)
	raiz.position = pos

	# El modelo, de cabeza: la punta hacia la arena y el pomo arriba.
	var pivote := Node3D.new()
	pivote.name = "Pivote"
	pivote.rotation_degrees = Vector3(INCLINACION_ESPADA, 0.0, 0.0)
	raiz.add_child(pivote)
	var modelo: Node3D = _crear_modelo_espada()
	var medida: AABB = _aabb_de(modelo)
	var k: float = LARGO_ESPADA / maxf(medida.size.y, 0.001)
	var c: Vector3 = medida.get_center()
	modelo.scale = Vector3.ONE * k
	modelo.rotation = Vector3(0.0, 0.0, PI)
	modelo.position = Vector3(c.x * k, medida.end.y * k - HUNDIMIENTO_ESPADA, -c.z * k)
	pivote.add_child(modelo)

	if not Engine.is_editor_hint():
		raiz.set("anim_recoger", ANIM_RECOGER)
		raiz.set("equipar_en_mano", true)
		raiz.connect(&"interactuado", _preparar_modelo_para_mano.bind(raiz, modelo, medida))
		# Una caja un poco más ancha que la hoja, para que sea fácil apuntarle.
		var visible_largo: float = maxf(LARGO_ESPADA - HUNDIMIENTO_ESPADA, 0.3)
		var colision := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(0.7, visible_largo + 0.2, 0.7)
		colision.shape = caja
		colision.position = Vector3(0.0, visible_largo * 0.5, 0.0)
		raiz.add_child(colision)
		if ESPERAR_AL_TUTORIAL:
			_esperar_tutorial(colision)


func _crear_modelo_espada() -> Node3D:
	if ResourceLoader.exists(ARCHIVO_ESPADA):
		var escena := load(ARCHIVO_ESPADA) as PackedScene
		if escena != null:
			var modelo := escena.instantiate() as Node3D
			if modelo != null:
				# Igual que en el menú: se quitan los "Cube" sueltos del modelo.
				for nodo in modelo.find_children("Cube*", "", true, false):
					nodo.get_parent().remove_child(nodo)
					nodo.free()
				if ACERO_NEGRO:
					var acero := StandardMaterial3D.new()
					acero.albedo_color = Color(0.07, 0.07, 0.085)
					acero.metallic = 0.9
					acero.roughness = 0.35
					for pieza in modelo.find_children("*", "MeshInstance3D", true, false):
						(pieza as MeshInstance3D).material_override = acero
				return modelo
	push_warning("cadaver_espada.gd: no se encontró la espada '%s'; se usa una de relleno." % ARCHIVO_ESPADA)
	var relleno := Node3D.new()
	var hoja := BoxMesh.new()
	hoja.size = Vector3(0.1, 1.5, 0.03)
	var acero_relleno := StandardMaterial3D.new()
	acero_relleno.albedo_color = Color(0.5, 0.5, 0.55)
	acero_relleno.metallic = 0.9
	acero_relleno.roughness = 0.35
	hoja.material = acero_relleno
	var malla := MeshInstance3D.new()
	malla.mesh = hoja
	relleno.add_child(malla)
	return relleno


# Caja que envuelve todas las piezas del modelo, en el espacio del propio modelo.
func _aabb_de(raiz: Node3D) -> AABB:
	var total := AABB()
	var primero: bool = true
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var pieza := nodo as MeshInstance3D
		if pieza.mesh == null:
			continue
		var relativa := Transform3D.IDENTITY
		var actual: Node = pieza
		while actual != null and actual != raiz:
			relativa = (actual as Node3D).transform * relativa
			actual = actual.get_parent()
		var caja: AABB = relativa * pieza.mesh.get_aabb()
		if primero:
			total = caja
			primero = false
		else:
			total = total.merge(caja)
	return total


# Se ejecuta justo al recoger, antes de que recogible.gd mande el modelo a la mano.
# Saca el modelo de su pose clavada y lo deja derecho, con el pomo en el origen.
func _preparar_modelo_para_mano(_quien: Node, raiz: Node3D, modelo: Node3D, medida: AABB) -> void:
	if not is_instance_valid(modelo) or not is_instance_valid(raiz):
		return
	var k: float = LARGO_EN_MANO / maxf(medida.size.y, 0.001)
	var c: Vector3 = medida.get_center()
	var agarre := Node3D.new()
	agarre.name = "EspadaEnMano"
	raiz.add_child(agarre)
	modelo.reparent(agarre, false)
	modelo.transform = Transform3D(
			Basis.from_scale(Vector3.ONE * k),
			Vector3(-c.x * k, -medida.position.y * k, -c.z * k))
	raiz.set("nodo_visual", agarre)


# Mientras el tutorial de controles siga activo, la espada no tiene colisión: el rayo del
# interactor no la detecta y no aparece el aviso. Al terminar el tutorial se activa sola.
func _esperar_tutorial(colision: CollisionShape3D) -> void:
	var escena: Node = get_tree().current_scene
	if escena == null:
		return
	var tutorial: Node = escena.find_child("TutorialControles", true, false)
	if tutorial == null or not tutorial.has_method(&"esta_activo") or not tutorial.has_signal(&"tutorial_completado"):
		return
	if not tutorial.call(&"esta_activo"):
		return
	colision.disabled = true
	tutorial.connect(&"tutorial_completado", _habilitar_espada.bind(colision), CONNECT_ONE_SHOT)


func _habilitar_espada(colision: CollisionShape3D) -> void:
	if is_instance_valid(colision):
		colision.disabled = false


func _al_recoger(_quien: Node) -> void:
	espada_recogida.emit()
