extends Control
class_name BreachPortal

## La Brèche : déchirure dimensionnelle dessinée à la main (aucune texture), pièce
## maîtresse de l'écran d'invocation. Anneaux runiques en rotation lente, cœur cramoisi
## qui respire. Le style suit les sceaux gravés des écrans de référence (Design-Style/).

## Vitesse de rotation des deux couronnes, en tours par seconde (sens opposés).
const OUTER_SPEED := 0.04
const INNER_SPEED := -0.07
const PULSE_PERIOD := 3.2
## Diamètre maximal du sceau, quelle que soit la place disponible.
const MAX_DIAMETER := 300.0

var _time: float = 0.0
## Intensité ajoutée le temps d'une invocation (0 = repos).
var _charge: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	# Un onglet caché n'a pas à faire tourner ses anneaux : sans ce test, la Brèche se
	# redessinait soixante fois par seconde pendant qu'on visitait la galerie.
	if not is_visible_in_tree():
		return
	_time += delta
	_charge = maxf(_charge - delta * 1.2, 0.0)
	queue_redraw()

## Fait rugir la Brèche : appelé au moment d'une invocation.
func flare() -> void:
	_charge = 1.0

func _draw() -> void:
	var center := size / 2.0
	# Le sceau ne doit pas avaler l'écran : il reste une pièce centrale, pas un fond.
	var radius: float = minf(minf(size.x, size.y), MAX_DIAMETER) * 0.46
	var pulse := 0.5 + 0.5 * sin(TAU * _time / PULSE_PERIOD)
	var intensity: float = 0.35 + 0.15 * pulse + 0.5 * _charge

	# Halo : disques concentriques de plus en plus opaques vers le cœur.
	for i in range(8):
		var t := float(i) / 8.0
		draw_circle(center, radius * (1.15 - t * 0.55), Color(Style.CRIMSON, 0.05 * intensity))
	draw_circle(center, radius * 0.62, Color(Style.CRIMSON_DEEP, 0.5 + 0.25 * _charge))
	_draw_rift(center, radius, intensity)

	# Couronne extérieure : anneau or et graduations en rotation.
	var outer_angle := TAU * _time * OUTER_SPEED
	draw_arc(center, radius, 0, TAU, 128, Color(Style.GOLD, 0.75), 1.5, true)
	for i in range(36):
		var angle := outer_angle + TAU * i / 36.0
		var direction := Vector2.from_angle(angle)
		var length: float = 0.07 if i % 3 == 0 else 0.035
		draw_line(center + direction * radius, center + direction * radius * (1.0 - length),
			Color(Style.GOLD, 0.55), 1.0, true)

	# Couronne intérieure : triangle et losanges cramoisis tournant en sens inverse.
	var inner_angle := TAU * _time * INNER_SPEED
	var triangle := PackedVector2Array()
	for i in range(3):
		triangle.append(center + Vector2.from_angle(inner_angle + TAU * i / 3.0 - PI / 2.0) * radius * 0.78)
	triangle.append(triangle[0])
	draw_polyline(triangle, Color(Style.CRIMSON_BRIGHT, 0.5 + 0.3 * _charge), 1.5, true)
	draw_arc(center, radius * 0.78, 0, TAU, 96, Color(Style.CRIMSON, 0.45), 1.0, true)
	for i in range(6):
		var angle := -inner_angle + TAU * i / 6.0
		Style.draw_diamond(self, center + Vector2.from_angle(angle) * radius * 0.78, 5.0,
			Color(Style.INK_DEEP, 0.9), Color(Style.GOLD, 0.7))

	# Éclats de la déchirure : traits fins qui jaillissent du cœur.
	for i in range(12):
		var angle := inner_angle * 0.5 + TAU * i / 12.0
		var direction := Vector2.from_angle(angle)
		var start: float = 0.36 + 0.04 * sin(_time * 1.7 + i)
		draw_line(center + direction * radius * start, center + direction * radius * (start + 0.16),
			Color(Style.CRIMSON_BRIGHT, (0.25 + 0.5 * _charge) * intensity), 1.0, true)

## La déchirure elle-même : une fente verticale incandescente au cœur du sceau,
## doublée d'un halo — c'est de là que sortent les guerriers.
func _draw_rift(center: Vector2, radius: float, intensity: float) -> void:
	var height: float = radius * (1.02 + 0.06 * _charge)
	var width: float = radius * (0.045 + 0.035 * _charge)
	for layer: int in range(4):
		# Une fente fine et blanche au centre, noyée dans des couches cramoisies de plus
		# en plus larges et transparentes : une fissure de lumière, pas un œil.
		var scale: float = 1.0 + layer * 1.35
		var alpha: float = (0.8 - layer * 0.2) * (0.55 + 0.45 * intensity) / (1.0 + layer)
		var color: Color = Color(1, 0.94, 0.88, alpha) if layer == 0 else Color(Style.CRIMSON_BRIGHT, alpha)
		var lens := PackedVector2Array()
		var steps := 24
		for i in range(steps + 1):
			var t := float(i) / steps
			var y := lerpf(-height, height, t)
			lens.append(center + Vector2(width * scale * (1.0 - pow(2.0 * t - 1.0, 2)), y))
		for i in range(steps + 1):
			var t := 1.0 - float(i) / steps
			var y := lerpf(-height, height, t)
			lens.append(center + Vector2(-width * scale * (1.0 - pow(2.0 * t - 1.0, 2)), y))
		draw_colored_polygon(lens, color)
