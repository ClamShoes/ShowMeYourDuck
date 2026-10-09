class_name CardJuice
extends RefCounted
## Spring + pop maths for the Balatro-style card feel. Pure functions — no node state.

## Pop length: the envelope reaches exactly 0 here, so a pop always fully settles.
const POP_DUR := 0.4
## Oscillation speeds (rad/s) for the pop's scale and rotation wobble.
const POP_SCALE_FREQ := 50.8
const POP_ROT_FREQ := 40.8
## Larger frame steps make the springs unstable (semi-implicit Euler).
const MAX_DT := 1.0 / 30.0


## One damped-spring step. Returns Vector2(value, velocity).
static func spring(x: float, v: float, target: float, k: float, damping: float, dt: float) -> Vector2:
	dt = minf(dt, MAX_DT)
	v += ((target - x) * k - v * damping) * dt
	return Vector2(x + v * dt, v)


## Vector2 spring step. Returns [value, velocity].
static func spring_v2(x: Vector2, v: Vector2, target: Vector2, k: float, damping: float, dt: float) -> Array:
	dt = minf(dt, MAX_DT)
	v += ((target - x) * k - v * damping) * dt
	return [x + v * dt, v]


## Decaying wobble: starts at 0, overshoots, settles to exactly 0 at POP_DUR.
static func pop(amp: float, freq: float, t: float) -> float:
	if t < 0.0 or t >= POP_DUR:
		return 0.0
	return amp * sin(freq * t) * pow(1.0 - t / POP_DUR, 3.0)
