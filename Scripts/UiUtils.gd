extends RefCounted
class_name UiUtils

## Petits utilitaires d'interface partagés. Ils vivaient recopiés dans quatre écrans :
## une seule version, testée une fois, vaut mieux que quatre qui divergeront.

## Initiales d'un nom, pour les pastilles et les placeholders ("Renji Kotsu" -> "RK").
static func initials(full_name: String) -> String:
	var result := ""
	for part: String in full_name.split(" ", false):
		result += part.substr(0, 1).to_upper()
	return result

## Vide un conteneur immédiatement : queue_free() seul laisse les enfants dans l'arbre
## jusqu'à la fin de la frame, ce qui fausserait tout comptage juste après.
static func clear_children(host: Node) -> void:
	for child: Node in host.get_children():
		host.remove_child(child)
		child.queue_free()
