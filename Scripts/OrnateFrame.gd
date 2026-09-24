extends Control
class_name OrnateFrame

## Cadre gravé posé par-dessus un panneau ou une carte : liseré fin et équerres d'angle,
## comme les cartouches des écrans de référence (Design-Style/).
## Purement décoratif : ne capte jamais les clics.

@export var line_color: Color = Style.GOLD_DIM:
	set(value):
		line_color = value
		queue_redraw()
@export var bracket_color: Color = Style.GOLD:
	set(value):
		bracket_color = value
		queue_redraw()
@export var inset: float = 5.0
@export var bracket_length: float = 16.0
@export var draw_outline: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

## Le cadre suit le bord du parent, pas sa propre boîte : posé dans un Container,
## il hériterait sinon des marges de contenu et viendrait barrer le texte.
func _frame_rect() -> Rect2:
	var parent := get_parent_control()
	if parent == null:
		return Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
	return Rect2(-position + Vector2.ONE * inset, parent.size - Vector2.ONE * inset * 2.0)

func _draw() -> void:
	var rect := _frame_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	if draw_outline:
		draw_rect(rect, line_color, false, 1.0)
	Style.draw_corner_brackets(self, rect, bracket_color, bracket_length, 2.0)
