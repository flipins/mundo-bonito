extends Node3D
## Se pone en el nodo UAL1_Standard (el maniquí), que debe ser hijo del CharacterBody3D "jugador".
## Lee la velocidad del padre y elige la animación. Además expone "puede_moverse":
## vale false desde que despegas hasta poco después de tocar el suelo, y mientras dura una
## interacción o un ataque. El script de jugador lo consulta para ignorar las teclas de movimiento.
 
## Emitida a mitad de la animación de interacción, cuando la mano llega al objeto.
signal momento_de_agarre
## Emitida cuando termina la animación de interacción (o de ataque).
signal interaccion_terminada
 
## Nombre de la acción de agacharse en tu Mapa de Entradas. Si no existe, se ignora.
@export var accion_agacharse: StringName = &"agacharse"
## Velocidad horizontal mínima para considerar que se mueve.
@export var umbral_movimiento: float = 0.2
## Segundos tras tocar el suelo después de los cuales se vuelve a poder mover, aunque la
## animación de aterrizaje no haya terminado. 0 = esperar a que termine la animación entera.
@export_range(0.0, 1.0, 0.01) var desbloqueo_aterrizaje: float = 0.25
 
## Qué tan rápido se reproduce la animación de levantarse al aterrizar (1 = velocidad original).
@export_range(0.5, 4.0, 0.05) var velocidad_aterrizaje: float = 1.8
 
@export_group("Caminar y correr")
## Acción de correr en tu Mapa de Entradas. Si no existe, se usa la tecla Shift.
@export var accion_correr: StringName = &"correr"
## Animaciones de caminar (tranquila). Se usa la primera que exista.
@export var anims_caminar: Array[StringName] = [&"Walk_Loop", &"Walk", &"Walk_Normal_Loop"]
## Animaciones de correr (rápida y agresiva). Se usa la primera que exista.
@export var anims_correr: Array[StringName] = [&"Sprint_Loop", &"Sprint", &"Jog_Fwd_Loop", &"Jog_Fwd"]
## Ajusta la velocidad de la animación a la velocidad real del jugador, para que los pies no patinen.
@export var sincronizar_pasos: bool = true
## Velocidad (m/s) a la que fue animado el caminar y el correr del pack. Más bajo = pasos más rápidos.
@export var velocidad_ref_caminar: float = 1.8
@export var velocidad_ref_correr: float = 5.0
## Límites de cuánto se puede acelerar o frenar la animación (1 = velocidad original).
@export_range(0.5, 1.0, 0.05) var escala_minima: float = 0.8
@export_range(1.0, 2.5, 0.05) var escala_maxima: float = 1.25
## Imprime en Salida la velocidad y la animación elegida (para comprobar qué se usa).
@export var depurar_velocidad: bool = false
 
@export_group("Interacción")
## Animación de interacción por defecto.
@export var anim_interactuar: StringName = &"Interact"
## Fracción (0 a 1) de la animación en la que se considera que agarras el objeto.
@export_range(0.0, 1.0, 0.05) var punto_de_agarre: float = 0.5
## Velocidad de reproducción de las animaciones de interacción.
@export_range(0.5, 3.0, 0.05) var velocidad_interaccion: float = 1.0
 
@export_group("Espada")
## Hueso de la mano donde se coloca el objeto. Si no existe, se busca uno parecido.
@export var hueso_mano: StringName = &"hand_r"
## Cómo queda el objeto en la mano (posición en metros y rotación en grados).
@export var posicion_en_mano: Vector3 = Vector3(0.0, 0.1, -0.15)
@export var rotacion_en_mano: Vector3 = Vector3(90.0, 0.0, 0.0)
## Animaciones que se usan cuando llevas la espada en la mano.
@export var anim_idle_espada: StringName = &"Sword_Idle"
@export var anim_ataque_espada: StringName = &"Sword_Attack"
 
## false mientras dura el salto (despegue, aire y primer tramo del aterrizaje), una interacción o un ataque.
var puede_moverse: bool = true
## true cuando ya tienes la espada equipada.
var con_espada: bool = false
## Modelo que lleva actualmente en la mano.
var objeto_en_mano: Node3D = null
 
var _cuerpo: CharacterBody3D = null
var _anim: AnimationPlayer = null
var _en_aire: bool = false
var _interactuando: bool = false
var _anim_interaccion: StringName = &""
var _agarre: BoneAttachment3D = null
var _ultimo_nombre: String = ""
 
 
func _ready() -> void:
	_cuerpo = get_parent() as CharacterBody3D
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _cuerpo == null or _anim == null:
		push_warning("animar_maniqui.gd: falta el CharacterBody3D padre o el AnimationPlayer del maniquí.")
		set_physics_process(false)
		return
 
	# Descomenta esta línea una vez para ver los nombres reales de las animaciones del pack.
	# print(_anim.get_animation_list())
 
	# Estas animaciones tienen que repetirse en bucle.
	var en_bucle: Array = ["Idle", "Crouch_Idle", "Crouch_Fwd", "Jump", "Sword_Idle"]
	en_bucle.append_array(anims_caminar)
	en_bucle.append_array(anims_correr)
	for nombre in en_bucle:
		if _anim.has_animation(nombre):
			_anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
 
	# Estas NO se repiten: se reproducen una vez y terminan.
	for nombre in ["Interact", "PickUp_Table", "PickUp_Kneeling", "Sword_Attack"]:
		if _anim.has_animation(nombre):
			_anim.get_animation(nombre).loop_mode = Animation.LOOP_NONE
 
	_anim.animation_finished.connect(_al_terminar_animacion)
	_anim.play("Idle")
 
 
func _unhandled_input(event: InputEvent) -> void:
	# Clic izquierdo: atacar (solo si tienes la espada).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if atacar():
			get_viewport().set_input_as_handled()
 
 
func _physics_process(_delta: float) -> void:
	# --- Interactuando o atacando: no se toca nada hasta que termine la animación ---
	if _interactuando:
		return
 
	# --- En el aire: despegue, y luego salto en bucle ---
	if not _cuerpo.is_on_floor():
		if not _en_aire:
			_en_aire = true
			puede_moverse = false
			_anim.speed_scale = 1.0
			_anim.play("Jump_Start", 0.1)
		elif _anim.assigned_animation == "Jump_Start" and not _anim.is_playing():
			_anim.play("Jump", 0.1)
		return
 
	# --- Aterrizaje ---
	if _en_aire:
		_en_aire = false
		_anim.play("Jump_Land", 0.05, velocidad_aterrizaje)
		return
	if _anim.assigned_animation == "Jump_Land" and _anim.is_playing():
		# Se libera el control un poco antes de que acabe la animación.
		if not puede_moverse and desbloqueo_aterrizaje > 0.0 and _anim.current_animation_position / velocidad_aterrizaje >= desbloqueo_aterrizaje:
			puede_moverse = true
		# Mientras siga bloqueado, se deja terminar la animación; si ya se puede mover, se sigue de largo.
		if not puede_moverse:
			return
 
	# --- En el suelo: quieto, caminando, corriendo o agachado ---
	var velocidad: float = Vector2(_cuerpo.velocity.x, _cuerpo.velocity.z).length()
	var se_mueve: bool = velocidad > umbral_movimiento
	var agachado: bool = InputMap.has_action(accion_agacharse) and Input.is_action_pressed(accion_agacharse)
 
	var nombre: String
	if agachado:
		nombre = "Crouch_Fwd" if se_mueve else "Crouch_Idle"
	elif se_mueve:
		if _quiere_correr():
			nombre = _primera_existente(anims_correr, "Idle")
		else:
			nombre = _primera_existente(anims_caminar, _primera_existente(anims_correr, "Idle"))
	elif con_espada and _anim.has_animation(anim_idle_espada):
		nombre = String(anim_idle_espada)
	else:
		nombre = "Idle"
 
	if depurar_velocidad and nombre != _ultimo_nombre:
		print("animar_maniqui.gd: velocidad %.2f, correr=%s -> %s (anim x%.2f)" % [velocidad, _quiere_correr(), nombre, _anim.speed_scale])
	_ultimo_nombre = nombre
 
	if _anim.assigned_animation != nombre or not _anim.is_playing():
		# Si aún queda aterrizaje en curso y no te mueves, se deja terminar.
		if _anim.assigned_animation == "Jump_Land" and _anim.is_playing() and not se_mueve:
			return
		_anim.play(nombre, 0.2)
 
	# Los pasos siguen la velocidad real, así el piso no parece deslizarse bajo los pies.
	if sincronizar_pasos and se_mueve and not agachado:
		var referencia: float = velocidad_ref_correr if _quiere_correr() else velocidad_ref_caminar
		_anim.speed_scale = clampf(velocidad / maxf(referencia, 0.1), escala_minima, escala_maxima)
	else:
		_anim.speed_scale = 1.0
 
 
func _quiere_correr() -> bool:
	if InputMap.has_action(accion_correr):
		return Input.is_action_pressed(accion_correr)
	return Input.is_physical_key_pressed(KEY_SHIFT)
 
 
# Devuelve la primera animación de la lista que exista en el AnimationPlayer.
func _primera_existente(lista: Array[StringName], por_defecto: String) -> String:
	for candidata in lista:
		if _anim.has_animation(candidata):
			return String(candidata)
	return por_defecto
 
 
## Reproduce una animación de interacción. Devuelve false si no se pudo (en el aire, ya interactuando, etc.).
## Devuelve true al instante; "momento_de_agarre" se emite más tarde, a la fracción "punto_de_agarre".
func reproducir_interaccion(nombre: StringName = &"") -> bool:
	if nombre == &"":
		nombre = anim_interactuar
	if _interactuando or _en_aire or not _cuerpo.is_on_floor():
		return false
	if not _anim.has_animation(nombre):
		push_warning("animar_maniqui.gd: no existe la animación '%s'." % nombre)
		return false
 
	_interactuando = true
	_anim_interaccion = nombre
	puede_moverse = false
	_anim.speed_scale = 1.0
	_anim.play(nombre, 0.15, velocidad_interaccion)
 
	var duracion: float = _anim.get_animation(nombre).length / velocidad_interaccion
	get_tree().create_timer(duracion * punto_de_agarre).timeout.connect(func() -> void:
		if _interactuando and _anim_interaccion == nombre:
			momento_de_agarre.emit()
	)
	return true
 
 
## Ataque con la espada. Devuelve false si no se puede (sin espada, en el aire, ocupado...).
func atacar() -> bool:
	if not con_espada or _interactuando or _en_aire or not _cuerpo.is_on_floor():
		return false
	if not _anim.has_animation(anim_ataque_espada):
		return false
	_interactuando = true
	_anim_interaccion = anim_ataque_espada
	puede_moverse = false
	_anim.speed_scale = 1.0
	_anim.play(anim_ataque_espada, 0.1)
	return true
 
 
## Coloca "visual" (un modelo 3D) en la mano del maniquí. Reemplaza lo que hubiera en la mano.
func equipar_en_mano(visual: Node3D) -> void:
	if not is_instance_valid(visual):
		push_warning("animar_maniqui.gd: el modelo a equipar ya no existe.")
		return
 
	# El esqueleto se busca por tipo, sin importar cómo se llame el nodo.
	var esqueleto: Skeleton3D = null
	for nodo in find_children("*", "Skeleton3D", true, false):
		esqueleto = nodo as Skeleton3D
		break
	if esqueleto == null:
		push_warning("animar_maniqui.gd: no se encontró ningún Skeleton3D dentro del maniquí.")
		return
 
	# Si el hueso configurado no existe, se busca uno que parezca la mano derecha.
	var hueso: StringName = hueso_mano
	if esqueleto.find_bone(hueso) == -1:
		hueso = &""
		for i in esqueleto.get_bone_count():
			var nombre_hueso := esqueleto.get_bone_name(i).to_lower()
			if nombre_hueso.contains("hand") and (nombre_hueso.ends_with("_r") or nombre_hueso.contains("right")):
				hueso = StringName(esqueleto.get_bone_name(i))
				break
		if hueso == &"":
			var huesos: PackedStringArray = []
			for i in esqueleto.get_bone_count():
				huesos.append(esqueleto.get_bone_name(i))
			push_warning("animar_maniqui.gd: no hay hueso de mano. Huesos: %s" % [huesos])
			return
		print("animar_maniqui.gd: se usa el hueso '%s' (cámbialo en 'Hueso Mano' para fijarlo)." % hueso)
 
	if _agarre == null or not is_instance_valid(_agarre):
		_agarre = BoneAttachment3D.new()
		_agarre.name = "AgarreMano"
		esqueleto.add_child(_agarre)
	_agarre.bone_name = hueso
 
	if is_instance_valid(objeto_en_mano) and objeto_en_mano != visual:
		objeto_en_mano.queue_free()
 
	visual.reparent(_agarre, false)
	visual.position = posicion_en_mano
	visual.rotation_degrees = rotacion_en_mano
	visual.visible = true
	objeto_en_mano = visual
	con_espada = true
	print("animar_maniqui.gd: espada equipada en '%s'." % hueso)
 
 
func _al_terminar_animacion(nombre: StringName) -> void:
	if nombre == &"Jump_Land":
		puede_moverse = true
	if _interactuando and nombre == _anim_interaccion:
		_interactuando = false
		_anim_interaccion = &""
		puede_moverse = true
		interaccion_terminada.emit()
 
