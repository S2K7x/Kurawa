extends Control
class_name SigilBackground

## Fond commun à tous les écrans : encre noire, sceau de la Brèche en filigrane et vignette.
## Entièrement dessiné (aucune texture à produire), inspiré des sigils géométriques en
## arrière-plan des écrans de référence (Design-Style/).

## Teinte du sceau : cramoisi par défaut, la couleur de guilde.
@export var sigil_color: Color = Style.CRIMSON
## Opacité du filigrane : il doit se deviner, pas se lire.
@export_range(0.0, 0.3, 0.005) var sigil_alpha: float = 0.075
@export var vignette_strength: float = 0.9

var _vignette: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = _build_vignette()
	resized.connect(queue_redraw)

func _build_vignette() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(Style.INK_DEEP, 0.0),
		Color(Style.INK_DEEP, 0.25 * vignette_strength),
		Color(Style.INK_DEEP, vignette_strength),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	return texture

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Style.INK)

	var center := Vector2(size.x * 0.5, size.y * 0.42)
	var radius: float = minf(size.x, size.y) * 0.62
	var color := Color(sigil_color, sigil_alpha)
	var faint := Color(sigil_color, sigil_alpha * 0.6)

	# Anneaux concentriques et couronne de graduations.
	draw_arc(center, radius, 0, TAU, 96, color, 1.5, true)
	draw_arc(center, radius * 0.82, 0, TAU, 96, faint, 1.0, true)
	draw_arc(center, radius * 0.34, 0, TAU, 64, faint, 1.0, true)
	for i in range(48):
		var angle := TAU * i / 48.0
		var direction := Vector2.from_angle(angle)
		var tick: float = 0.04 if i % 4 == 0 else 0.02
		draw_line(center + direction * radius * 0.82, center + direction * radius * (0.82 - tick), faint, 1.0, true)

	# Triangles entrelacés : la Brèche vue comme un sceau.
	for offset: float in [0.0, PI]:
		var points := PackedVector2Array()
		for i in range(3):
			points.append(center + Vector2.from_angle(offset + TAU * i / 3.0 - PI / 2.0) * radius * 0.82)
		points.append(points[0])
		draw_polyline(points, color, 1.5, true)

	# Éclats dispersés, comme des fragments arrachés à la déchirure.
	for i in range(7):
		var angle := TAU * i / 7.0 + 0.4
		var shard_center := center + Vector2.from_angle(angle) * radius * 1.05
		var shard := PackedVector2Array([
			shard_center + Vector2(0, -12), shard_center + Vector2(5, 0),
			shard_center + Vector2(0, 12), shard_center + Vector2(-5, 0), shard_center + Vector2(0, -12),
		])
		draw_polyline(shard, faint, 1.0, true)

	draw_texture_rect(_vignette, rect, false)
