extends PanelContainer
class_name CharacterCard

## Carte de guerrier au format poster (ratio ~2:3, voir GDD.md > Format des cartes).
## Placeholder jusqu'à la Phase 4 : aplat de la couleur de l'élément, bordure de la rareté.
## Sert à la fois à la révélation d'invocation et à la galerie de la guilde.

signal pressed(character_id: String)

const FULL_STAR := "★"
const EMPTY_STAR := "☆"

@onready var _art: TextureRect = %Art
@onready var _initials: Label = %Initials
@onready var _rarity_label: Label = %RarityLabel
@onready var _stars_label: Label = %StarsLabel
@onready var _name_label: Label = %NameLabel
@onready var _sub_label: Label = %SubLabel

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

	add_theme_stylebox_override("panel", _frame_style(rarity_color))
	_art.texture = _art_placeholder(element_color)
	_initials.text = _initials_of(str(_character.get("name", "")))
	_rarity_label.text = rarity
	_rarity_label.add_theme_color_override("font_color", rarity_color)
	_name_label.text = str(_character.get("name", "???"))

	if _entry.is_empty():
		_stars_label.text = ""
		_sub_label.text = element
	else:
		var stars: int = int(_entry.get("stars", 1))
		_stars_label.text = FULL_STAR.repeat(stars) + EMPTY_STAR.repeat(maxi(_max_stars - stars, 0))
		_stars_label.add_theme_color_override("font_color", DataLoader.rarity_color("SSR"))
		_sub_label.text = "%s · Niv %d" % [element, int(_entry.get("level", 1))]

## Placeholder d'illustration jusqu'à la Phase 4 : dégradé vertical de la couleur de
## l'élément, surmonté des initiales du guerrier.
func _art_placeholder(element_color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, element_color.lightened(0.18))
	gradient.set_color(1, element_color.darkened(0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.2, 0.0)
	texture.fill_to = Vector2(0.8, 1.0)
	texture.width = 128
	texture.height = 192
	return texture

func _initials_of(character_name: String) -> String:
	var initials := ""
	for part: String in character_name.split(" ", false):
		initials += part.substr(0, 1).to_upper()
	return initials

func _frame_style(rarity_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.078, 0.153)
	style.set_border_width_all(3)
	style.border_color = rarity_color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	style.shadow_color = Color(rarity_color, 0.35)
	style.shadow_size = 6
	return style

func _gui_input(event: InputEvent) -> void:
	# Les événements tactiles sont convertis en clics souris par Godot : un seul chemin suffit
	# pour le desktop et le mobile (voir CLAUDE.md > Cibles d'export).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(character_id)
		accept_event()
