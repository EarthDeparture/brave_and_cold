## Baseline rifle motion from checkpoint/pre-grip-transition-route-2026-10-04.
## Test-only fixture for matched transition captures; do not use in gameplay.
extends Viewmodel
func _pose_rifle(base: Transform3D) -> void:
	var kick := 0.0
	var bolt_roll := 0.0
	var bolt_slide := 0.0
	if _fire_t >= 0.0:
		var t := _fire_t
		kick = (t / 0.05) if t < 0.05 else exp(-(t - 0.05) * 7.0)
		kick *= _kick
		if _kick > 0.5:
			if t > 0.45 and t < 0.56:
				bolt_roll = 70.0 * _sstep((t - 0.45) / 0.11)
			elif t >= 0.56 and t < 0.68:
				bolt_roll = 70.0
				bolt_slide = 0.055 * _sstep((t - 0.56) / 0.12)
			elif t >= 0.68 and t < 0.78:
				bolt_roll = 70.0
				bolt_slide = 0.055 * (1.0 - _sstep((t - 0.68) / 0.10))
			elif t >= 0.78 and t < 0.9:
				bolt_roll = 70.0 * (1.0 - _sstep((t - 0.78) / 0.12))
	var ak := player.aim_k
	# The narrow aim FOV magnifies the gun along with the world. Slide it away along the view axis (the sight line IS the axis,
	# so the sight picture stays true) so the receiver does not swallow the bottom of the screen: farther the more you zoom.
	var mag := tan(deg_to_rad(Player.AIM_FOV * 0.5)) / tan(deg_to_rad(player.cam.fov * 0.5))
	var apos := Vector3(AIM_POS.x, AIM_POS.y, AIM_POS.z - 0.12 - 0.17 * clampf(mag - 1.0, 0.0, 1.8))
	var rpos := Vector3(0.075, -0.105, -0.45).lerp(apos, ak)
	var rb := Basis(Vector3.UP, deg_to_rad(30.0 * (1.0 - ak))) * Basis(Vector3.RIGHT, deg_to_rad(lerpf(-2.0, 2.7, ak)))   # +2.7 deg levels the sight line (rear->front slopes down 2.7 deg in the model)
	var butt := rpos + Vector3(0.0, 0.0, 0.4)
	var kb := Basis(Vector3.RIGHT, deg_to_rad(lerpf(9.0, 5.0, ak) * kick))
	var w := base * _about(butt, kb) * Transform3D(rb, rpos + Vector3(0.0, 0.01 * kick, 0.0))
	_rifle.transform = w
	_bolt.transform = w * Transform3D(Basis(Vector3.BACK, deg_to_rad(bolt_roll)), BOLT_ORIGIN + Vector3(0.0, 0.0, bolt_slide))
	# Dorsum faces outward at the stock; fingers curl under it, thumb opposes.
	var rz := Vector3(0.40, 0.60, 0.693).normalized()
	var ry := (Vector3.RIGHT - rz * Vector3.RIGHT.dot(rz)).normalized()
	var rx := ry.cross(rz).normalized()
	var trigger := w * Transform3D(Basis(rx, ry, rz), RIFLE_WRIST_R)
	var bz := Vector3(0.55, 0.0, 0.835).normalized()
	var bx := Vector3.DOWN
	var by := bz.cross(bx)
	var bw := _bolt.transform * Transform3D(Basis.IDENTITY, -BOLT_ORIGIN)
	var bolt_grip := bw * Transform3D(Basis(bx, by, bz), BOLT_WRIST)
	var reach := 0.0
	if _fire_t >= 0.40 and _fire_t < FIRE_LEN and _kick > 0.5:
		if _fire_t < 0.50:
			reach = _sstep((_fire_t - 0.40) / 0.10)
		elif _fire_t < 0.90:
			reach = 1.0
		else:
			reach = 1.0 - _sstep((_fire_t - 0.90) / (FIRE_LEN - 0.90))
	_right.transform = trigger.interpolate_with(bolt_grip, reach)
	_right.pose("Trigger", "Bolt", reach)
	_left.transform = w * Transform3D(Basis(Vector3.FORWARD, Vector3.DOWN, Vector3.LEFT), RIFLE_WRIST_L)
	_left.pose("Support")
	var arm := base * _about(butt, kb)
	_aim_sleeve(_sl_r, _right.transform, Vector3.ZERO, arm * Vector3(0.46, -0.56, 0.32))
	_aim_sleeve(_sl_l, _left.transform, Vector3.ZERO, arm * Vector3(-0.46, -0.58, 0.28))

