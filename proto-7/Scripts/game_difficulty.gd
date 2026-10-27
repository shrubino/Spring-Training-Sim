class_name GameDifficulty
extends RefCounted

enum Level { EASY, MEDIUM, HARD }

# Each row contains Easy, Medium, Hard values; Medium is the standard balance.
const PRESETS := {
	"hit_window": [0.074, 0.062, 0.054],
	"double_window": [0.03, 0.025, 0.021],
	"triple_window": [0.010, 0.008, 0.0065],
	"home_run_window": [0.004, 0.003, 0.0025],
	"fastball_duration": [Vector2(0.88, 1.26), Vector2(0.76, 1.14), Vector2(0.68, 1.04)],
	"foul_chance": [0.12, 0.18, 0.23],
	"infield_grounder_chance": [0.18, 0.28, 0.36],
	"single_airborne_chance": [0.14, 0.2, 0.26],
	"run_step": [0.05, 0.045, 0.042],
	"run_touch_multiplier": [3.0, 2.0, 1.5],
	"fielder_fly_speed": [24.0, 28.0, 32.0],
	"grounder_pickup_speed": [90.0, 105.0, 115.0],
	"field_throw_speed": [220.0, 245.0, 265.0],
	"field_catch_radius": [9.0, 11.0, 12.0],
	"pitch_meter_speed": [1.38, 1.62, 1.85],
	"opponent_contact_chance": [Vector2(0.93, 0.25), Vector2(0.98, 0.34), Vector2(0.99, 0.42)],
	"opponent_single_cutoff": [Vector2(0.68, 0.88), Vector2(0.62, 0.8), Vector2(0.58, 0.75)],
	"opponent_double_cutoff": [Vector2(0.91, 0.97), Vector2(0.88, 0.95), Vector2(0.85, 0.93)],
	"opponent_triple_cutoff": [Vector2(0.985, 0.997), Vector2(0.97, 0.99), Vector2(0.96, 0.985)],
	"catch_duration": [Vector2(1.75, 2.15), Vector2(1.5, 1.85), Vector2(1.35, 1.65)],
	"catch_curve": [18.0, 28.0, 38.0],
	"catch_radius": [20.0, 16.0, 14.0],
	"great_catch_radius": [7.0, 5.0, 4.0],
	"pass_tolerance": [32.0, 24.0, 18.0],
}
static var level := Level.MEDIUM

static var game_speed := 0.85

# Pitch profiles: seconds to the plate, late slowing, and chance of missing the zone.
static var pitch_profiles: Array[Dictionary] = [
	{"name": AnnouncementText.FASTBALL, "duration": 1.0, "deceleration": 0.0, "ball_chance": 0.0},
	{"name": AnnouncementText.CHANGEUP, "duration": 1.5, "deceleration": 0.65, "ball_chance": 0.0},
	{"name": AnnouncementText.SLIDER, "duration": 1.25, "deceleration": 0.35, "ball_chance": 0.65},
	{"name": AnnouncementText.CURVEBALL, "duration": 1.36, "deceleration": 0.42, "ball_chance": 0.30},
]
static var cpu_pitch_quality := Vector2(0.15, 1.0)
static var pitch_duration_variation := Vector2(0.98, 1.02)
static var fastball_duration: Vector2 = PRESETS.fastball_duration[Level.MEDIUM] # Fastest and slowest, before variation.
static var fastball_variation := Vector2(0.97, 1.03)
static var curve_break_start := Vector2(0.48, 0.65)
static var curve_depth := Vector2(5.0, 10.0)

# Batting: timing errors in seconds; foul odds apply only to would-be singles.
static var hit_window: float = PRESETS.hit_window[Level.MEDIUM]
static var double_window: float = PRESETS.double_window[Level.MEDIUM]
static var triple_window: float = PRESETS.triple_window[Level.MEDIUM]
static var home_run_window: float = PRESETS.home_run_window[Level.MEDIUM]
static var foul_chance: float = PRESETS.foul_chance[Level.MEDIUM]
static var infield_grounder_chance: float = PRESETS.infield_grounder_chance[Level.MEDIUM]
static var single_airborne_chance: float = PRESETS.single_airborne_chance[Level.MEDIUM]
static var grounder_distance := Vector2(42.0, 64.0)
static var grounder_flight_time := Vector2(0.32, 0.42)

# Running: distance is measured in bases; times are seconds.
static var run_step: float = PRESETS.run_step[Level.MEDIUM]
static var run_touch_multiplier: float = PRESETS.run_touch_multiplier[Level.MEDIUM]
static var dive_distance := 0.42
static var slide_time := 0.18
static var dive_recovery_time := 1.0
static var opponent_run_speed := 116.0

# Mini-field defense. Speeds are pixels per field simulation second.
static var field_speed := 0.55
static var field_catch_error := 0.07
static var field_throw_error := 0.06
static var field_catch_radius: float = PRESETS.field_catch_radius[Level.MEDIUM]
static var field_dive_radius := 22.0
static var fielder_fly_speed: float = PRESETS.fielder_fly_speed[Level.MEDIUM]
static var fielder_ground_speed := 52.0
static var fielder_dive_speed := 90.0
static var fielder_chase_speed := 76.0
static var grounder_pickup_speed: float = PRESETS.grounder_pickup_speed[Level.MEDIUM]
static var field_throw_speed: float = PRESETS.field_throw_speed[Level.MEDIUM]
static var receiver_speed := 55.0

# Player pitching. Probability ranges run from poor release to perfect release.
static var pitch_meter_speed: float = PRESETS.pitch_meter_speed[Level.MEDIUM]
static var pitch_accuracy_exponent := 2.0
static var player_pitch_ball_chance := Vector2(0.65, 0.03)
static var opponent_contact_chance: Vector2 = PRESETS.opponent_contact_chance[Level.MEDIUM]
# Cumulative hit-quality cutoffs, from poor pitch to perfect pitch.
static var opponent_single_cutoff: Vector2 = PRESETS.opponent_single_cutoff[Level.MEDIUM]
static var opponent_double_cutoff: Vector2 = PRESETS.opponent_double_cutoff[Level.MEDIUM]
static var opponent_triple_cutoff: Vector2 = PRESETS.opponent_triple_cutoff[Level.MEDIUM]

# Catching: seconds of descent, pixels of horizontal bend and catch alignment.
static var catch_move_speed := 105.0
static var catch_radius: float = PRESETS.catch_radius[Level.MEDIUM]
static var great_catch_radius: float = PRESETS.great_catch_radius[Level.MEDIUM]
static var catch_duration: Vector2 = PRESETS.catch_duration[Level.MEDIUM]
static var catch_curve: float = PRESETS.catch_curve[Level.MEDIUM]
static var catch_clean_chance := Vector2(0.78, 0.98)

# Passing: dotted-line growth in pixels/second and release tolerance in pixels.
static var pass_charge_speed := 420.0
static var pass_tolerance: float = PRESETS.pass_tolerance[Level.MEDIUM]


static func apply_level(new_level: Level) -> void:
	assert(new_level >= Level.EASY and new_level <= Level.HARD)
	level = new_level
	hit_window = PRESETS.hit_window[level]
	double_window = PRESETS.double_window[level]
	triple_window = PRESETS.triple_window[level]
	home_run_window = PRESETS.home_run_window[level]
	fastball_duration = PRESETS.fastball_duration[level]
	foul_chance = PRESETS.foul_chance[level]
	infield_grounder_chance = PRESETS.infield_grounder_chance[level]
	single_airborne_chance = PRESETS.single_airborne_chance[level]
	run_step = PRESETS.run_step[level]
	run_touch_multiplier = PRESETS.run_touch_multiplier[level]
	fielder_fly_speed = PRESETS.fielder_fly_speed[level]
	grounder_pickup_speed = PRESETS.grounder_pickup_speed[level]
	field_throw_speed = PRESETS.field_throw_speed[level]
	field_catch_radius = PRESETS.field_catch_radius[level]
	pitch_meter_speed = PRESETS.pitch_meter_speed[level]
	opponent_contact_chance = PRESETS.opponent_contact_chance[level]
	opponent_single_cutoff = PRESETS.opponent_single_cutoff[level]
	opponent_double_cutoff = PRESETS.opponent_double_cutoff[level]
	opponent_triple_cutoff = PRESETS.opponent_triple_cutoff[level]
	catch_duration = PRESETS.catch_duration[level]
	catch_curve = PRESETS.catch_curve[level]
	catch_radius = PRESETS.catch_radius[level]
	great_catch_radius = PRESETS.great_catch_radius[level]
	pass_tolerance = PRESETS.pass_tolerance[level]
