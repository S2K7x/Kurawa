extends PanelContainer
class_name CombatUnit

## Vignette d'un combattant pendant un combat : portrait, PV, jauge ATB et altérations en
## cours. Purement de l'affichage : elle lit un Combatant, elle ne le modifie pas.
##
## Elle s'anime sans le moindre asset supplémentaire (voir CLAUDE.md > Direction artistique :
## les illustrations restent statiques) : le cadrage respire, le cadre pulse au tour actif,
## et les coups reçus font blanchir puis tressauter la vignette.

signal selected(unit: Combatant)

## Libellés courts des altérations, pour tenir dans une vignette de 150 px.
const STATUS_LABELS := {
	"burn": "Brûlure", "stun": "Étourdi", "damage_reduction": "Garde",
	"atk_up": "ATK+", "speed_up": "VIT+", "dodge": "Esquive",
	"empower": "Arme ardente", "heal_per_turn": "Soin",
}

@onready var _portrait: TextureRect = %Portrait
@onready var _initials: Label = %Initials
@onready var _name: Label = %NameLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _atb_bar: ProgressBar = %AtbBar
@onready var _status: Label = %StatusLabel
@onready var _frame: OrnateFrame = %Frame

## Part de l'illustration gardée pour la vignette : le haut, là où se trouve le visage.
const BUST_RATIO := 0.45
## Respiration du cadrage : resserrement maximal et durée d'un aller-retour complet.
const IDLE_ZOOM := 0.93
const IDLE_PERIOD := 3.6
## Pulsation du cadre quand c'est au combattant d'agir.
const PULSE_PERIOD := 1.1

var unit: Combatant

var _atb_threshold: float = 1000.0
var _is_active: bool = false
var _is_targeted: bool = false

var _element_color: Color = Style.GOLD
## Fenêtre de cadrage animée (null tant que le guerrier n'a pas d'illustration).
var _bust_atlas: AtlasTexture = null
var _clock: float = 0.0
## Position au repos et secousse en cours : sans ça, deux coups d'une compétence
## multi-frappes se chevauchent et la vignette dérive hors de sa colonne.
var _rest_position: Vector2 = Vector2.ZERO
var _shake_tween: Tween = null

func bind(combatant: Combatant, atb_threshold: float) -> void:
	unit = combatant
	_atb_threshold = atb_threshold
	if is_node_ready():
		_build()
		refresh()

func _ready() -> void:
	if unit != null:
		_build()
		refresh()

func _build() -> void:
	var color := DataLoader.element_color(unit.element)
	_element_color = color
	# En combat la vignette est large et courte : l'illustration est recadrée sur le haut
	# du portrait plutôt que déformée.
	var artwork := _artwork()
	_bust_atlas = null
	if artwork != null:
		_bust_atlas = _bust(artwork)
		_portrait.texture = _bust_atlas
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_initials.hide()
		# Décalage déterministe tiré du nom : sans lui, toute l'équipe respire au même
		# rythme et l'écran se met à battre comme un seul bloc.
		_clock = IDLE_PERIOD * (float(absi(hash(unit.name)) % 1000) / 1000.0)
	else:
		_portrait.texture = _portrait_texture(color)
		_portrait.stretch_mode = TextureRect.STRETCH_SCALE
		_initials.show()
		_initials.text = UiUtils.initials(unit.name)
	_name.text = unit.name
	_hp_bar.add_theme_stylebox_override("fill", _bar_style(Style.CRIMSON_BRIGHT if not unit.is_ally else Color("#4e9a63")))
	_atb_bar.add_theme_stylebox_override("fill", _bar_style(Style.GOLD_DIM))
	_update_processing()

## Guerrier de la guilde ou adversaire : chaque camp a son catalogue et son dossier
## d'illustrations. Sans fichier, l'appelant retombe sur le placeholder d'élément.
func _artwork() -> Texture2D:
	if unit.is_ally:
		return DataLoader.character_art(DataLoader.character(unit.id))
	return DataLoader.enemy_art(DataLoader.enemy_or_empty(unit.id))

## Encadré : or quand c'est au combattant d'agir, cramoisi quand il est visé, sinon discret.
func set_highlight(active: bool, targeted: bool) -> void:
	_is_active = active
	_is_targeted = targeted
	refresh()

func refresh() -> void:
	if unit == null:
		return
	_hp_bar.max_value = unit.max_hp
	_hp_bar.value = unit.hp
	_hp_label.text = "%d / %d" % [unit.hp, unit.max_hp]
	_atb_bar.max_value = _atb_threshold
	_atb_bar.value = clampf(unit.atb, 0.0, _atb_threshold)

	var labels: PackedStringArray = []
	for status: Dictionary in unit.statuses:
		labels.append(str(STATUS_LABELS.get(status.get("type", ""), status.get("type", ""))))
	_status.text = " · ".join(labels)

	var border := Style.GOLD_DIM
	if _is_targeted:
		border = Style.CRIMSON_BRIGHT
	elif _is_active:
		border = Style.GOLD
	add_theme_stylebox_override("panel", _panel_style(border))
	_frame.bracket_color = border
	_frame.draw_outline = _is_active
	modulate = Color(1, 1, 1, 0.35) if not unit.is_alive() else Color.WHITE
	_update_processing()

# --- Animation ---------------------------------------------------------------------------------

## On n'anime que ce qui a quelque chose à animer : un mort ne respire plus, et une vignette
## sans illustration ni tour actif n'a aucune raison de consommer une image par frame.
func _update_processing() -> void:
	var alive := unit != null and unit.is_alive()
	set_process(alive and (_bust_atlas != null or _is_active))

func _process(delta: float) -> void:
	# Un décor animé ne redessine pas quand personne ne le regarde (CLAUDE.md > Profiler).
	if not is_visible_in_tree():
		return
	_clock += delta
	if _bust_atlas != null:
		_breathe()
	if _is_active:
		_pulse()

## Respiration : le cadrage se resserre très lentement vers le visage, puis se relâche.
## On déplace la fenêtre de l'AtlasTexture plutôt que l'échelle du TextureRect — une
## vignette mise à l'échelle déborderait sur ses voisines dans le conteneur.
func _breathe() -> void:
	var full := _bust_atlas.atlas.get_size()
	var framed := full.y * BUST_RATIO
	var wave := 0.5 - 0.5 * cos(TAU * _clock / IDLE_PERIOD)
	var zoom := lerpf(1.0, IDLE_ZOOM, wave)
	var w := full.x * zoom
	var h := framed * zoom
	_bust_atlas.region = Rect2((full.x - w) * 0.5, (framed - h) * 0.6, w, h)

## Tour actif : les équerres virent vers la couleur de l'élément et le liseré respire,
## pour que l'œil trouve tout de suite qui doit jouer.
func _pulse() -> void:
	var wave := 0.5 + 0.5 * sin(TAU * _clock / PULSE_PERIOD)
	_frame.bracket_color = Style.GOLD.lerp(_element_color.lightened(0.25), wave * 0.75)
	_frame.line_color = Color(_element_color, 0.18 + 0.32 * wave)

func _panel_style(border: Color) -> StyleBoxFlat:
	var style := Style.panel(Color(Style.SURFACE, 0.85), border, 3, 6)
	style.set_border_width_all(2 if _is_active or _is_targeted else 1)
	return style

func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style

## La vignette de combat est large et courte : un recadrage centré couperait la tête.
## On ne garde que le haut de l'illustration, là où se trouve le visage.
func _bust(artwork: Texture2D) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = artwork
	var size := artwork.get_size()
	atlas.region = Rect2(0, 0, size.x, size.y * BUST_RATIO)
	return atlas

func _portrait_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([color.darkened(0.3), color.darkened(0.8)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.3, 0.0)
	texture.fill_to = Vector2(0.7, 1.0)
	texture.width = 96
	texture.height = 64
	return texture


## Encaisse un coup à l'écran : la vignette blanchit et tressaute brièvement.
## Purement cosmétique — les PV, eux, ont déjà été retirés par le moteur.
func flash_damage(critical: bool = false) -> void:
	# Une compétence à plusieurs frappes rappelle ceci avant la fin de la secousse
	# précédente : on repart toujours du repos, sinon la vignette dérive coup après coup.
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()
		position = _rest_position
	else:
		_rest_position = position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.6, 0.7, 0.7) if not critical else Color(2.0, 1.4, 0.6), 0.06)
	tween.chain().tween_property(self, "modulate", Color.WHITE, 0.18)
	_shake_tween = create_tween()
	var amplitude := 9.0 if critical else 5.0
	_shake_tween.tween_property(self, "position", _rest_position + Vector2(amplitude, 0), 0.04)
	_shake_tween.tween_property(self, "position", _rest_position - Vector2(amplitude * 0.6, 0), 0.05)
	_shake_tween.tween_property(self, "position", _rest_position, 0.05)

## Soin reçu : un souffle vert, sans secousse.
func flash_heal() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.7, 1.5, 0.9), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(unit)
		accept_event()
