extends SceneTree

## Outil de relecture visuelle : monte Main.tscn, capture chaque écran en PNG puis quitte.
## Doit tourner avec un vrai rendu (pas --headless) :
##   godot --path . --resolution 720x1280 -s res://Tests/capture_screens.gd -- <dossier_sortie>

const SAVE_PATH := "user://capture_kurawa_save.json"

var _main: Node
var _frames: int = 0
var _shots: Array[String] = []
var _out_dir: String = "user://captures"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_main = load("res://Scenes/Main.tscn").instantiate()
	_main.player.save_path = SAVE_PATH
	root.add_child(_main)
	_main.player.reset_save()
	_main.player.add_eclats(3000)

func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		4:
			_shot("01_breche")
		6:
			var results: Array = _main.player.summon(true)
			_main.get_node("%ScreenHost").get_child(0)._reveal.start(results)
		70:
			_shot("02_revelation")
		72:
			_main.get_node("%ScreenHost").get_child(0)._reveal._show_summary()
		80:
			_shot("03_recap_x10")
			_main.get_node("%ScreenHost").get_child(0)._reveal._close()
			_main.get_node("%GuildNav").button_pressed = true
			_main._show(_main.get_node("%ScreenHost").get_child(1))
		86:
			_shot("04_guilde")
			var inventory: Node = _main.get_node("%ScreenHost").get_child(1)
			var grid: GridContainer = inventory.get_node("%Grid")
			if grid.get_child_count() > 0:
				inventory._show_detail(grid.get_child(0).character_id)
		92:
			_shot("05_fiche")
		98:
			print("\n".join(_shots))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			quit(0)
			return true
	return false

func _shot(name: String) -> void:
	var path := "%s/%s.png" % [_out_dir, name]
	var image := root.get_texture().get_image()
	image.save_png(path)
	_shots.append(path)
