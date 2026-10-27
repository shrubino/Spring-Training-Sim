extends Node2D

signal pitch_finished(hit_bases: int)
signal pitch_selected(pitch_name: String)
signal pitch_started
signal pitch_received(swing_miss: bool)
signal pitch_released
signal ball_contact(play: RefCounted)
signal foul_contact

const HitPlay = preload("res://Scripts/hit_play.gd")

enum State { IDLE, WINDUP, FLIGHT, RESULT }
enum Type { FASTBALL, CHANGEUP, SLIDER, CURVEBALL }
const RELEASE_FRAME := 7
const PITCH_STEP := 6.0
const CONTACT_FRAME := 5
const FLIGHT_TIME := 1.0
const PLATE_OFFSET := Vector2(16, 0)

@onready var pitcher: AnimatedSprite2D = $Pitcher
@onready var pitcher_home: Vector2 = pitcher.position
@onready var batter: AnimatedSprite2D = $Batter
@onready var ball_area: Control = $BallArea
@onready var ball: Sprite2D = $BallArea/Ball
var state := State.IDLE
var playback_speed := 1.0
var flight_elapsed := 0.0
var hit_result := 0
var rng := RandomNumberGenerator.new()
var pitch_type := Type.FASTBALL
var flight_duration := FLIGHT_TIME
var deceleration := 0.0
var pitch_is_ball := false
var swung_at_pitch := false
var called_ball := false
var fouled_pitch := false
var break_offset := 0.0
var pitch_quality := 0.5
var break_start := 0.3
var curve_depth := 0.0
var release_position := Vector2.ZERO
var plate_position := Vector2.ZERO


func _ready() -> void:
	pitcher.frame_changed.connect(_on_pitcher_frame_changed)
	batter.frame_changed.connect(_on_batter_frame_changed)
	batter.animation_finished.connect(func(): batter.play("idle"))
	pitcher.speed_scale = GameDifficulty.game_speed
	ball.hide()


func start_pitch(type: int = -1, quality: float = -1.0) -> void:
	if state != State.IDLE:
		return
	pitch_type = rng.randi_range(0, GameDifficulty.pitch_profiles.size() - 1) if type == -1 else type
	assert(pitch_type >= 0 and pitch_type < GameDifficulty.pitch_profiles.size())
	var profile: Dictionary = GameDifficulty.pitch_profiles[pitch_type]
	flight_duration = profile.duration
	deceleration = profile.deceleration
	pitch_is_ball = rng.randf() < profile.ball_chance
	break_offset = (14.0 if rng.randf() < 0.5 else -14.0) if pitch_is_ball else 0.0
	if pitch_type == Type.SLIDER and not pitch_is_ball:
		break_offset = rng.randf_range(-2.0, 2.0)
	pitch_quality = rng.randf_range(GameDifficulty.cpu_pitch_quality.x, GameDifficulty.cpu_pitch_quality.y) if quality < 0.0 else clampf(quality, 0.0, 1.0)
	flight_duration *= rng.randf_range(GameDifficulty.pitch_duration_variation.x, GameDifficulty.pitch_duration_variation.y)
	if pitch_type == Type.FASTBALL:
		flight_duration = lerpf(GameDifficulty.fastball_duration.y, GameDifficulty.fastball_duration.x, pitch_quality) * rng.randf_range(GameDifficulty.fastball_variation.x, GameDifficulty.fastball_variation.y)
	break_start = 0.3
	curve_depth = 0.0
	if pitch_type == Type.CURVEBALL:
		break_start = lerpf(GameDifficulty.curve_break_start.x, GameDifficulty.curve_break_start.y, pitch_quality)
		curve_depth = lerpf(GameDifficulty.curve_depth.x, GameDifficulty.curve_depth.y, pitch_quality)
	swung_at_pitch = false
	called_ball = false
	fouled_pitch = false
	hit_result = 0
	flight_elapsed = 0.0
	pitch_selected.emit(profile.name)
	ball.hide()
	state = State.WINDUP
	pitcher.play("pitch")
	pitcher.set_frame_and_progress(0, 0.0)
	pitch_started.emit()


func _on_pitcher_frame_changed() -> void:
	if pitcher.animation == &"pitch":
		pitcher.position = pitcher_home + Vector2((-1.0 if not pitcher.flip_h else 1.0) * roundf(PITCH_STEP * minf(float(pitcher.frame) / RELEASE_FRAME, 1.0)), 0)
	if state == State.WINDUP and pitcher.frame >= RELEASE_FRAME:
		release_position = pitcher.position - ball_area.position + Vector2(17 if pitcher.flip_h else -17, -2)
		plate_position = batter.position - ball_area.position + Vector2(-PLATE_OFFSET.x if batter.flip_h else PLATE_OFFSET.x, PLATE_OFFSET.y)
		ball.position = release_position
		ball.show()
		state = State.FLIGHT
		pitch_released.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Space"):
		swing()


func swing() -> void:
	if not visible or state not in [State.IDLE, State.WINDUP, State.FLIGHT]:
		return
	if batter.animation == &"swing" and batter.is_playing():
		return
	if state == State.FLIGHT:
		swung_at_pitch = true
	batter.play("swing")
	batter.set_frame_and_progress(0, 0.0)


func _on_batter_frame_changed() -> void:
	if state == State.FLIGHT and batter.animation == &"swing" and batter.frame == CONTACT_FRAME:
		swung_at_pitch = true
		var bases := hit_bases_for_time(flight_elapsed, flight_duration)
		if not pitch_is_ball and bases > 0:
			if bases == 1 and rng.randf() < GameDifficulty.foul_chance:
				finish_foul()
			else:
				finish_pitch(bases)


static func is_hit_time(elapsed: float) -> bool:
	return hit_bases_for_time(elapsed) > 0


static func hit_bases_for_time(elapsed: float, arrival: float = FLIGHT_TIME) -> int:
	var error := absf(elapsed - arrival)
	if error > GameDifficulty.hit_window:
		return 0
	if error <= GameDifficulty.home_run_window:
		return 4
	if error <= GameDifficulty.triple_window:
		return 3
	if error <= GameDifficulty.double_window:
		return 2
	return 1


func flight_progress() -> float:
	var t := flight_elapsed / flight_duration
	if t > 1.0:
		return 1.0 + (t - 1.0) * (1.0 - deceleration)
	return t + deceleration * t * (1.0 - t)


func break_progress() -> float:
	return smoothstep(break_start, 0.96 if pitch_type == Type.CURVEBALL else 0.85, flight_elapsed / flight_duration)


func vertical_offset() -> float:
	var rise := smoothstep(0.0, 0.3, flight_elapsed / flight_duration)
	return break_offset * break_progress() - curve_depth * rise * (1.0 - break_progress())


func _process(delta: float) -> void:
	delta *= GameDifficulty.game_speed * playback_speed
	if state == State.FLIGHT:
		flight_elapsed += delta
		ball.position = release_position.lerp(plate_position, flight_progress()) + Vector2(0, vertical_offset())
		if flight_elapsed > flight_duration + GameDifficulty.hit_window:
			finish_pitch(0)
	elif state == State.RESULT:
		var velocity := Vector2(-650 if pitcher.flip_h else 650, -100) if hit_result else (plate_position - release_position) * (1.0 - deceleration) / flight_duration
		if fouled_pitch:
			velocity = Vector2(-180, -220)
		ball.position += velocity * delta
		var ball_rect := Rect2(ball.position - ball.texture.get_size() / 2.0, ball.texture.get_size())
		if not Rect2(Vector2.ZERO, ball_area.size).intersects(ball_rect):
			ball.hide()
			pitcher.play("idle")
			pitcher.position = pitcher_home
			state = State.IDLE
			pitch_finished.emit(hit_result)


func finish_pitch(hit: int) -> void:
	hit_result = hit
	called_ball = hit == 0 and pitch_is_ball and not swung_at_pitch
	state = State.RESULT
	if hit > 0:
		ball_contact.emit(HitPlay.from_contact(hit, flight_elapsed, flight_duration))
	else:
		pitch_received.emit(swung_at_pitch)


func finish_foul() -> void:
	fouled_pitch = true
	hit_result = 0
	called_ball = false
	state = State.RESULT
	foul_contact.emit()
