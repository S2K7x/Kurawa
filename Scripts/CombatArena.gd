extends Control

## Écran de combat : pilote un CombatManager et le donne à voir.
## Le joueur joue chaque tour de ses guerriers (Attaquer / Compétence / Passer, cible au
## toucher), ou bascule en AUTO et laisse l'IA mener son équipe — pratique pour farmer
## un donjon déjà maîtrisé (voir GDD.md > Structure du contenu PvE).
## Toute la règle du jeu vit dans CombatManager : cet écran ne fait qu'ordonner et afficher.

signal finished(victory: bool)

const UNIT_SCENE := preload("res://Scenes/CombatUnit.tscn")

## Respiration entre deux actions, pour que le combat reste lisible. Mise à 0 dans les tests.
var step_delay: float = 0.55

@onready var _enemy_row: HBoxContainer = %EnemyRow
@onready var _ally_row: HBoxContainer = %AllyRow
@onready var _log: RichTextLabel = %Log
@onready var _actor_label: Label = %ActorLabel
@onready var _actions: HBoxContainer = %Actions
@onready var _result: Control = %Result

var _player: PlayerManager
var _combat: CombatManager
var _encounter: Dictionary = {}
var _team_ids: Array = []
var _widgets: Dictionary = {} # Combatant -> CombatUnit
var _current_actor: Combatant
var _target: Combatant
var _logged_events: int = 0
var _running: bool = false
var _auto: bool = false

func setup(player: PlayerManager) -> void:
	_player = player

func _ready() -> void:
	%LogPanel.add_theme_stylebox_override("panel", Style.panel(Color(Style.INK_DEEP, 0.72), Style.GOLD_DIM, 3, 14))
	%AttackButton.pressed.connect(_on_attack)
	%SkillButton.pressed.connect(_on_skill)
	%PassButton.pressed.connect(_on_pass)
	%AutoButton.toggled.connect(_on_auto_toggled)
	%FleeButton.pressed.connect(_on_flee)
	%ContinueButton.pressed.connect(_on_continue)
	%ContinueButton.add_theme_stylebox_override("normal", Style.action_button(Style.CRIMSON, Style.GOLD_DIM))
	%ContinueButton.add_theme_stylebox_override("hover", Style.action_button(Style.CRIMSON_BRIGHT, Style.GOLD))
	# Le panneau de fin doit être franchement opaque : il conclut, il ne se superpose pas.
	%Panel.add_theme_stylebox_override("panel", Style.panel(Style.INK_DEEP, Style.GOLD_DIM, 3, 26))
	_set_actions_enabled(false)
	hide()

## `encounter` : {"title", "enemies", "chapter_id", "battle_index", "or_multiplier", "xp_multiplier"}.
func begin(encounter: Dictionary, team_ids: Array) -> void:
	_encounter = encounter
	_team_ids = team_ids
	_result.hide()
	_log.text = ""
	_logged_events = 0
	_auto = false
	%AutoButton.button_pressed = false
	%Title.text = str(encounter.get("title", "COMBAT")).to_upper()

	_combat = CombatManager.new()
	var team: Array[Combatant] = []
	for character_id: String in team_ids:
		team.append(CombatManager.from_character(
			_player.get_character_data(character_id),
			_player.get_character_stats(character_id),
			_player.get_character_skill(character_id)))
	var foes: Array[Combatant] = []
	for entry: Dictionary in encounter.get("enemies", []):
		foes.append(CombatManager.from_enemy(str(entry.get("id", "")), int(entry.get("level", 1))))
	_combat.start(team, foes)

	_build_row(_ally_row, team)
	_build_row(_enemy_row, foes)
	_target = foes[0] if not foes.is_empty() else null
	show()
	_running = true
	_advance()

func _build_row(row: HBoxContainer, units: Array[Combatant]) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for unit: Combatant in units:
		var widget: CombatUnit = UNIT_SCENE.instantiate()
		row.add_child(widget)
		widget.bind(unit, _combat._atb_threshold)
		widget.selected.connect(_on_unit_selected)
		_widgets[unit] = widget

# --- Boucle de combat --------------------------------------------------------------------------

## Fait avancer le combat jusqu'à ce qu'un guerrier du joueur ait la main (ou jusqu'à la fin).
func _advance() -> void:
	while _running:
		if _combat.is_over():
			_finish()
			return
		_current_actor = _combat.begin_turn()
		_flush()
		if _current_actor == null:
			if step_delay > 0.0:
				await get_tree().create_timer(step_delay).timeout
			continue
		if _current_actor.is_ally and not _auto:
			_prompt_player()
			return
		if step_delay > 0.0:
			await get_tree().create_timer(step_delay).timeout
		if not _running:
			return
		_combat.act_ai(_current_actor)
		_flush()
		if step_delay > 0.0:
			await get_tree().create_timer(step_delay).timeout

func _prompt_player() -> void:
	_actor_label.text = "AU TOUR DE %s" % _current_actor.name.to_upper()
	%SkillButton.disabled = _current_actor.skill_cooldown > 0
	%SkillButton.text = "COMPÉTENCE" if _current_actor.skill_cooldown == 0 \
		else "COMPÉTENCE (%d)" % _current_actor.skill_cooldown
	if _target == null or not _target.is_alive():
		var living := _combat._living(_combat.enemies)
		_target = null if living.is_empty() else living[0]
	_set_actions_enabled(true)
	_refresh_widgets()

func _play(action: String) -> void:
	if _current_actor == null:
		return
	_set_actions_enabled(false)
	_combat.act(_current_actor, action, _target)
	_current_actor = null
	_flush()
	if step_delay > 0.0:
		await get_tree().create_timer(step_delay).timeout
	_advance()

func _on_attack() -> void:
	_play("attack")

func _on_skill() -> void:
	_play("skill")

func _on_pass() -> void:
	_play("pass")

func _on_auto_toggled(pressed: bool) -> void:
	_auto = pressed
	# Si on bascule en auto alors que le joueur avait la main, l'IA reprend le tour en cours.
	if _auto and _current_actor != null and _current_actor.is_ally:
		_set_actions_enabled(false)
		var actor := _current_actor
		_current_actor = null
		_combat.act_ai(actor)
		_flush()
		_advance()

func _on_flee() -> void:
	_running = false
	_show_result(false, {})

func _on_unit_selected(unit: Combatant) -> void:
	if unit.is_ally or not unit.is_alive():
		return
	_target = unit
	_refresh_widgets()

# --- Affichage ---------------------------------------------------------------------------------

func _flush() -> void:
	%TurnLabel.text = "TOUR %d" % _combat.turn_count
	while _logged_events < _combat.events.size():
		var line := _describe(_combat.events[_logged_events])
		if line != "":
			_log.append_text(line + "\n")
		_logged_events += 1
	_refresh_widgets()

func _refresh_widgets() -> void:
	for unit: Combatant in _widgets:
		var widget: CombatUnit = _widgets[unit]
		widget.set_highlight(unit == _current_actor, unit == _target and unit.is_alive())

func _set_actions_enabled(enabled: bool) -> void:
	for button: Button in _actions.get_children():
		button.disabled = not enabled
	if not enabled:
		_actor_label.text = " "

## Traduit un événement du moteur en une ligne de journal lisible.
func _describe(event: Dictionary) -> String:
	var actor := str(event.get("actor", ""))
	match str(event.get("kind", "")):
		"combat_start":
			return "[color=#96887e]Le combat commence.[/color]"
		"attack":
			return "%s frappe %s — [b]%d[/b]" % [actor, event.get("target", ""), int(event.get("damage", 0))]
		"skill":
			return "[color=#e3d3a8]%s — %s[/color] sur %s — [b]%d[/b]" % [actor, event.get("skill", ""),
				", ".join(event.get("targets", [])), int(event.get("damage", 0))]
		"critical":
			return "[color=#d8263a]Coup critique sur %s ![/color]" % event.get("target", "")
		"burn":
			return "[color=#e8552e]%s brûle (-%d)[/color]" % [actor, int(event.get("damage", 0))]
		"heal":
			return "[color=#4e9a63]%s récupère %d PV[/color]" % [actor, int(event.get("amount", 0))]
		"stunned":
			return "[color=#96887e]%s est étourdi et passe son tour[/color]" % actor
		"dodge":
			return "[color=#96887e]%s esquive[/color]" % actor
		"charge":
			return "[color=#e3d3a8]%s prépare %s…[/color]" % [actor, event.get("skill", "")]
		"extra_turn":
			return "[color=#e3d3a8]%s enchaîne immédiatement[/color]" % actor
		"defeated":
			return "[color=#d8263a]%s tombe.[/color]" % actor
		"pass":
			return "[color=#96887e]%s passe son tour[/color]" % actor
		_:
			return ""

# --- Fin de combat -----------------------------------------------------------------------------

func _finish() -> void:
	_running = false
	_set_actions_enabled(false)
	var victory := _combat.result() == CombatManager.Result.VICTORY
	var granted := {}
	if victory:
		granted = _player.grant_victory(_team_ids,
			ContentLibrary.battle_rewards(_encounter.get("enemies", []),
				float(_encounter.get("or_multiplier", 1.0)), float(_encounter.get("xp_multiplier", 1.0))),
			str(_encounter.get("chapter_id", "")), int(_encounter.get("battle_index", -1)))
	else:
		_player.record_defeat(_team_ids)
	_show_result(victory, granted)

func _show_result(victory: bool, granted: Dictionary) -> void:
	%ResultTitle.text = "VICTOIRE" if victory else "DÉFAITE"
	%ResultTitle.add_theme_color_override("font_color", Style.GOLD if victory else Style.CRIMSON_BRIGHT)

	var lines: PackedStringArray = []
	if victory:
		lines.append("⬢ [b]%d[/b] Or de guilde" % int(granted.get("or", 0)))
		lines.append("✦ [b]%d[/b] XP pour chaque guerrier engagé" % int(granted.get("xp", 0)))
		for character_id: String in granted.get("level_ups", {}):
			lines.append("[color=#e3d3a8]%s passe %d niveau(x)[/color]" % [
				_player.get_character_data(character_id).get("name", "?"),
				int(granted["level_ups"][character_id])])
		var first_clear: Dictionary = granted.get("first_clear", {})
		if not first_clear.is_empty():
			lines.append("")
			lines.append("[color=#e3d3a8][b]CHAPITRE BOUCLÉ[/b][/color]")
			lines.append("◈ [b]%d[/b] Éclats Dimensionnels" % int(first_clear.get("eclats_dimensionnels", 0)))
			lines.append("⬢ [b]%d[/b] Or de guilde" % int(first_clear.get("or_de_guilde", 0)))
	else:
		lines.append("[color=#96887e]L'énergie dépensée est perdue. Monte tes guerriers en donjon et reviens.[/color]")
	%ResultBody.text = "\n".join(lines)
	_result.show()

func _on_continue() -> void:
	_result.hide()
	hide()
	finished.emit(_combat != null and _combat.result() == CombatManager.Result.VICTORY)
