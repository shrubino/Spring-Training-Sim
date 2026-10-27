extends Node

const BAT_HITS := [
	preload("res://Assets/Audio/bathit1.mp3"),
	preload("res://Assets/Audio/bathit2.mp3"),
	preload("res://Assets/Audio/bathit3.mp3"),
]
const MITTS := [
	preload("res://Assets/Audio/mitt1.mp3"),
	preload("res://Assets/Audio/mitt2.mp3"),
	preload("res://Assets/Audio/mitt3.mp3"),
]

@onready var crowd_a: AudioStreamPlayer = $CrowdA
@onready var crowd_b: AudioStreamPlayer = $CrowdB
@onready var bat: AudioStreamPlayer = $BatHits
@onready var mitt: AudioStreamPlayer = $Mitt
@onready var cheer: AudioStreamPlayer = $Cheer
@onready var hit_cheer: AudioStreamPlayer = $HitCheer
@onready var home_run_cheer: AudioStreamPlayer = $HomeRunCheer
@onready var good_try: AudioStreamPlayer = $GoodTry
@onready var whoa: AudioStreamPlayer = $Whoa
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	var ambience: AudioStreamMP3 = crowd_a.stream.duplicate()
	ambience.loop = true
	crowd_a.stream = ambience
	crowd_b.stream = ambience
	crowd_a.play()
	crowd_b.play(ambience.get_length() * 0.43)
	$WhoaDelay.timeout.connect(whoa.play)
	var game = get_parent()
	var field = game.get_node("Field/TextureRect")
	for pitch in [game.get_node("Batting"), game.get_node("Pitching")]:
		pitch.ball_contact.connect(_on_ball_contact)
		pitch.foul_contact.connect(func(): play_variant(bat, BAT_HITS))
		pitch.pitch_received.connect(_on_pitch_received)
	game.strikeout.connect(good_try.play)
	field.runner_tagged_out.connect(good_try.play)
	field.ball_caught.connect(play_mitt)
	field.home_run.connect(play_home_run_cheer)
	field.play_finished.connect(_on_play_finished)
	game.get_node("Run").run_finished.connect(_on_run_finished)
	game.runs_scored.connect(func(_runs: int): play_cheer())


func play_variant(player: AudioStreamPlayer, samples: Array) -> void:
	player.stream = samples[rng.randi_range(0, samples.size() - 1)]
	player.pitch_scale = rng.randf_range(0.97, 1.03)
	player.play()


func play_mitt() -> void:
	play_variant(mitt, MITTS)


func play_cheer() -> void:
	if not cheer.playing and not home_run_cheer.playing:
		cheer.play()


func play_home_run_cheer() -> void:
	cheer.stop()
	hit_cheer.stop()
	home_run_cheer.play()


func _on_ball_contact(_play: RefCounted) -> void:
	play_variant(bat, BAT_HITS)
	hit_cheer.play()


func _on_pitch_received(swing_miss: bool) -> void:
	play_mitt()
	if swing_miss:
		$WhoaDelay.start()


func _on_play_finished(_play: RefCounted, caught: bool, runner_out: bool) -> void:
	if not caught and not runner_out:
		play_cheer()


func _on_run_finished(outcome: String) -> void:
	if outcome == AnnouncementText.RUN_CAUGHT:
		play_cheer()


func _exit_tree() -> void:
	for player in get_children():
		if player is AudioStreamPlayer:
			player.stop()
