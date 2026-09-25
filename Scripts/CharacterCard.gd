extends PanelContainer
class_name CharacterCard

## Carte de guerrier au format poster (ratio ~2:3, voir GDD.md > Format des cartes),
## habillée comme une carte TCG : double liseré de rareté, badges de rareté et d'élément,
## bandeau de nom gravé (référence : Design-Style/).
## Placeholder d'illustration jusqu'à la Phase 4 : dégradé de l'élément + initiales.
## Sert à la fois à la révélation d'invocation et à la galerie de la guilde.

signal pressed(character_id: String)

const FULL_STAR := "★"
const EMPTY_STAR := "☆"

@onready var _art: TextureRect = %Art
@onready var _initials: Label = %Initials
@onready var _rarity_label: Label = %RarityLabel
@onready var _element_label: Label = %ElementLabel
@onready var _stars_label: Label = %StarsLabel
@onready var _name_label: Label = %NameLabel
@onready var _sub_label: Label = %SubLabel
@onready var _frame: OrnateFrame = %Frame

var character_id: String = ""

var _character: Dictionary = {}
var _entry: Dictionary = {}
var _max_stars: int = 6
var _pending_display := false

## `entry` est une entrée d'inventaire ({"level", "stars", "xp"}) ; vide pour une carte
## non possédée (révélation d'un nouveau guerrier).
func display(character: Dictionary, entry: Dictionary = {}, max_stars: int = 6) -> void:
	_character = character
	_entry = entry
	_max_stars = max_stars
	character_id = str(character.get("id", ""))
	if is_node_ready():
		_apply()
	else:
		_pending_display = true

func _ready() -> void:
	if _pending_display:
		_apply()

func _apply() -> void:
	_pending_display = false
	var rarity := str(_character.get("rarity", "R"))
	var element := str(_character.get("element", ""))
	var rarity_color := DataLoader.rarity_color(rarity)
	var element_color := DataLoader.element_color(element)

	add_theme_stylebox_override("panel", _card_style(rarity_color))
	_frame.line_color = Color(rarity_color, 0.5)
	_frame.bracket_color = rarity_color

	# Vraie illustration si elle existe, placeholder sinon : les deux cohabitent le temps
	# que le roster soit illustré (voir CLAUDE.md > Ajouter une illustration).
	var artwork := DataLoader.character_art(_character)
	if artwork != null:
		_art.texture = artwork
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_initials.hide()
	else:
		_art.texture = _art_placeholder(element_color)
		_art.stretch_mode = TextureRect.STRETCH_SCALE
		_initials.show()
		_initials.text = UiUtils.initials(str(_character.get("name", "")))
	_name_label.text = str(_character.get("name", "???"))

	_rarity_label.text = rarity
	_rarity_label.add_theme_color_override("font_color", rarity_color)
	_rarity_label.add_theme_stylebox_override("normal", _badge_style(rarity_color))
	_element_label.text = element
	_element_label.add_theme_color_override("font_color", element_color.lightened(0.35))
	_element_label.add_theme_stylebox_override("normal", _badge_style(element_color))

	if _entry.is_empty():
		_stars_label.text = ""
		_sub_label.text = str(_character.get("origin", element))
	else:
		var stars: int = int(_entry.get("stars", 1))
		_stars_label.text = FULL_STAR.repeat(stars) + EMPTY_STAR.repeat(maxi(_max_stars - stars, 0))
		_stars_label.add_theme_color_override("font_color", Style.GOLD)
		_sub_label.text = "%s · Niv %d" % [element, int(_entry.get("level", 1))]

## Corps de la carte : fond d'encre, liseré de la rareté et halo discret de la même teinte.
func _card_style(rarity_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Style.INK_DEEP
	style.set_border_width_all(2)
	style.border_color = rarity_color
	style.set_corner_radius_all(3)
	style.set_content_margin_all(5)
	style.shadow_color = Color(rarity_color, 0.28)
	style.shadow_size = 8
	return style

## Pastille sombre derrière un badge, cerclée de la couleur qu'elle annonce.
func _badge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# Les badges se posent maintenant sur de vraies illustrations, parfois très claires :
	# la pastille doit rester franchement opaque pour que la lettre reste lisible.
	style.bg_color = Color(Style.INK_DEEP, 0.92)
	style.set_border_width_all(1)
	style.border_color = Color(color, 0.85)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

## Placeholder d'illustration jusqu'à la Phase 4 : dégradé vertical de la couleur de
## l'élément, assombri vers le bas pour que le bandeau de nom reste lisible.
func _art_placeholder(element_color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		element_color.darkened(0.18),
		element_color.darkened(0.52),
		element_color.darkened(0.85),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.25, 0.0)
	texture.fill_to = Vector2(0.75, 1.0)
	texture.width = 128
	texture.height = 192
	return texture


func _gui_input(event: InputEvent) -> void:
	# Les événements tactiles sont convertis en clics souris par Godot : un seul chemin suffit
	# pour le desktop et le mobile (voir CLAUDE.md > Cibles d'export).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(character_id)
		accept_event()
