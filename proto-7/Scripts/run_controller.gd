extends NinePatchRect

signal run_finished(outcome: String)

var active := false
var distance := 0.0
var goal := 1
var last_action := &""
var dive_remaining := 0.0
var slide_remaining := 0.0
var result := ""
var dived_base := -1
var step_remaining := 0.0
var display_start_distance := 0.0
var display_start_progress := 0.0
var runner: AnimatedSprite2D
@onready var lane: TextureRect = $TextureRect


func _ready() -> void:
	lane.clip_contents = true
	runner = AnimatedSprite2D.new()
	runner.name = "Runner"
	runner.sprite_frames = SpriteFrames.new()
	runner.sprite_frames.remove_animation("default")
	for spec in [
		["run", preload("res://Assets/Animations/runner_9.png"), 16.0, true],
		["dive", preload("res://Assets/Animations/runner_dive_4.png"), 20.0, false],
	]:
		runner.sprite_frames.add_animation(spec[0])
		runner.sprite_frames.set_animation_speed(spec[0], spec[2])
		runner.sprite_frames.set_animation_loop(spec[0], spec[3])
		for i in range(spec[1].get_width() / 36):
			var atlas := AtlasTexture.new()
			atlas.atlas = spec[1]
			atlas.region = Rect2(i * 36, 0, 36, 36)
			runner.sprite_frames.add_frame(spec[0], atlas)
	lane.add_child(runner)
	runner.animation = &"run"
	runner.hide()


func start_run(bases: int) -> void:
	active = true
	distance = 0.0
	goal = bases
	last_action = &""
	dive_remaining = 0.0
	slide_remaining = 0.0
	result = ""
	dived_base = -1
	step_remaining = 0.0
	display_start_distance = 0.0
	display_start_progress = 0.0
	runner.show()
	runner.animation = &"run"
	runner.set_frame_and_progress(0, 0.0)
	runner.pause()
	update_display()


func set_goal(bases: int) -> void:
	if not active or reached_base() or bases <= goal:
		return
	display_start_progress = display_progress()
	display_start_distance = distance
	goal = bases
	update_display()


func reached_base() -> bool:
	return distance >= goal


func finish_run(outcome: String) -> void:
	if not active:
		return
	active = false
	dive_remaining = 0.0
	slide_remaining = 0.0
	step_remaining = 0.0
	runner.pause()
	result = outcome
	run_finished.emit(outcome)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not active or reached_base() or dive_remaining > 0.0:
		return
	for action in [&"Left", &"Right"]:
		if event.is_action_pressed(action):
			if action != last_action:
				last_action = action
				# TouchScreenButton emits actions; keyboard input arrives as key events.
				var step_scale := GameDifficulty.run_touch_multiplier if event is InputEventAction else 1.0
				distance = minf(goal, distance + GameDifficulty.run_step * step_scale)
				step_remaining = 0.18
				runner.play("run")
				update_display()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("Space"):
		var base := int(distance)
		if dived_base != base:
			dived_base = base
			dive_remaining = GameDifficulty.dive_recovery_time
			slide_remaining = GameDifficulty.slide_time
			step_remaining = 0.0
			runner.play("dive")
			runner.set_frame_and_progress(0, 0.0)
			update_display()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if active and slide_remaining > 0.0:
		var movement := minf(delta, slide_remaining)
		distance = minf(mini(dived_base + 1, goal), distance + GameDifficulty.dive_distance * movement / GameDifficulty.slide_time)
		slide_remaining = maxf(0.0, slide_remaining - movement)
		update_display()
	dive_remaining = maxf(0.0, dive_remaining - delta)
	step_remaining = maxf(0.0, step_remaining - delta)
	if active and dive_remaining <= 0.0 and step_remaining <= 0.0:
		runner.pause()


func display_progress() -> float:
	var remaining := float(goal) - display_start_distance
	var progress := clampf((distance - display_start_distance) / remaining, 0.0, 1.0)
	return lerpf(display_start_progress, 1.0, progress)


func update_display() -> void:
	runner.position = Vector2(lane.size.x / 2.0, lerpf(lane.size.y - 20.0, 30.0, display_progress()))
