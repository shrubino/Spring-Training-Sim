extends Node2D

signal throw_released(missed: bool)

enum State { IDLE, READY, CHARGING, WINDUP, FLIGHT, DONE }
const RELEASE_FRAME := 3

@onready var passer: AnimatedSprite2D = $Passer
@onready var catcher: AnimatedSprite2D = $Catcher
@onready var ball_area: Control = $BallArea
@onready var ball: Sprite2D = $BallArea/Ball
var state := State.IDLE
var started := false
var charge_distance := 0.0
var missed := false
var elapsed := 0.0
var flight_duration := 0.6
var release_position := Vector2.ZERO
var receive_position := Vector2.ZERO
var landing := Vector2.ZERO


func _ready() -> void:
	passer.sprite_frames.set_animation_speed("default", 12.0)
	passer.sprite_frames.set_animation_loop("default", false)
	passer.frame_changed.connect(_on_passer_frame_changed)
	stop()


func start_pass() -> void:
	started = true
	state = State.READY
	charge_distance = 0.0
	missed = false
	elapsed = 0.0
	release_position = passer.position + Vector2(12, -8)
	receive_position = catcher.position + Vector2(-12, -8)
	passer.set_frame_and_progress(passer.sprite_frames.get_frame_count("default") - 1, 0.0)
	passer.pause()
	catcher.set_frame_and_progress(0, 0.0)
	catcher.pause()
	ball.hide()
	queue_redraw()


func stop() -> void:
	started = false
	state = State.IDLE
	charge_distance = 0.0
	passer.pause()
	catcher.pause()
	ball.hide()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if state == State.READY and event.is_action_pressed("Space"):
		state = State.CHARGING
	elif state == State.CHARGING and event.is_action_released("Space"):
		missed = absf(charge_distance - release_position.distance_to(receive_position)) > GameDifficulty.pass_tolerance
		state = State.WINDUP
		passer.play("default")
		passer.set_frame_and_progress(0, 0.0)
		queue_redraw()


func _on_passer_frame_changed() -> void:
	if state == State.WINDUP and passer.frame >= RELEASE_FRAME:
		throw_released.emit(missed)


func launch_ball(duration: float) -> void:
	state = State.FLIGHT
	elapsed = 0.0
	flight_duration = duration
	landing = receive_position
	if missed:
		landing.x = release_position.x + clampf(charge_distance, 24.0, ball_area.position.x + ball_area.size.x + 8.0 - release_position.x)
	ball.position = release_position - ball_area.position
	ball.show()


func _process(delta: float) -> void:
	if state == State.CHARGING:
		charge_distance += GameDifficulty.pass_charge_speed * delta
		queue_redraw()
	elif state == State.FLIGHT:
		elapsed += delta
		var t := minf(1.0, elapsed / flight_duration)
		ball.position = release_position.lerp(landing, t) - ball_area.position + Vector2(0, sin(t * PI) * (12.0 if missed else -6.0))
		if t >= 1.0:
			state = State.DONE
			ball.hide()
			if not missed:
				catcher.frame = 1


func _draw() -> void:
	if state != State.CHARGING:
		return
	var length := minf(charge_distance, ball_area.position.x + ball_area.size.x - release_position.x)
	var direction := release_position.direction_to(receive_position)
	for distance in range(0, int(length), 10):
		draw_rect(Rect2((release_position + direction * distance).round(), Vector2(2, 2)), Color(0.24, 0.24, 0.24))
