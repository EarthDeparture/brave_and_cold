class_name Spoilage
extends RefCounted
## Food decay speed from the air temperature where the food is (TLD: food lasts
## longer out in the cold than inside a heated room). 1.0 = the shelf_h baseline.
const CURVE := [Vector2(-10, .25), Vector2(-2, .35), Vector2(2, .55), Vector2(8, .85), Vector2(15, 1.0), Vector2(25, 1.4)]

static func rate_c(temp_c: float) -> float:
	if temp_c <= CURVE[0].x: return CURVE[0].y
	for i in range(1, CURVE.size()):
		var a: Vector2 = CURVE[i - 1]; var b: Vector2 = CURVE[i]
		if temp_c <= b.x: return lerpf(a.y, b.y, (temp_c - a.x) / (b.x - a.x))
	return CURVE[CURVE.size() - 1].y
