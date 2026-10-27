extends NinePatchRect

signal resolved(clean: bool, fumbled: bool)

@onready var fielder: AnimatedSprite2D = $AnimatedSprite2D
@onready var ball: Sprite2D = $Ball
var rng := RandomNumberGenerator.new()
var active := false
var started := false
var elapsed := 0.0
var duration := 1.675
var great_catch := false
var curve_amount := 0.0
var start := Vector2.ZERO
var target := Vector2.ZERO
var loose_velocity := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	fielder.z_index = 1
	fielder.sprite_frames.set_animation_speed("default", 12.0)
	stop()


func start_play(_play: RefCounted) -> void:
	active = true
	started = true
	elapsed = 0.0
	duration = rng.randf_range(GameDifficulty.catch_duration.x, GameDifficulty.catch_duration.y)
	curve_amount = rng.randf_range(-GameDifficulty.catch_curve, GameDifficulty.catch_curve)
	great_catch = false
	fielder.position.x = size.x / 2.0
	fielder.flip_h = false
	fielder.set_frame_and_progress(0, 0.0)
	fielder.pause()
	target = Vector2(rng.randf_range(28.0, size.x - 28.0), fielder.position.y - 11.0)
	start = Vector2(clampf(target.x + rng.randf_range(-80.0, 80.0), 12.0, size.x - 12.0), 32.0)
	ball.position = start
	ball.show()
	loose_velocity = Vector2.ZERO


func stop() -> void:
	active = false
	started = false
	great_catch = false
	ball.hide()
	fielder.pause()


func _process(delta: float) -> void:
	if not started or not is_visible_in_tree():
		return
	if not active:
		if ball.visible:
			loose_velocity.y += 220.0 * delta
			ball.position += loose_velocity * delta
			if ball.position.y > size.y + 8.0:
				ball.hide()
		return
	var movement := Input.get_axis("Left", "Right")
	fielder.position.x = clampf(fielder.position.x + movement * GameDifficulty.catch_move_speed * delta, 18.0, size.x - 18.0)
	if movement != 0.0:
		fielder.flip_h = movement < 0.0
		fielder.play("default")
	else:
		fielder.set_frame_and_progress(0, 0.0)
		fielder.pause()
	elapsed = minf(duration, elapsed + delta)
	var t := elapsed / duration
	ball.position = start.lerp(target, t) + Vector2(sin(t * PI) * curve_amount, 0)
	ball.position.x = clampf(ball.position.x, 12.0, size.x - 12.0)
	if elapsed >= duration:
		var error := absf(fielder.position.x - target.x)
		var aligned := error <= GameDifficulty.catch_radius
		var chance := lerpf(GameDifficulty.catch_clean_chance.x, GameDifficulty.catch_clean_chance.y, 1.0 - clampf(error / GameDifficulty.catch_radius, 0.0, 1.0))
		var clean := aligned and rng.randf() < chance
		great_catch = clean and error <= GameDifficulty.great_catch_radius
		active = false
		fielder.pause()
		if clean:
			ball.hide()
		else:
			loose_velocity = Vector2(rng.randf_range(-45.0, 45.0), -70.0 if aligned else 70.0)
		resolved.emit(clean, aligned and not clean)
