@tool
extends Node3D
## Calavera monumental procedural para el fondo de la arena.
## Compatible con scripts/world/dunas.gd: construir(terreno).
## No requiere modelos externos.

@export var escala_general: float = 1.0

var hueso: StandardMaterial3D
var sombra: StandardMaterial3D
var dientes: StandardMaterial3D
var musgo: StandardMaterial3D

func construir(terreno: Node3D) -> void:
    for hijo in get_children():
        remove_child(hijo)
        hijo.free()

    hueso = _material(Color(0.72, 0.68, 0.56), 0.93)
    sombra = _material(Color(0.085, 0.075, 0.068), 1.0)
    dientes = _material(Color(0.86, 0.81, 0.66), 0.8)
    musgo = _material(Color(0.16, 0.21, 0.11), 1.0)

    var avance: float = terreno.distancia_arena + terreno.radio_arena + 16.0
    var x: float = terreno.centro_valle(avance)
    # Situada tras el combate, ligeramente hundida en la duna de cierre.
    position = Vector3(x, terreno.altura_base(x, -avance) - 4.0, -avance)
    rotation.y = 0.0
    scale = Vector3.ONE * escala_general

    # Frente de la calavera: mira hacia +Z, hacia el jugador.
    _esfera("Craneo", Vector3(0, 14.8, 0), Vector3(13.5, 12.2, 8.2), hueso)
    _esfera("Frente", Vector3(0, 19.8, 3.6), Vector3(11.8, 7.4, 5.2), hueso)
    _esfera("PomuloIzquierdo", Vector3(-8.4, 9.2, 4.8), Vector3(5.4, 4.0, 4.6), hueso)
    _esfera("PomuloDerecho", Vector3(8.4, 9.2, 4.8), Vector3(5.4, 4.0, 4.6), hueso)
    _esfera("Maxilar", Vector3(0, 5.4, 4.6), Vector3(8.6, 4.2, 4.1), hueso)
    _esfera("Mandibula", Vector3(0, 2.1, 4.3), Vector3(9.2, 2.1, 3.0), hueso)

    # Cavidades negras superpuestas sobre el hueso: oscuridad profunda.
    _esfera("CuencaIzquierda", Vector3(-5.7, 13.1, 7.0), Vector3(4.25, 4.8, 1.2), sombra)
    _esfera("CuencaDerecha", Vector3(5.7, 13.1, 7.0), Vector3(4.25, 4.8, 1.2), sombra)
    _esfera("Nariz", Vector3(0, 8.0, 8.15), Vector3(2.15, 3.0, 0.95), sombra)
    _esfera("Boca", Vector3(0, 4.0, 8.05), Vector3(7.2, 1.25, 0.8), sombra)
    _esfera("SienIzquierda", Vector3(-10.6, 15.3, 4.6), Vector3(2.0, 2.7, 1.1), sombra)
    _esfera("SienDerecha", Vector3(10.6, 15.3, 4.6), Vector3(2.0, 2.7, 1.1), sombra)

    # Dientes independientes y algo irregulares.
    for i in range(12):
        var xx: float = (float(i) - 5.5) * 1.12
        var longitud: float = 2.3 if i % 3 != 0 else 1.8
        _esfera("Diente_%02d" % i, Vector3(xx, 4.35 - longitud * 0.32, 8.6),
            Vector3(0.46, longitud, 0.63), dientes)

    # Cuernos grandes curvados, nacen a ambos lados y se alzan hacia afuera.
    for lado in [-1.0, 1.0]:
        var puntos: Array[Vector3] = [
            Vector3(lado * 9.6, 20.5, 0.2),
            Vector3(lado * 13.2, 23.1, 0.0),
            Vector3(lado * 16.4, 26.7, -0.3),
            Vector3(lado * 18.1, 31.1, -0.8),
            Vector3(lado * 18.0, 35.5, -1.5),
            Vector3(lado * 15.9, 39.0, -2.1)
        ]
        for i in range(puntos.size() - 1):
            var grosor: float = lerpf(2.9, 0.32, float(i) / float(puntos.size() - 1))
            _segmento("Cuerno_%s_%d" % [str(lado), i], puntos[i], puntos[i + 1], grosor, hueso)

    # Pequeños restos de vegetación que la integran al paisaje.
    for lado in [-1.0, 1.0]:
        _esfera("Musgo", Vector3(lado * 10.5, 8.3, -0.3),
            Vector3(3.1, 1.2, 2.5), musgo)

func _material(color: Color, rugosidad: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = rugosidad
    return mat

func _esfera(nombre: String, centro: Vector3, radios: Vector3, mat: Material) -> void:
    var nodo := MeshInstance3D.new()
    nodo.name = nombre
    var mesh := SphereMesh.new()
    mesh.radial_segments = 24
    mesh.rings = 12
    nodo.mesh = mesh
    nodo.position = centro
    nodo.scale = radios
    nodo.material_override = mat
    add_child(nodo)

func _segmento(nombre: String, a: Vector3, b: Vector3, radio: float, mat: Material) -> void:
    var direccion := b - a
    var nodo := MeshInstance3D.new()
    nodo.name = nombre
    var mesh := CylinderMesh.new()
    mesh.top_radius = radio * 0.75
    mesh.bottom_radius = radio
    mesh.height = direccion.length()
    mesh.radial_segments = 14
    nodo.mesh = mesh
    nodo.position = (a + b) * 0.5
    nodo.quaternion = Quaternion(Vector3.UP, direccion.normalized())
    nodo.material_override = mat
    add_child(nodo)
