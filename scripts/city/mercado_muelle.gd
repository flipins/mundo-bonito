@tool
extends Node3D

const CAJON_MANZANAS := "res://assets/fantasy_props/export/FarmCrate_Apple.gltf"
const CAJON_ZANAHORIAS := "res://assets/fantasy_props/export/FarmCrate_Carrot.gltf"


func _ready() -> void:
	child_entered_tree.connect(_al_entrar)

	var muelle := get_node_or_null("Muelle") as Node3D
	if muelle != null:
		_montar.call_deferred(muelle.get_instance_id())


func _al_entrar(nodo: Node) -> void:
	if nodo.name == &"Muelle":
		_montar.call_deferred(nodo.get_instance_id())


func _montar(id: int) -> void:
	var muelle := instance_from_id(id) as Node3D
	if not is_instance_valid(muelle) or muelle.get_parent() != self:
		return
	if has_node("MercadoDelMuelle"):
		return

	var generador := get_parent().get_parent()
	var cubierta := muelle.get_node("Paseo/Cubierta") as MeshInstance3D
	var piso := to_local(cubierta.global_position).y + (cubierta.mesh as BoxMesh).size.y * 0.5

	var mercado := Node3D.new()
	mercado.name = "MercadoDelMuelle"
	add_child(mercado)

	var madera := _material(Color("#785437"))
	var pescado := _material(Color("#91b5b9"))
	var azul := _material(Color("#397487"))
	var ocre := _material(Color("#c0833e"))
	var frutas: Array[Material] = [
		_material(Color("#b84b39")),
		_material(Color("#df9137")),
		_material(Color("#8eaa48"))
	]

	var usar_modelos := (
		bool(generador.get("generar_decoracion"))
		and generador.has_method("colocar_modelo_ciudad")
	)

	for z: float in [-28.0, -41.0, -54.0, 86.0, 99.0, 112.0]:
		var pesca := z < 0.0
		var puesto := Node3D.new()
		puesto.name = ("Pescaderia" if pesca else "Fruteria") + str(int(absf(z)))
		mercado.add_child(puesto)

		# Alinea el puesto con la curva del paseo.
		var costa: float = generador.call("_costa", z)
		var adelante: float = generador.call("_costa", z + 1.0)
		var atras: float = generador.call("_costa", z - 1.0)
		puesto.position = Vector3(costa + 2.7, piso, z)
		puesto.rotation.y = atan2(adelante - atras, 2.0)

		_bloque(
			puesto, Vector3(0, 0.55, 0),
			Vector3(1.55, 1.1, 4.4), madera
		)

		for extremo: float in [-1.0, 1.0]:
			_bloque(
				puesto, Vector3(-0.65, 1.5, extremo * 2.0),
				Vector3(0.13, 3.0, 0.13), madera
			)

		var lona := _bloque(
			puesto, Vector3(0.12, 2.85, 0),
			Vector3(2.6, 0.13, 4.9), azul if pesca else ocre
		)
		lona.rotation.z = -0.10

		if generador.get("generar_colisiones"):
			var cuerpo := StaticBody3D.new()
			var forma := CollisionShape3D.new()
			var caja := BoxShape3D.new()
			caja.size = Vector3(1.55, 1.1, 4.4)
			forma.shape = caja
			forma.position.y = 0.55
			cuerpo.add_child(forma)
			puesto.add_child(cuerpo)

		for fila in range(3):
			var centro_z := (fila - 1) * 1.37

			# Apoya cada cajón importado sobre la mesa, a 1.10 m.
			if usar_modelos and not pesca:
				var ruta := CAJON_ZANAHORIAS if fila == 1 else CAJON_MANZANAS
				var colocado: bool = generador.call(
					"colocar_modelo_ciudad",
					puesto,
					ruta,
					Vector3(0.0, 1.10, centro_z),
					1.23,
					0.0
				)
				if colocado:
					continue

			# Cajón de madera para el pescado o para la fruta de respaldo.
			_bloque(
				puesto, Vector3(0, 1.15, centro_z),
				Vector3(1.38, 0.10, 1.28), madera
			)

			for borde: float in [-1.0, 1.0]:
				_bloque(
					puesto, Vector3(borde * 0.66, 1.24, centro_z),
					Vector3(0.07, 0.19, 1.28), madera
				)
				_bloque(
					puesto, Vector3(0, 1.24, centro_z + borde * 0.60),
					Vector3(1.32, 0.19, 0.07), madera
				)

			if pesca:
				for i in range(3):
					var pez := Vector3((i - 1) * 0.38, 1.32, centro_z)
					_ovalo(puesto, pez, Vector3(0.23, 0.17, 0.68), pescado)
					_ovalo(
						puesto, pez + Vector3(0, 0, 0.34),
						Vector3(0.30, 0.07, 0.16), pescado
					)
			else:
				for i in range(3):
					for j in range(3):
						var pos_fruta := Vector3(
							(i - 1) * 0.34,
							1.37,
							centro_z + (j - 1) * 0.34
						)
						_ovalo(
							puesto, pos_fruta,
							Vector3(0.31, 0.34, 0.31), frutas[fila]
						)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _bloque(
	padre: Node3D,
	pos: Vector3,
	medidas: Vector3,
	material: Material
) -> MeshInstance3D:
	var malla := BoxMesh.new()
	malla.size = medidas

	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.material_override = material
	nodo.position = pos
	padre.add_child(nodo)
	return nodo


# Agrupa los productos que comparten material para dibujarlos juntos.
func _ovalo(
	padre: Node3D,
	pos: Vector3,
	medidas: Vector3,
	material: Material
) -> void:
	var nombre := "Productos" + str(material.get_instance_id())
	var grupo := padre.get_node_or_null(nombre) as MultiMeshInstance3D

	if grupo == null:
		grupo = MultiMeshInstance3D.new()
		grupo.name = nombre

		var lote := MultiMesh.new()
		lote.transform_format = MultiMesh.TRANSFORM_3D
		lote.mesh = _esfera_producto()
		lote.instance_count = 18
		lote.visible_instance_count = 0

		grupo.multimesh = lote
		grupo.material_override = material
		padre.add_child(grupo)

	var indice := grupo.multimesh.visible_instance_count
	var transformacion := Transform3D(Basis.from_scale(medidas), pos)
	grupo.multimesh.set_instance_transform(indice, transformacion)
	grupo.multimesh.visible_instance_count = indice + 1


func _esfera_producto() -> SphereMesh:
	var malla := SphereMesh.new()
	malla.radius = 0.5
	malla.height = 1.0
	malla.radial_segments = 8
	malla.rings = 3
	return malla
