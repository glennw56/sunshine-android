extends RefCounted
## 18-hole bakery course. Pars sum to 53. Tunables live here so a playtest
## can change the loop and the jump without hunting through the rules.

const PAR_TOTAL := 53
const BALL_RADIUS := 0.06
const BALL_MASS := 0.18
const BALL_LINEAR_DAMP := 0.16
const BALL_ANGULAR_DAMP := 0.42
const BALL_FRICTION := 0.28
const BALL_BOUNCE := 0.30
const BALL_GRAVITY := 1.0
const STOP_SPEED := 0.07
const CUP_CAPTURE_SPEED := 1.2
const MIN_PUTT_SPEED := 0.8
const MAX_PUTT_SPEED := 9.0
const CONVEYOR_MPS := 0.6
const STROKE_CAP := 3
const UNLOCK_SECONDS := 86400
## Full-power entries. Hole 4 needs about 3.2 m/s at the loop. Hole 14's
## kicker is a 28 degree lip; this power is what the playtest settled on.
const LOOP_POWER := 0.78
const JUMP_POWER := 0.927

const HOLES: Array = [
	{"name": "Welcome Mat", "par": 2, "floor": -0.35},
	{"name": "Rolling Pin Ramps", "par": 2, "floor": -0.35},
	{"name": "Cupcake Bumpers", "par": 3, "floor": -0.35},
	{"name": "Donut Loop", "par": 3, "floor": -0.35},
	{"name": "Windmill Whisk", "par": 3, "floor": -0.35},
	{"name": "Croissant Curve", "par": 2, "floor": -0.35},
	{"name": "Sprinkle Slope", "par": 3, "floor": -0.65},
	{"name": "Oven Door Drawbridge", "par": 3, "floor": -0.35},
	{"name": "Mixing Bowl Funnel", "par": 2, "floor": -1.25},
	{"name": "Conveyor Cookies", "par": 3, "floor": -0.35},
	{"name": "Baguette Bridge", "par": 3, "floor": -0.35},
	{"name": "Pie Crust Maze", "par": 4, "floor": -0.35},
	{"name": "Sugar Cube Stairs", "par": 3, "floor": -0.80},
	{"name": "Coffee Cup Jump", "par": 3, "floor": -0.35},
	{"name": "Macaron Gates", "par": 3, "floor": -0.35},
	{"name": "Cake Tier Spiral", "par": 4, "floor": -0.35},
	{"name": "Piping Bag Tubes", "par": 3, "floor": -0.35},
	{"name": "Sunshine Finale", "par": 4, "floor": -0.35},
]


static func hole_count() -> int:
	return HOLES.size()


static func hole_name(hole: int) -> String:
	return str(HOLES[hole - 1]["name"])


static func par(hole: int) -> int:
	return int(HOLES[hole - 1]["par"])


static func floor_y(hole: int) -> float:
	return float(HOLES[hole - 1]["floor"])


static func glb_path(hole: int) -> String:
	return "res://assets/minigolf/hole%02d/hole%02d.glb" % [hole, hole]


static func putt_speed(power: float) -> float:
	return lerpf(MIN_PUTT_SPEED, MAX_PUTT_SPEED, clampf(power, 0.0, 1.0))


static func power_for_speed(speed: float) -> float:
	return clampf((speed - MIN_PUTT_SPEED) / (MAX_PUTT_SPEED - MIN_PUTT_SPEED), 0.02, 1.0)


static func stars_for(par_n: int, strokes: int, holed: bool) -> int:
	if not holed:
		return 1
	if strokes <= par_n:
		return 3
	if strokes == par_n + 1:
		return 2
	return 1


static func result_name(par_n: int, strokes: int, holed: bool) -> String:
	if not holed:
		return "Next hole"
	if strokes <= 1:
		return "Hole-in-One"
	var over := strokes - par_n
	if over <= -2:
		return "Eagle"
	if over == -1:
		return "Birdie"
	if over == 0:
		return "Par"
	if over == 1:
		return "Bogey"
	if over == 2:
		return "Double Bogey"
	return "Triple Bogey"
