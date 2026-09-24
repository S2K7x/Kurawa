extends Control

## Tutoriel de première partie : quelques cartes qui expliquent les mécaniques, sans PNJ
## ni mise en scène (voir CLAUDE.md > Onboarding). Chaque étape peut désigner un onglet,
## que la coquille met en avant pendant l'explication.
## Texte : Data/tutorial.json.

signal step_changed(nav_name: String)
signal closed

@onready var _title: Label = %Title
@onready var _body: Label = %Body

var _steps: Array = []
var _index: int = 0

func _ready() -> void:
	%Panel.add_theme_stylebox_override("panel", Style.panel(Style.INK_DEEP, Style.GOLD_DIM, 3, 26))
	%NextButton.add_theme_stylebox_override("normal", Style.action_button(Style.CRIMSON, Style.GOLD_DIM))
	%NextButton.add_theme_stylebox_override("hover", Style.action_button(Style.CRIMSON_BRIGHT, Style.GOLD))
	%NextButton.pressed.connect(_advance)
	%SkipButton.pressed.connect(_finish)
	hide()

func start() -> void:
	_steps = DataLoader.load_json(DataLoader.TUTORIAL_PATH).get("steps", [])
	if _steps.is_empty():
		_finish()
		return
	_index = 0
	show()
	_apply()

func _apply() -> void:
	var step: Dictionary = _steps[_index]
	%Step.text = "%d / %d" % [_index + 1, _steps.size()]
	_title.text = str(step.get("title", "")).to_upper()
	_body.text = str(step.get("body", ""))
	%NextButton.text = "SUIVANT" if _index < _steps.size() - 1 else "COMMENCER"
	%SkipButton.visible = _index < _steps.size() - 1
	step_changed.emit(str(step.get("nav", "")))

func _advance() -> void:
	if _index >= _steps.size() - 1:
		_finish()
		return
	_index += 1
	_apply()

func _finish() -> void:
	hide()
	closed.emit()
