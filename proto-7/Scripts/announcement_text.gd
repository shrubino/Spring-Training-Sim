class_name AnnouncementText
extends RefCounted

# Pitch names also supply the pitching selection label.
const FASTBALL := "Fastball"
const CHANGEUP := "Changeup"
const SLIDER := "Slider"
const CURVEBALL := "Curveball"
const PITCH_CALL := "%s!"

# Batting and pitch counts.
const BALL := "Ball!"
const WALK := "Ball four -- walk!"
const STRIKE := "Strike!"
const FOUL := "Foul ball!"
const GROUND_BALL := "Chopped into the infield!"
const STRIKEOUT := "Strike three! You're out!"

# Pitching to the opposing batter.
const OPPONENT_STRIKEOUT := "Strike three! He's out!"
const OPPONENT_WALK := "Ball four! He takes his base!"

# Fielding, catching, and plays at the bases.
const CAUGHT := "Caught! He's out!"
const TAGGED_OUT := "Out at the base!"
const SAFE := "Safe!"
const GREAT_CATCH := "What a catch! He's out!"
const GREAT_PICKUP := "Great pickup! Make the throw!"
const THROW_TO_BASE := "He's throwing to %s!"
const THROW_ERROR := "Throwing error -- extra base!"
const BASE_NAMES := ["first", "second", "third", "home"]
const GATHERED := "On base!"
const FUMBLE := "It popped out of the glove!"
const MISSED_CATCH := "It gets past him!"

# Run results, shared by gameplay signals and their announcement/audio callers.
const RUN_CAUGHT := "CAUGHT — OUT"
const RUN_THROWN_OUT := "THROWN OUT"
const RUN_SAFE := "SAFE!"

# Hit dialogue, in display order. The home-run finish plays when the ball leaves the field.
const LINE_DRIVE := "Line drive hit!"
const HIT_LINES := {
	1: [LINE_DRIVE],
	2: [LINE_DRIVE, "He's going for a double!"],
	3: [LINE_DRIVE, "Folks, it could be a triple!"],
	4: ["It's going...", "Going..."],
}
const HOME_RUN := "Gone! Home run!!"

# Inning introductions. %s is the ordinal inning name.
const INNING_NAMES := ["1st", "2nd", "3rd"]
const TOP_INNING := "Top of the %s! You're on bat, kid!"
const BOTTOM_INNING := "Bottom of the %s! Take the mound!"
# Final results after three complete innings.
const WIN := "We got em! Nice work, kid"
const LOSS := "Welcome to the big leagues, kid"

const QUOTED_LINE := '"%s"'


static func pitch(pitch_name: String) -> String:
	return PITCH_CALL % pitch_name


static func inning(number: int, away_batting: bool) -> String:
	return (TOP_INNING if away_batting else BOTTOM_INNING) % INNING_NAMES[number - 1]


static func throw_to_base(base: int) -> String:
	return THROW_TO_BASE % BASE_NAMES[base - 1]
