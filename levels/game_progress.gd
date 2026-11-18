class_name GameProgress
extends RefCounted
## What the player has done so far, kept between runs in user://progress.cfg:
## each level's best result, and from those the ocean's health, which the
## title screen and the results show.
##
## The levels are listed here in order. One with no scene yet shows on the
## title screen as coming soon.

const PATH := "user://progress.cfg"
## Stars a level can earn.
const MAX_STARS := 3
## The ocean's health before any level is done. It starts in a bad way.
const START_HEALTH := 0.12

const LEVELS: Array[Dictionary] = [
	{
		"id": "nesting_beach",
		"title": "Nesting Beach",
		"animal": "Crabs",
		"blurb": "Turtle eggs were laid on the wrong side of the mountain. Carry them home to the nest before the tide gets them.",
		"scene": "res://levels/nesting_beach.tscn",
	},
	{
		"id": "clean_currents",
		"title": "Clean Currents",
		"animal": "Fish",
		"blurb": "Find the trash hidden around the reef and bring it to the collection net.",
		"scene": "",
	},
	{
		"id": "open_sky",
		"title": "Open Sky",
		"animal": "Bird",
		"blurb": "Coming soon.",
		"scene": "",
	},
]

static var _config: ConfigFile


## The best result saved for a level: "stars", "time" (seconds) and "eggs",
## or empty if it hasn't been finished.
static func get_best(level_id: String) -> Dictionary:
	_load()
	return _config.get_value("best", level_id, {})


## Saves a level's result if it beats the best so far: more stars, or as
## many in less time. Returns whether it did.
static func record(level_id: String, result: Dictionary) -> bool:
	var best := get_best(level_id)
	var better: bool = best.is_empty() or result.stars > best.stars \
			or (result.stars == best.stars and result.time < best.time)
	if better:
		_config.set_value("best", level_id, result)
		_config.save(PATH)
	return better


## Every star earned, over every level.
static func get_total_stars() -> int:
	var total := 0
	for level in LEVELS:
		total += int(get_best(level.id).get("stars", 0))
	return total


## How healthy the ocean is, 0 to 1: START_HEALTH, plus a share of the rest
## for each star earned.
static func get_health() -> float:
	var possible := LEVELS.size() * MAX_STARS
	return START_HEALTH + (1.0 - START_HEALTH) * get_total_stars() / possible


## Forgets every result.
static func reset() -> void:
	_load()
	_config.clear()
	_config.save(PATH)


static func _load() -> void:
	if _config:
		return
	_config = ConfigFile.new()
	_config.load(PATH)


## Seconds as m:ss.
static func format_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]
