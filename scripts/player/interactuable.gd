class_name Interactuable
extends StaticBody3D

signal interactuado(quien: Node)

## Texto del aviso que aparece al mirar el objeto, por ejemplo "Leer nota" o "Abrir puerta".
@export var texto_prompt: String = "Examinar"
## Mensaje que se muestra en pantalla al interactuar (déjalo vacío si no hace falta).
@export_multiline var mensaje: String = ""

@export_group("Animación")
## Animación del maniquí al interactuar, por ejemplo PickUp_Table, PickUp_Kneeling o Interact.
## Déjalo vacío para interactuar al instante, sin animación.
@export var anim_recoger: StringName = &""


func interactuar(quien: Node) -> void:
	interactuado.emit(quien)
