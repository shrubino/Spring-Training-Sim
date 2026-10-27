extends Node2D

signal runs_scored(runs: int)
signal strikeout

enum Phase { BATTING, FIELDING }
const INNINGS_PER_GAME := 3
const BASE_EMPTY = preload("res://Assets/UI/base_empty.png")
const BASE_FULL = preload("res://Assets/UI/base_full.png")
const OUT_EMPTY = preload("res://Assets/UI/out_empty.png")
const OUT_FULL = preload("res://Assets/UI/out_full.png")
var game_over := false
var restarting := false
var phase := Phase.BATTING
var ball_in_play := false
var play_phase := Phase.BATTING
var hit_slowmo_remaining := 0.0
var pitch_queue_revision := 0
var field_target_x := 0.0
var field_tween: Tween
var inning := 1
var inning_scores: Array[Vector2i] = [Vector2i.ZERO]
var player_score := 0
var opponent_score := 0
var strikes := 0
var balls := 0
var outs := 0
var bases: Array[bool] = [false, false, false]

@onready var pitching_box = $Batting
@onready var player_pitching = $Pitching
@onready var catching = $Catching
@onready var passing = $Passing
@onready var field_left_x: float = $Field.position.x
@onready var field_right_x: float = $Catching.position.x + $Catching.size.x - $Field.size.x
@onready var run_box = $Run
@onready var away_scores: Array[Label] = [$Score/Box/AwayScore1, $Score/Box/AwayScore2, $Score/Box/AwayScore3]
@onready var home_scores: Array[Label] = [$Score/Box/HomeScore1, $Score/Box/HomeScore2, $Score/Box/HomeScore3]
@onready var score_arrow: TextureRect = $Score/Box/Arrow
@onready var score_arrow_top: Vector2 = score_arrow.position
@onready var innings_label: Label = $Score/Box/InningsLabel
@onready var count_label: Label = $"Score/Box/Control/Balls + Strikes"
@onready var base_icons: Array = [$Score/Box/Control/Base1, $Score/Box/Control/Base2, $Score/Box/Control/Base3]
@onready var out_icons: Array = [$Score/Box/Control/Out1,$Score/Box/Control/Out2 , $Score/Box/Control/Out3]
@onready var field_view = $Field/TextureRect
@onready var phase_status: Label = $PhaseStatus
@onready var shot_call: Label = $"Shot Call/Label"
@onready var announcements = $"Shot Call"


func _ready() -> void:
	$RestartButton.show()
	$FullscreenButton.show()
	field_target_x = field_right_x
	$Field.position.x = field_target_x
	field_view.pitch_controller = pitching_box
	field_view.run_controller = $Run
	field_view.catch_controller = catching
	catching.resolved.connect(_on_player_catch)
	field_view.pass_requested.connect(_on_pass_requested)
	passing.throw_released.connect(_on_pass_released)
	run_box.run_finished.connect(_on_run_finished)
	for controller in [pitching_box, player_pitching]:
		controller.pitch_selected.connect(func(pitch_name: String): announcements.announce(AnnouncementText.pitch(pitch_name)))
		controller.pitch_started.connect(field_view.start_pitch)
		controller.pitch_released.connect(field_view.release_pitch)
		controller.ball_contact.connect(_on_ball_contact)
		controller.pitch_finished.connect(_on_pitch_finished)
	field_view.home_run.connect(func(): announcements.announce(AnnouncementText.HOME_RUN, Vector2(240, 132), 0.12))
	field_view.play_finished.connect(_on_field_play_finished)
	field_view.sync_runners(bases)
	update_display()
	announce_inning()
	queue_pitch()


func announce_inning() -> void:
	announcements.announce(AnnouncementText.inning(inning, phase == Phase.BATTING))


func queue_pitch() -> void:
	if game_over:
		return
	pitch_queue_revision += 1
	var request := pitch_queue_revision
	player_pitching.ready_to_pitch = false
	if ball_in_play:
		await get_tree().create_timer(1.0).timeout
	if request != pitch_queue_revision:
		return
	if outs == 3:
		outs = 0
		announce_inning()
	ball_in_play = false
	catching.stop()
	passing.stop()
	update_display()
	await get_tree().create_timer(1.5).timeout
	if request == pitch_queue_revision and not ball_in_play:
		if phase == Phase.BATTING:
			pitching_box.start_pitch()
		else:
			player_pitching.select_pitch(0)
			player_pitching.ready_to_pitch = true


func active_pitch():
	return pitching_box if phase == Phase.BATTING else player_pitching


func _on_ball_contact(play: RefCounted) -> void:
	if game_over:
		return
	play_phase = phase
	ball_in_play = true
	hit_slowmo_remaining = 0.5
	set_hit_speed(0.4)
	field_view.start_hit(play)
	announcements.announce_hit(play.hit_bases, play.grounder)
	update_display()


func _on_player_catch(clean: bool, fumbled: bool) -> void:
	field_view.resolve_player_catch(clean, fumbled, catching.great_catch)
	if field_view.caught and catching.great_catch:
		announcements.announce(AnnouncementText.GREAT_CATCH)
	elif clean and passing.started:
		announcements.announce(AnnouncementText.GREAT_PICKUP if catching.great_catch else AnnouncementText.throw_to_base(field_view.play.hit_bases))
	elif clean:
		announcements.announce(AnnouncementText.CAUGHT if field_view.caught else AnnouncementText.GATHERED)
	else:
		announcements.announce(AnnouncementText.FUMBLE if fumbled else AnnouncementText.MISSED_CATCH)
	if clean:
		catching.stop()
		update_display()


func _on_pass_requested() -> void:
	passing.start_pass()
	announcements.announce(AnnouncementText.throw_to_base(field_view.play.hit_bases))
	update_display()


func _on_pass_released(missed: bool) -> void:
	field_view.begin_throw(int(missed))
	passing.launch_ball(field_view.throw_duration / GameDifficulty.field_speed)
	if missed:
		announcements.announce(AnnouncementText.THROW_ERROR)


func _on_pitch_finished(hit_bases: int) -> void:
	if game_over:
		return
	if hit_bases > 0:
		return
	field_view.finish_miss()
	var player_batting := phase == Phase.BATTING
	if active_pitch().fouled_pitch:
		strikes = mini(strikes + 1, 2)
		announcements.announce(AnnouncementText.FOUL)
	elif active_pitch().called_ball:
		record_ball()
		var walk_text: String = AnnouncementText.WALK if player_batting else AnnouncementText.OPPONENT_WALK
		announcements.announce(walk_text if balls == 0 else AnnouncementText.BALL)
	else:
		record_pitch(0)
		if game_over:
			return
		var out_text: String = AnnouncementText.STRIKEOUT if player_batting else AnnouncementText.OPPONENT_STRIKEOUT
		announcements.announce(out_text if strikes == 0 else AnnouncementText.STRIKE)
	field_view.sync_runners(bases)
	update_display()
	queue_pitch()


func _on_run_finished(outcome: String) -> void:
	if outcome == AnnouncementText.RUN_CAUGHT:
		announcements.announce(AnnouncementText.CAUGHT)
	elif outcome == AnnouncementText.RUN_THROWN_OUT:
		announcements.announce(AnnouncementText.TAGGED_OUT)


func _on_field_play_finished(play: RefCounted, caught: bool, runner_out: bool) -> void:
	if game_over:
		return
	if caught:
		strikes = 0
		record_out()
	elif runner_out:
		announcements.announce(AnnouncementText.TAGGED_OUT)
		strikes = 0
		if outs < 2:
			record_pitch(play.hit_bases, false)
		record_out()
	else:
		if play.hit_bases < 4 or field_view.throw_attempted:
			announcements.announce(AnnouncementText.SAFE, Vector2(216, 108), 0.12)
		record_pitch(play.hit_bases)
	if game_over:
		return
	field_view.sync_runners(bases)
	update_display()
	queue_pitch()


func record_out() -> void:
	if game_over:
		return
	balls = 0
	strikes = 0
	outs += 1
	if outs == 3:
		bases.fill(false)
		if phase == Phase.FIELDING:
			if inning >= INNINGS_PER_GAME:
				finish_game()
				return
			inning += 1
			inning_scores.append(Vector2i.ZERO)
		phase = Phase.FIELDING if phase == Phase.BATTING else Phase.BATTING


func finish_game() -> void:
	if game_over:
		return
	game_over = true
	pitch_queue_revision += 1
	player_pitching.ready_to_pitch = false
	player_pitching.charging = false
	hit_slowmo_remaining = 0.0
	ball_in_play = false
	catching.stop()
	passing.stop()
	if field_tween != null:
		field_tween.kill()
	for controller in [pitching_box, player_pitching, field_view, run_box, catching, passing]:
		controller.process_mode = Node.PROCESS_MODE_DISABLED
	for item in get_children():
		if item is CanvasItem and item not in [$Score, $BG, announcements, $RestartButton, $FullscreenButton]:
			item.hide()
	update_display()
	announcements.announce(AnnouncementText.WIN if player_score > opponent_score else AnnouncementText.LOSS, Vector2(216, 240))


func record_ball() -> void:
	if game_over:
		return
	balls += 1
	if balls == 4:
		# Only runners forced by the batter's walk advance.
		if bases[0]:
			if bases[1]:
				if bases[2]:
					score_runs(1)
				bases[2] = true
			bases[1] = true
		bases[0] = true
		balls = 0
		strikes = 0


func record_pitch(hit_bases: int, batter_safe: bool = true) -> void:
	if game_over:
		return
	assert(hit_bases >= 0 and hit_bases <= 4)
	if hit_bases > 0:
		var runs := 0
		balls = 0
		# shortcut: runners advance the hit's base count; add extra-base decisions with fielding.
		for step in range(hit_bases):
			if bases[2]:
				runs += 1
			bases = [step == 0 and batter_safe, bases[0], bases[1]]
		strikes = 0
		if runs > 0:
			score_runs(runs)
	else:
		strikes += 1
		if strikes == 3:
			strikeout.emit()
			strikes = 0
			record_out()


func score_runs(runs: int) -> void:
	if game_over:
		return
	if phase == Phase.BATTING:
		player_score += runs
		inning_scores[inning - 1].x += runs
	else:
		opponent_score += runs
		inning_scores[inning - 1].y += runs
	runs_scored.emit(runs)


func update_scorecard() -> void:
	var first := floori(float(inning - 1) / away_scores.size()) * away_scores.size()
	for column in range(away_scores.size()):
		var index := first + column
		away_scores[column].text = str(inning_scores[index].x) if index < inning_scores.size() else ""
		home_scores[column].text = str(inning_scores[index].y) if index < inning_scores.size() else ""
	innings_label.text = "INNINGS" if first == 0 else "INNINGS %d-%d" % [first + 1, first + away_scores.size()]
	var row_step := home_scores[0].position.y - away_scores[0].position.y
	score_arrow.position = score_arrow_top + Vector2(0, row_step if phase == Phase.FIELDING else 0.0)


func set_hit_speed(speed: float) -> void:
	var controller = active_pitch()
	controller.playback_speed = speed
	controller.batter.speed_scale = speed
	controller.pitcher.speed_scale = GameDifficulty.game_speed * speed
	field_view.set_playback_speed(speed)


func _process(delta: float) -> void:
	if hit_slowmo_remaining > 0.0:
		hit_slowmo_remaining = maxf(0.0, hit_slowmo_remaining - delta)
		if hit_slowmo_remaining == 0.0:
			set_hit_speed(1.0)
			update_display()


func update_display() -> void:
	update_scorecard()
	count_label.text = "%d--%d" % [balls, strikes]
	for i in range(3):
		base_icons[i].texture = BASE_FULL if bases[i] else BASE_EMPTY
		out_icons[i].texture = OUT_FULL if i < outs else OUT_EMPTY
	if game_over:
		return
	pitching_box.visible = phase == Phase.BATTING and (not ball_in_play or hit_slowmo_remaining > 0.0)
	player_pitching.visible = phase == Phase.FIELDING and (not ball_in_play or hit_slowmo_remaining > 0.0)
	passing.visible = phase == Phase.FIELDING and ball_in_play and passing.started
	catching.visible = phase == Phase.FIELDING and ball_in_play and hit_slowmo_remaining == 0.0 and catching.started and not passing.started
	field_view.pitch_controller = active_pitch()
	field_view.run_controller = run_box if phase == Phase.BATTING else null
	field_view.player_fielding = phase == Phase.FIELDING
	var target_x := field_right_x if phase == Phase.BATTING else field_left_x
	if target_x != field_target_x:
		field_target_x = target_x
		if field_tween != null:
			field_tween.kill()
		field_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		field_tween.tween_method(move_field, $Field.position.x, target_x, 0.45)
	run_box.visible = phase == Phase.BATTING and play_phase == phase and ball_in_play and hit_slowmo_remaining == 0.0
	$SwingInput.visible = pitching_box.visible
	$RunInput.visible = run_box.visible
	$PitchInput.visible = player_pitching.visible
	$CatchInput.visible = catching.visible
	$PassInput.visible = passing.visible
	phase_status.visible = false

	if announcements.visible:
		announcements.layout_message()


func move_field(x: float) -> void:
	$Field.position.x = roundf(x)
	if announcements.visible:
		announcements.layout_message()


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func restart_game() -> void:
	if restarting:
		return
	restarting = true
	pitch_queue_revision += 1
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("F"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("R"):
		restart_game()
		get_viewport().set_input_as_handled()
