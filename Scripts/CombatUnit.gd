extends PanelContainer
class_name CombatUnit

## Vignette d'un combattant pendant un combat : portrait placeholder, PV, jauge ATB et
## altérations en cours. Purement de l'affichage : elle lit un Combatant, elle ne le modifie pas.

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

var unit: Combatant

var _atb_threshold: float = 1000.0
var _is_active: bool = false
var _is_targeted: bool = false

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
	# En combat la vignette est large et courte : l'illustration est recadrée sur le haut
	# du portrait plutôt que déformée.
	var artwork := DataLoader.character_art(DataLoader.character(unit.id))
	if artwork != null:
		_portrait.texture = _bust(artwork)
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_initials.hide()
	else:
		_portrait.texture = _portrait_texture(color)
		_portrait.stretch_mode = TextureRect.STRETCH_SCALE
		_initials.show()
		_initials.text = UiUtils.initials(unit.name)
	_name.text = unit.name
	_hp_bar.add_theme_stylebox_override("fill", _bar_style(Style.CRIMSON_BRIGHT if not unit.is_ally else Color("#4e9a63")))
	_atb_bar.add_theme_stylebox_override("fill", _bar_style(Style.GOLD_DIM))

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
	modulate = Color(1, 1, 1, 0.35) if not unit.is_alive() else Color.WHITE

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
	atlas.region = Rect2(0, 0, size.x, size.y * 0.45)
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
	var start := position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.6, 0.7, 0.7) if not critical else Color(2.0, 1.4, 0.6), 0.06)
	tween.chain().tween_property(self, "modulate", Color.WHITE, 0.18)
	var shake := create_tween()
	var amplitude := 9.0 if critical else 5.0
	shake.tween_property(self, "position", start + Vector2(amplitude, 0), 0.04)
	shake.tween_property(self, "position", start - Vector2(amplitude * 0.6, 0), 0.05)
	shake.tween_property(self, "position", start, 0.05)

## Soin reçu : un souffle vert, sans secousse.
func flash_heal() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.7, 1.5, 0.9), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(unit)
		accept_event()
