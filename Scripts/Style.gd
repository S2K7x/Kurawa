extends RefCounted
class_name Style

## Palette et fabriques de styles de l'UI Kurawa : noir d'encre, cramoisi de guilde,
## liserés or pâle. Référence visuelle : Design-Style/ (écrans de sélection de légende
## et gabarit de cartes TCG). Voir GDD.md > Direction artistique.
##
## Tout ce qui est couleur ou cadre d'interface passe par ici ; les couleurs d'éléments
## et de raretés, elles, restent pilotées par les données (DataLoader).

# --- Palette -----------------------------------------------------------------------------------

const INK := Color("#08060a")          # fond général
const INK_DEEP := Color("#050407")     # fond des overlays
const SURFACE := Color("#16090d")      # panneaux
const SURFACE_RAISED := Color("#20101a")
const CRIMSON := Color("#a3172a")      # accent principal (guilde)
const CRIMSON_BRIGHT := Color("#d8263a")
const CRIMSON_DEEP := Color("#4a0d18")
const GOLD := Color("#e3d3a8")         # liserés et titres
const GOLD_DIM := Color("#8c7a52")
const TEXT := Color("#ece4d6")
const TEXT_MUTED := Color("#96887e")

# --- Cadres ------------------------------------------------------------------------------------

## Panneau sombre à liseré fin, base de tous les encadrés de l'interface.
static func panel(bg: Color = SURFACE, border: Color = GOLD_DIM, radius: int = 4, margin: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

## Panneau teinté cramoisi translucide (fiches, encarts de texte des références).
static func crimson_panel(margin: int = 18) -> StyleBoxFlat:
	var style := panel(Color(CRIMSON_DEEP, 0.55), Color(CRIMSON, 0.7), 2, margin)
	return style

## Bouton d'action : fond cramoisi plein, liseré or au survol (cf. « PICK LEGEND »).
static func action_button(bg: Color, border: Color, margin_v: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(2)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style

## Onglet de navigation : rien qu'un soulignement, or quand il est actif.
static func nav_tab(underline: Color, thickness: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_bottom = thickness
	style.border_color = underline
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 14
	style.content_margin_bottom = 12
	return style

# --- Dessin ------------------------------------------------------------------------------------

## Équerres d'angle façon cartouche gravé, à appeler depuis un _draw().
static func draw_corner_brackets(canvas: CanvasItem, rect: Rect2, color: Color, length: float = 14.0, width: float = 1.0) -> void:
	var corners := [
		[rect.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1, 0), Vector2(0, -1)],
		[rect.end, Vector2(-1, 0), Vector2(0, -1)],
	]
	for corner: Array in corners:
		var origin: Vector2 = corner[0]
		canvas.draw_line(origin, origin + corner[1] * length, color, width)
		canvas.draw_line(origin, origin + corner[2] * length, color, width)

## Losange (badge de stat des cartes TCG de référence).
static func draw_diamond(canvas: CanvasItem, center: Vector2, radius: float, fill: Color, border: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	])
	canvas.draw_colored_polygon(points, fill)
	canvas.draw_polyline(points + PackedVector2Array([points[0]]), border, 1.0, true)
