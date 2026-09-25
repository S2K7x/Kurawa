extends Control
class_name GuildCrest

## Blason de la guilde : sceau héraldique dessiné à la main, sans aucune texture à produire
## (même parti pris que BreachPortal et SigilBackground — voir CLAUDE.md > Langage visuel).
## Sert de logo sur l'écran d'accueil, à côté du mot KURAWA composé en Cinzel : les IA
## d'illustration massacrent le texte, la typo reste donc du ressort du moteur.
##
## Si une illustration d'emblème est déposée dans `Assets/UI/crest.png` (ou .webp/.jpg),
## elle remplace le dessin — le blason généré et le blason dessiné cohabitent, comme les
## illustrations de guerriers et leurs placeholders.

const CREST_PATH_BASE := "res://Assets/UI/crest"
const CREST_EXTENSIONS: Array[String] = ["png", "webp", "jpg"]

## Anneau extérieur, graduations, anneau intérieur : proportions du sceau.
const RING_OUTER := 0.94
const RING_INNER := 0.78
const TICK_COUNT := 24

@export var ring_color: Color = Style.GOLD
@export var accent_color: Color = Style.CRIMSON_BRIGHT
## Un blason plus discret sur fond chargé : tout le dessin est multiplié par cette opacité.
@export_range(0.0, 1.0) var strength: float = 1.0:
	set(value):
		strength = value
		queue_redraw()

var _texture: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_texture = _load_crest()

## Illustration d'emblème déposée par l'auteur, ou null pour retomber sur le dessin.
## Résolu une seule fois : le blason ne change pas en cours de session.
func _load_crest() -> Texture2D:
	for extension: String in CREST_EXTENSIONS:
		var path := "%s.%s" % [CREST_PATH_BASE, extension]
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _draw() -> void:
	var center := size / 2.0
	var radius: float = minf(size.x, size.y) * 0.5
	if radius <= 1.0:
		return
	if _texture != null:
		_draw_texture_crest(center, radius)
		return
	_draw_seal(center, radius)

## Emblème généré : posé au carré, centré, sans déformation.
func _draw_texture_crest(center: Vector2, radius: float) -> void:
	var side := radius * 2.0
	draw_texture_rect(_texture, Rect2(center - Vector2.ONE * radius, Vector2(side, side)),
		false, Color(1, 1, 1, strength))

## Le sceau dessiné : deux anneaux gradués, une fente cramoisie, et le chevron de la
## guilde. Volontairement **différent** de BreachPortal : le portail est un disque runique
## qui tourne, le blason est une marque héraldique fixe. Deux arcs de part et d'autre de
## la fente suffiraient à le faire lire comme un œil — d'où le chevron plutôt que des arcs.
func _draw_seal(center: Vector2, radius: float) -> void:
	var outer := radius * RING_OUTER
	var inner := radius * RING_INNER

	draw_arc(center, outer, 0, TAU, 96, Color(ring_color, 0.85 * strength), 1.5, true)
	draw_arc(center, inner, 0, TAU, 72, Color(ring_color, 0.4 * strength), 1.0, true)

	# Graduations entre les deux anneaux, une sur quatre plus longue : la lecture « sceau
	# gravé » tient à cette irrégularité régulière.
	for i in range(TICK_COUNT):
		var direction := Vector2.from_angle(TAU * i / TICK_COUNT - PI / 2.0)
		var depth: float = 1.0 if i % 4 == 0 else 0.45
		draw_line(center + direction * outer,
			center + direction * lerpf(outer, inner, depth),
			Color(ring_color, (0.6 if i % 4 == 0 else 0.35) * strength), 1.0, true)

	# La fente, fine, passe derrière les chevrons : une fissure, pas une pupille.
	_draw_rift(center, inner * 0.86)

	# Le double chevron de la guilde, en or, tombant vers la Brèche. C'est LA forme qui
	# doit survivre à 24 px (icône, coin d'interface) : deux traits, rien d'autre.
	var stroke: float = maxf(radius * 0.014, 1.5)
	_draw_chevron(center, inner, 0.62, -0.46, Color(ring_color, 0.95 * strength), stroke)
	_draw_chevron(center, inner, 0.62, 0.02, Color(ring_color, 0.72 * strength), stroke)

	# Losanges cardinaux : les quatre éléments, sans couleur pour ne pas en privilégier un.
	for i in range(4):
		var direction := Vector2.from_angle(TAU * i / 4.0 - PI / 2.0)
		Style.draw_diamond(self, center + direction * outer, maxf(radius * 0.09, 2.5),
			Color(Style.INK_DEEP, 0.95 * strength), Color(ring_color, 0.8 * strength))

## Angle de chute du chevron : profondeur de la pointe, en fraction du rayon intérieur.
## Constante pour que les deux chevrons restent parallèles.
const CHEVRON_DROP := 0.36

## Un V ouvert vers le haut. `half_width` et `top` sont des fractions du rayon intérieur.
func _draw_chevron(center: Vector2, inner: float, half_width: float, top: float,
		color: Color, width: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(-inner * half_width, inner * top),
		center + Vector2(0.0, inner * (top + CHEVRON_DROP)),
		center + Vector2(inner * half_width, inner * top),
	])
	draw_polyline(points, color, width, true)

## La déchirure au cœur du blason : une fente de lumière, reprise en plus sobre du
## motif de BreachPortal pour que l'écran d'accueil et l'invocation parlent la même langue.
func _draw_rift(center: Vector2, half_height: float) -> void:
	var width: float = half_height * 0.035
	for layer: int in range(2):
		var scale: float = 1.0 + layer * 1.2
		var alpha: float = (0.95 - layer * 0.55) * strength
		var color: Color = Color(1, 0.94, 0.88, alpha) if layer == 0 else Color(accent_color, alpha)
		var lens := PackedVector2Array()
		var steps := 20
		for i in range(steps + 1):
			var t := float(i) / steps
			lens.append(center + Vector2(width * scale * (1.0 - pow(2.0 * t - 1.0, 2)),
				lerpf(-half_height, half_height, t)))
		for i in range(steps + 1):
			var t := 1.0 - float(i) / steps
			lens.append(center + Vector2(-width * scale * (1.0 - pow(2.0 * t - 1.0, 2)),
				lerpf(-half_height, half_height, t)))
		draw_colored_polygon(lens, color)
