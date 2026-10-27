extends Node2D

var changing_scene := false


func _ready() -> void:
	$Control/NinePatchRect2/TouchButton.pressed.connect(start_game.bind(GameDifficulty.Level.EASY))
	$Control/NinePatchRect3/TouchButton.pressed.connect(start_game.bind(GameDifficulty.Level.MEDIUM))
	$Control/NinePatchRect4/TouchButton.pressed.connect(start_game.bind(GameDifficulty.Level.HARD))


func start_game(level: GameDifficulty.Level) -> void:
	if changing_scene:
		return
	changing_scene = true
	GameDifficulty.apply_level(level)
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/main.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("F"):
		var mode := DisplayServer.window_get_mode()
		var fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("R"):
		if not changing_scene:
			changing_scene = true
			get_tree().call_deferred("reload_current_scene")
		get_viewport().set_input_as_handled()
