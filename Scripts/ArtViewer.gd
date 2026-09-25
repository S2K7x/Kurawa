extends Control

## Visionneuse plein écran : l'illustration sans cadre ni bandeau de carte, pour la regarder
## pour ce qu'elle est. Le bandeau d'information se masque d'une touche, et un glissement
## latéral passe au guerrier suivant de la collection.

signal closed

## Distance minimale d'un glissement pour changer de guerrier.
const SWIPE_THRESHOLD := 60.0

@onready var _art: TextureRect = %Art
@onready var _caption: VBoxContainer = %Caption
@onready var _shade: ColorRect = %Shade

var _player: PlayerManager
## Guerriers parcourables dans l'ordre où la galerie les affiche.
var _ids: Array = []
var _index: int = 0
var _drag_start: Vector2 = Vector2.ZERO

func setup(player: PlayerManager) -> void:
	_player = player

func _ready() -> void:
	%CloseButton.pressed.connect(_close)
	hide()

## `ids` : la liste affichée par l'appelant, pour que le glissement suive le même ordre.
func open(character_id: String, ids: Array = []) -> void:
	_ids = ids.duplicate() if not ids.is_empty() else [character_id]
	_index = maxi(_ids.find(character_id), 0)
	_apply()
	show()

func _apply() -> void:
	var character_id: String = _ids[_index]
	var data := _player.get_character_data(character_id)
	var artwork := DataLoader.character_art(data)
	_art.texture = artwork
	# Sans illustration, la visionneuse n'a rien à montrer : on n'ouvre pas une page noire.
	if artwork == null:
		_close()
		return
	%Name.text = str(data.get("name", ""))
	%Name.add_theme_color_override("font_color", DataLoader.rarity_color(str(data.get("rarity", "R"))))
	%Origin.text = "%s · %s · %s" % [data.get("rarity", ""), data.get("element", ""), data.get("origin", "")]
	var entry: Dictionary = _player.inventory.get(character_id, {})
	var stars: int = int(entry.get("stars", 1))
	%Stars.text = CharacterCard.FULL_STAR.repeat(stars) \
		+ CharacterCard.EMPTY_STAR.repeat(maxi(_player.progression.max_stars - stars, 0))
	%Stars.add_theme_color_override("font_color", Style.GOLD)
	%Hint.visible = _ids.size() > 1
	_set_caption_visible(true)

func _set_caption_visible(visible_caption: bool) -> void:
	_caption.visible = visible_caption
	_shade.visible = visible_caption

func _step(direction: int) -> void:
	if _ids.size() <= 1:
		return
	_index = wrapi(_index + direction, 0, _ids.size())
	_apply()

func _close() -> void:
	hide()
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			_drag_start = event.position
			return
		var drag: float = event.position.x - _drag_start.x
		if absf(drag) >= SWIPE_THRESHOLD:
			_step(-1 if drag > 0 else 1)
		else:
			# Touche sans glissement : on montre l'illustration seule.
			_set_caption_visible(not _caption.visible)
		accept_event()
