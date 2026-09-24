extends Control
class_name RevealBurst

## Gerbe de lumière derrière la carte révélée : rayons et anneaux à la couleur de la rareté.
## Plus la rareté est haute, plus la gerbe est dense et large — c'est le signal visuel
## qui dit « ça vaut le coup » avant même de lire la carte (GDD.md > Phase 2).

## Densité et portée par rareté.
const SHAPE := {
	"R": {"rays": 12, "reach": 0.55, "alpha": 0.16},
	"SR": {"rays": 20, "reach": 0.8, "alpha": 0.24},
	"SSR": {"rays": 30, "reach": 1.05, "alpha": 0.32},
}
## Les rayons démarrent loin du centre : sinon leurs bases se superposent toutes et
## la gerbe vire à l'aplat opaque.
const RAY_INNER := 0.34

## Avancement de l'animation (0 = rien, 1 = gerbe pleine), animé par SummonReveal.
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()

var _color: Color = Style.GOLD
var _shape: Dictionary = SHAPE["R"]
var _seed: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func configure(rarity: String, color: Color, variation: int) -> void:
	_color = color
	_shape = SHAPE.get(rarity, SHAPE["R"])
	# Une graine par tirage : deux cartes d'affilée n'ont pas exactement la même gerbe.
	_seed = variation
	queue_redraw()

func _draw() -> void:
	if progress <= 0.0:
		return
	var center := size / 2.0
	var base: float = minf(size.x, size.y) * float(_shape["reach"])
	var fade: float = float(_shape["alpha"]) * progress

	var rays: int = int(_shape["rays"])
	for i in range(rays):
		var angle := TAU * i / rays + _seed * 0.37
		var direction := Vector2.from_angle(angle)
		# Longueurs alternées : la gerbe respire au lieu d'être une roue régulière.
		var length := base * (0.55 + 0.45 * absf(sin(i * 2.4 + _seed)))
		# Coin effilé : large au centre, pointe à l'extérieur (sinon les rayons se lisent
		# comme des barres épaisses au bord de l'écran).
		var points := PackedVector2Array([
			center + direction * length * progress,
			center + direction.rotated(0.09) * base * RAY_INNER,
			center + direction.rotated(-0.09) * base * RAY_INNER,
		])
		draw_colored_polygon(points, Color(_color, fade * 0.45))

	for ring: float in [0.42, 0.62, 0.88]:
		draw_arc(center, base * ring * progress, 0, TAU, 72, Color(_color, fade * 0.7), 1.5, true)
	draw_circle(center, base * 0.18 * progress, Color(_color, fade * 0.3))
