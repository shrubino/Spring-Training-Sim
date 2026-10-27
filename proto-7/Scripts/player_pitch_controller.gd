extends "res://Scripts/pitch_controller.gd"

@onready var selection: Label = $PitchSelect/Label
@onready var line: TextureRect = $PitchSlider/Line
@onready var slider: TextureRect = $PitchSlider/Slider
@onready var arrow: TextureRect = $PitchSlider/Arrow
var selected_pitch := 0
var ready_to_pitch := false
var charging := false
var meter_time := 0.0
var accuracy := 0.0
var opponent_resolved := false
var controls_hide_remaining := 0.0


func _ready() -> void:
	super._ready()
	slider.size = slider.texture.get_size()
	arrow.size = arrow.texture.get_size()
	select_pitch(0)


func select_pitch(step: int) -> void:
	controls_hide_remaining = 0.0
	$PitchSelect.show()
	$PitchSlider.show()
	selected_pitch = posmod(selected_pitch + step, GameDifficulty.pitch_profiles.size())
	selection.text = GameDifficulty.pitch_profiles[selected_pitch].name.to_upper()
	arrow.position.x = roundf(line.position.x + rng.randf_range(0.25, 0.75) * line.texture.get_width() - arrow.size.x / 2.0)
	meter_time = 0.0
	update_meter()


func update_meter() -> void:
	var progress := pingpong(meter_time * GameDifficulty.pitch_meter_speed, 1.0)
	slider.position.x = roundf(line.position.x + progress * (line.texture.get_width() - slider.size.x))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not ready_to_pitch or state != State.IDLE or get_parent().ball_in_play:
		return
	if not charging and event.is_action_pressed("Left"):
		select_pitch(-1)
	elif not charging and event.is_action_pressed("Right"):
		select_pitch(1)
	elif event.is_action_pressed("Space"):
		charging = true
	elif charging and event.is_action_released("Space"):
		charging = false
		ready_to_pitch = false
		var error := absf(slider.position.x + slider.size.x / 2.0 - arrow.position.x - arrow.size.x / 2.0)
		accuracy = pow(1.0 - clampf(error / (line.texture.get_width() * 0.5), 0.0, 1.0), GameDifficulty.pitch_accuracy_exponent)
		controls_hide_remaining = 0.08
		opponent_resolved = false
		start_pitch(selected_pitch, accuracy)
		pitch_is_ball = rng.randf() < lerpf(GameDifficulty.player_pitch_ball_chance.x, GameDifficulty.player_pitch_ball_chance.y, accuracy)
		break_offset = (14.0 if rng.randf() < 0.5 else -14.0) if pitch_is_ball else 0.0


func swing() -> void:
	pass


func _on_batter_frame_changed() -> void:
	pass


func _process(delta: float) -> void:
	if controls_hide_remaining > 0.0:
		controls_hide_remaining = maxf(0.0, controls_hide_remaining - delta)
		if controls_hide_remaining == 0.0:
			$PitchSelect.hide()
			$PitchSlider.hide()
	if charging:
		meter_time += delta
		update_meter()
	if state == State.FLIGHT and not opponent_resolved:
		var next_time := flight_elapsed + delta * GameDifficulty.game_speed * playback_speed
		if next_time >= flight_duration - CONTACT_FRAME / 20.0:
			if not pitch_is_ball and batter.animation != &"swing":
				batter.play("swing")
		if next_time >= flight_duration:
			opponent_resolved = true
			flight_elapsed = flight_duration
			ball.position = plate_position + Vector2(0, break_offset)
			if not pitch_is_ball and rng.randf() < lerpf(GameDifficulty.opponent_contact_chance.x, GameDifficulty.opponent_contact_chance.y, accuracy):
				var power := rng.randf()
				var bases := 1
				if power >= lerpf(GameDifficulty.opponent_triple_cutoff.x, GameDifficulty.opponent_triple_cutoff.y, accuracy):
					bases = 4
				elif power >= lerpf(GameDifficulty.opponent_double_cutoff.x, GameDifficulty.opponent_double_cutoff.y, accuracy):
					bases = 3
				elif power >= lerpf(GameDifficulty.opponent_single_cutoff.x, GameDifficulty.opponent_single_cutoff.y, accuracy):
					bases = 2
				finish_pitch(bases)
			else:
				swung_at_pitch = not pitch_is_ball
				finish_pitch(0)
			return
	super._process(delta)
