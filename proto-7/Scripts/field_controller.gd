extends Control

signal pass_requested
signal ball_caught
signal runner_tagged_out
signal home_run
signal play_finished(play: RefCounted, caught: bool, runner_out: bool)

const HitPlay = preload("res://Scripts/hit_play.gd")
const BASES := [HitPlay.HOME, Vector2(258, 203), Vector2(180, 155), Vector2(100, 203), HitPlay.HOME]
const POSITIONS := {
	"Pitcher": Vector2(180, 211), "Catcher": Vector2(180, 287),
	"FirstBaseman": Vector2(270, 197), "SecondBaseman": Vector2(219, 176),
	"Shortstop": Vector2(142, 179), "ThirdBaseman": Vector2(88, 197),
	"LeftField": Vector2(75, 112), "CenterField": Vector2(180, 78), "RightField": Vector2(285, 112),
}
enum State { READY, WINDUP, PITCH, HIT_FLIGHT, CATCHING, PASSING, CHASE, THROW, LOOSE_BALL, RECOVER }

var state := State.READY
var playback_speed := 1.0
var pitch_controller: Node2D
var run_controller: NinePatchRect
var catch_controller: NinePatchRect
var player_fielding := false
var runner_out := false
var manual_throw_done := false
var great_pickup := false
var frames: SpriteFrames
var defenders: Dictionary = {}
var runners: Array[Dictionary] = []
var batter: AnimatedSprite2D
var ball: Sprite2D
var play: RefCounted
var chaser: AnimatedSprite2D
var receiver: AnimatedSprite2D
var caught := false
var elapsed := 0.0
var throw_start := Vector2.ZERO
var throw_target := Vector2.ZERO
var throw_duration := 0.0
var rng := RandomNumberGenerator.new()
var catch_dropped := false
var throw_missed := false
var throw_attempted := false
var throw_recovered := false
var pickup_target := Vector2.ZERO
var loose_start := Vector2.ZERO
var loose_target := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frames = SpriteFrames.new()
	frames.remove_animation("default")
	for spec in [
		["idle", preload("res://Assets/Animations/Minis/minis_idle.png"), 6, 5.0, true],
		["run", preload("res://Assets/Animations/Minis/minis_run.png"), 6, 10.0, true],
		["pitch", preload("res://Assets/Animations/Minis/minis_throw.png"), 8, 10.0, false],
		["dive", preload("res://Assets/Animations/Minis/minis_dive.png"), 10, 16.0, false],
	]:
		frames.add_animation(spec[0])
		frames.set_animation_speed(spec[0], spec[3])
		frames.set_animation_loop(spec[0], spec[4])
		for i in range(spec[1].get_width() / spec[2]):
			var atlas := AtlasTexture.new()
			atlas.atlas = spec[1]
			atlas.region = Rect2(i * spec[2], 0, spec[2], 8)
			frames.add_frame(spec[0], atlas)
	for role in POSITIONS:
		defenders[role] = make_mini(role, POSITIONS[role], false)
	batter = make_mini("Batter", BASES[0] + Vector2(-10, 0), true)
	ball = Sprite2D.new()
	ball.name = "Ball"
	ball.texture = preload("res://Assets/Sprites/ball.png")
	ball.scale = Vector2(0.5, 0.5)
	ball.z_index = 20
	add_child(ball)
	ball.hide()


func make_mini(role: String, point: Vector2, away: bool) -> AnimatedSprite2D:
	var mini := AnimatedSprite2D.new()
	mini.name = role
	mini.sprite_frames = frames
	mini.speed_scale = (GameDifficulty.game_speed if away else GameDifficulty.field_speed) * playback_speed
	mini.position = point
	mini.offset = Vector2(0, -4)
	#mini.modulate = Color(1.8, 0.75, 0.6) if away else Color(0.7, 1.0, 1.4)
	mini.z_index = 5
	add_child(mini)
	mini.play("idle")
	return mini


func sync_runners(bases: Array[bool]) -> void:
	for runner in runners:
		runner.sprite.free()
	runners.clear()
	for i in range(3):
		if bases[i]:
			add_runner(i + 1)
	batter.show()
	batter.position = BASES[0] + Vector2(-10, 0)
	batter.play("idle")


func add_runner(base: int) -> void:
	var mini := make_mini("Runner%d" % base, BASES[base], true)
	runners.append({"sprite": mini, "origin": base, "route": [], "visited": [BASES[base]]})


func start_pitch() -> void:
	assert(state == State.READY)
	state = State.WINDUP
	ball.hide()
	var pitcher: AnimatedSprite2D = defenders.Pitcher
	pitcher.play("pitch")
	# The top pitcher drives the mini's pose, including edits to animation speed.
	pitcher.pause()
	pitcher.frame = 0


func release_pitch() -> void:
	state = State.PITCH
	ball.position = POSITIONS.Pitcher + Vector2(0, -4)
	ball.show()
	defenders.Pitcher.frame = 2


func finish_miss() -> void:
	ball.hide()
	state = State.READY
	defenders.Pitcher.play("idle")


func start_hit(hit: RefCounted) -> void:
	play = hit
	caught = false
	runner_out = false
	manual_throw_done = false
	great_pickup = false
	if run_controller != null:
		run_controller.start_run(play.hit_bases)
	catch_dropped = false
	throw_missed = false
	throw_attempted = false
	throw_recovered = false
	pickup_target = play.landing
	elapsed = 0.0
	state = State.HIT_FLIGHT
	ball.position = BASES[0]
	ball.show()
	chaser = nearest_defender(play.landing)
	receiver = defenders[["FirstBaseman", "SecondBaseman", "ThirdBaseman", "Catcher"][play.hit_bases - 1]]
	if receiver == chaser:
		receiver = defenders.Shortstop
	add_runner(0)
	batter.hide()
	for runner in runners:
		var route: Array[Vector2] = []
		for base in range(runner.origin + 1, mini(runner.origin + play.hit_bases, 4) + 1):
			route.append(BASES[base])
		runner.route = route
	if player_fielding and play.hit_bases < 4:
		state = State.CATCHING
		catch_controller.start_play(play)


func move_mini(mini: AnimatedSprite2D, target: Vector2, speed: float, delta: float) -> void:
	if mini.position.distance_to(target) <= 0.5:
		mini.position = target
		if mini.animation == &"run":
			mini.play("idle")
		return
	mini.flip_h = target.x < mini.position.x
	if mini.animation != &"dive":
		mini.play("run")
	mini.position = mini.position.move_toward(target, speed * delta)
	if mini.position.distance_to(target) <= 0.5:
		mini.position = target


func move_runners(delta: float) -> bool:
	var done := true
	for runner in runners:
		if runner.origin == 0 and run_controller != null and not caught and not runner_out:
			var distance: float = run_controller.distance
			var base := mini(int(distance), 3)
			runner.sprite.flip_h = BASES[base + 1].x < BASES[base].x
			runner.sprite.position = BASES[base].lerp(BASES[base + 1], clampf(distance - base, 0.0, 1.0))
			while not runner.route.is_empty() and distance >= runner.visited.size():
				runner.visited.append(runner.route.pop_front())
			if run_controller.dive_remaining > 0.0:
				runner.sprite.play("dive")
			elif run_controller.step_remaining > 0.0:
				runner.sprite.play("run")
			else:
				runner.sprite.play("idle")
			if not run_controller.reached_base():
				done = false
			elif play.hit_bases == 4:
				runner.sprite.hide()
			continue
		if runner.route.is_empty():
			continue
		done = false
		move_mini(runner.sprite, runner.route[0], GameDifficulty.opponent_run_speed, delta)
		if runner.sprite.position.distance_to(runner.route[0]) <= 0.5:
			runner.visited.append(runner.route.pop_front())
			if runner.route.is_empty():
				runner.sprite.play("idle")
				if not caught and (runner.origin + play.hit_bases >= 4):
					runner.sprite.hide()
	return done


func begin_throw(player_error: int = -1) -> void:
	if player_error == -1:
		ball_caught.emit()
	if player_fielding and not caught and not manual_throw_done and player_error == -1:
		state = State.PASSING
		chaser.play("idle")
		ball.position = chaser.position + Vector2(0, -4)
		ball.show()
		pass_requested.emit()
		return
	if player_error >= 0:
		manual_throw_done = true
	state = State.THROW
	elapsed = 0.2 if player_error >= 0 else 0.0
	throw_start = chaser.position + Vector2(0, -4)
	throw_target = POSITIONS.Pitcher if caught else BASES[play.hit_bases]
	if not throw_attempted:
		throw_attempted = true
		throw_missed = player_error == 1 if player_error >= 0 else rng.randf() < GameDifficulty.field_throw_error
		if throw_missed:
			throw_target += Vector2(rng.randf_range(18.0, 28.0) * (-1.0 if rng.randf() < 0.5 else 1.0), rng.randf_range(-12.0, 12.0))
			throw_target = throw_target.clamp(Vector2(8, 8), size - Vector2(8, 8))
	throw_duration = maxf(0.3, throw_start.distance_to(throw_target) / GameDifficulty.field_throw_speed)
	chaser.flip_h = throw_target.x < throw_start.x
	if not caught:
		chaser.play("pitch")
	ball.position = throw_start
	ball.show()


func resolve_landing(player_caught: bool = false) -> void:
	caught = player_caught or (play.airborne and chaser.position.distance_to(play.landing) <= GameDifficulty.field_catch_radius)
	if caught and not player_caught and rng.randf() < GameDifficulty.field_catch_error:
		caught = false
		catch_dropped = true
		begin_loose_ball(play.landing + Vector2(rng.randf_range(-12.0, 12.0), 12.0))
		return
	if caught:
		if run_controller != null:
			run_controller.finish_run(AnnouncementText.RUN_CAUGHT)
		chaser.play("dive")
		for runner in runners:
			if runner.origin == 0:
				runner.route.clear()
				runner.sprite.hide()
			else:
				runner.sprite.show()
				runner.route = runner.visited.duplicate()
				runner.route.reverse()
		begin_throw()
	else:
		state = State.CHASE


func resolve_player_catch(clean: bool, fumbled: bool, great_catch: bool = false) -> void:
	if state != State.CATCHING:
		return
	ball.position = play.landing
	if clean:
		chaser.position = play.landing
		great_pickup = great_catch
		if play.airborne:
			resolve_landing(true)
		else:
			begin_throw()
	else:
		catch_dropped = fumbled
		if fumbled:
			advance_on_error()
		begin_loose_ball(play.landing + Vector2(rng.randf_range(-16.0, 16.0), 12.0))


func nearest_defender(point: Vector2) -> AnimatedSprite2D:
	var nearest: AnimatedSprite2D = defenders.Pitcher
	for mini in defenders.values():
		if mini.position.distance_to(point) < nearest.position.distance_to(point):
			nearest = mini
	return nearest


func begin_loose_ball(target: Vector2) -> void:
	state = State.LOOSE_BALL
	elapsed = 0.0
	loose_start = ball.position
	loose_target = target.clamp(Vector2(8, 8), size - Vector2(8, 8))
	pickup_target = loose_target
	var previous_chaser := chaser
	chaser = nearest_defender(pickup_target)
	if receiver == chaser:
		receiver = previous_chaser
	chaser.play("run")


func advance_on_error() -> void:
	if caught or play.hit_bases == 4:
		return
	if run_controller != null and run_controller.reached_base():
		return
	play.hit_bases += 1
	if run_controller != null:
		run_controller.set_goal(play.hit_bases)
	for runner in runners:
		var next_base: int = runner.origin + play.hit_bases
		if next_base <= 4:
			runner.sprite.show()
			runner.route.append(BASES[next_base])
			runner.sprite.play("run")


func set_playback_speed(speed: float) -> void:
	playback_speed = speed
	for child in get_children():
		if child is AnimatedSprite2D:
			child.speed_scale = (GameDifficulty.field_speed if child in defenders.values() else GameDifficulty.game_speed) * speed


func _process(delta: float) -> void:
	delta *= GameDifficulty.field_speed * playback_speed
	if state in [State.HIT_FLIGHT, State.CHASE, State.THROW, State.LOOSE_BALL] and receiver != chaser:
		move_mini(receiver, POSITIONS.Pitcher if caught else BASES[play.hit_bases], GameDifficulty.receiver_speed, delta)
	match state:
		State.WINDUP:
			if pitch_controller != null:
				defenders.Pitcher.frame = mini(3, int(float(pitch_controller.pitcher.frame) / pitch_controller.RELEASE_FRAME * 2.0))
		State.PITCH:
			if pitch_controller != null:
				defenders.Pitcher.frame = mini(3, int(float(pitch_controller.pitcher.frame) / pitch_controller.RELEASE_FRAME * 2.0))
				ball.position = (POSITIONS.Pitcher + Vector2(0, -4)).lerp(BASES[0], minf(1.0, pitch_controller.flight_progress()))
				ball.position.x += pitch_controller.vertical_offset() * 0.5
		State.CATCHING:
			if not catch_controller.is_visible_in_tree():
				return
			var t: float = clampf(catch_controller.elapsed / catch_controller.duration, 0.0, 1.0)
			ball.position = BASES[0].lerp(play.landing, t) + Vector2(sin(t * PI) * catch_controller.curve_amount * 0.35, -sin(t * PI) * 28.0)
			var offset: float = (catch_controller.fielder.position.x - catch_controller.target.x) * 0.35
			move_mini(chaser, play.landing + Vector2(offset, 0), 80.0, delta)
			move_runners(delta)
		State.PASSING:
			ball.position = chaser.position + Vector2(0, -4)
			if receiver != chaser:
				move_mini(receiver, BASES[play.hit_bases], GameDifficulty.receiver_speed, delta)
			move_runners(delta)
		State.HIT_FLIGHT:
			elapsed += delta
			var t := minf(1.0, elapsed / play.flight_duration)
			var height: float = 0.0 if not play.airborne else 24.0 + play.hit_bases * 3.0
			ball.position = BASES[0].lerp(play.landing, t) + Vector2(0, -sin(t * PI) * height)
			if play.hit_bases < 4:
				if chaser.position.distance_to(play.landing) < GameDifficulty.field_dive_radius and t > 0.8:
					chaser.play("dive")
				var speed := GameDifficulty.fielder_dive_speed if chaser.animation == &"dive" else (GameDifficulty.fielder_ground_speed if not play.airborne else GameDifficulty.fielder_fly_speed)
				if play.grounder:
					speed = GameDifficulty.grounder_pickup_speed
				move_mini(chaser, play.landing, speed, delta)
			move_runners(delta)
			if t >= 1.0:
				if play.hit_bases == 4:
					ball.hide()
					state = State.RECOVER
					home_run.emit()
				else:
					resolve_landing()
		State.LOOSE_BALL:
			elapsed += delta
			var t := minf(1.0, elapsed / 0.4)
			ball.position = loose_start.lerp(loose_target, t) + Vector2(0, -sin(t * PI) * 5.0)
			move_mini(chaser, pickup_target, 45.0, delta)
			move_runners(delta)
			if t >= 1.0:
				state = State.CHASE
		State.CHASE:
			move_runners(delta)
			if chaser.position.distance_to(pickup_target) < 16.0:
				chaser.play("dive")
			move_mini(chaser, pickup_target, GameDifficulty.grounder_pickup_speed if play.grounder else GameDifficulty.fielder_chase_speed, delta)
			if chaser.position.distance_to(pickup_target) <= 2.0:
				begin_throw()
		State.THROW:
			elapsed += delta
			if caught and elapsed >= 0.2 and elapsed - delta < 0.2:
				chaser.play("pitch")
			move_runners(delta)
			var t := clampf((elapsed - 0.2) / throw_duration, 0.0, 1.0)
			ball.position = throw_start.lerp(throw_target, t) + Vector2(0, -sin(t * PI) * 8.0)
			if t >= 1.0:
				if throw_missed and not throw_recovered:
					throw_recovered = true
					advance_on_error()
					begin_loose_ball(throw_target + Vector2(8, 4))
				else:
					ball_caught.emit()
					var batter_running := false
					for runner in runners:
						if runner.origin == 0 and not runner.route.is_empty():
							batter_running = true
					var throw_out: bool = not run_controller.reached_base() if run_controller != null else batter_running
					if manual_throw_done:
						throw_out = not throw_missed and (great_pickup or batter_running)
					if not caught and throw_out:
						runner_out = true
						runner_tagged_out.emit()
						if run_controller != null:
							run_controller.finish_run(AnnouncementText.RUN_THROWN_OUT)
						for runner in runners:
							if runner.origin == 0:
								runner.route.clear()
								runner.sprite.hide()
					ball.hide()
					state = State.RECOVER
		State.RECOVER:
			var done := move_runners(delta)
			for role in defenders:
				var mini: AnimatedSprite2D = defenders[role]
				if mini.animation in [&"pitch", &"dive"]:
					mini.play("idle")
				move_mini(mini, POSITIONS[role], 65.0, delta)
				if mini.position.distance_to(POSITIONS[role]) > 0.5:
					done = false
			if done:
				state = State.READY
				if run_controller != null and not caught and not runner_out:
					run_controller.finish_run(AnnouncementText.RUN_SAFE)
				play_finished.emit(play, caught, runner_out)
