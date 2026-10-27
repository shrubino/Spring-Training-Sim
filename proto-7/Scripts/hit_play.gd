extends RefCounted

const HOME := Vector2(180, 280)

var hit_bases: int
var direction: Vector2
var landing: Vector2
var airborne: bool
var grounder := false
var flight_duration: float


static func from_contact(bases: int, elapsed: float, arrival: float = 1.0) -> RefCounted:
	assert(bases >= 1 and bases <= 4)
	var play = load("res://Scripts/hit_play.gd").new()
	play.hit_bases = bases
	play.grounder = bases == 1 and randf() < GameDifficulty.infield_grounder_chance
	var timing := clampf((elapsed - arrival) / GameDifficulty.hit_window, -1.0, 1.0)
	var side := -1.0 if timing < 0.0 else 1.0
	var angle: float
	var distance: float
	match bases:
		1:
			angle = timing * PI / 4.0
			distance = lerpf(88.0, 120.0, absf(timing))
		2:
			angle = side * lerpf(0.15, 0.65, absf(timing))
			distance = 178.0
		3:
			angle = side * 0.4
			distance = 262.0
		_:
			angle = timing * 0.5
			distance = 312.0
	angle += randf_range(-0.025, 0.025) if bases == 3 else randf_range(-0.06, 0.06)
	angle = clampf(angle, -PI / 4.0, PI / 4.0)
	if play.grounder:
		angle = timing * 0.35 + randf_range(-0.18, 0.18)
		distance = randf_range(GameDifficulty.grounder_distance.x, GameDifficulty.grounder_distance.y)
	play.direction = Vector2(sin(angle), -cos(angle))
	play.landing = HOME + play.direction * distance
	play.airborne = bases > 1 or (not play.grounder and randf() < GameDifficulty.single_airborne_chance)
	play.flight_duration = [0.9, 1.35, 1.65, 1.9][bases - 1]
	if play.grounder:
		play.flight_duration = randf_range(GameDifficulty.grounder_flight_time.x, GameDifficulty.grounder_flight_time.y)
	return play
