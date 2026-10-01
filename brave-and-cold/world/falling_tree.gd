class_name FallingTree
extends Node3D
## Visual-only tree that tips over away from the player, then calls on_land.

var _mi: MeshInstance3D
var _axis := Vector3.RIGHT
var _basis := Basis()
var _origin := Vector3.ZERO
var _dir := Vector3.FORWARD
var _h := 10.0
var _dur := 1.5
var _t := 0.0
var _cb: Callable


static func burst(parent: Node, pos: Vector3, amount: int, speed: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.6
	p.explosiveness = 0.95
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 4
	sm.rings = 2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.93, 0.96, 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = m
	p.mesh = sm
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6.0, 0)
	p.emitting = true
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = pos


func setup(mesh: Mesh, mat: Material, origin: Vector3, basis: Basis, dir: Vector3, h: float, on_land: Callable) -> void:
	_origin = origin
	_basis = basis
	_dir = Vector3(dir.x, 0, dir.z).normalized()
	_axis = Vector3.UP.cross(_dir).normalized()
	_h = h
	_dur = 1.1 + 0.06 * h
	_cb = on_land
	_mi = MeshInstance3D.new()
	_mi.mesh = mesh
	_mi.material_override = mat
	_mi.top_level = true
	add_child(_mi)
	_mi.global_transform = Transform3D(basis, origin)
	burst(self, origin + Vector3.UP * h * 0.75, 40, 3.0)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / _dur, 0.0, 1.0)
	var ang := deg_to_rad(88.0) * pow(k, 2.3)
	_mi.global_transform = Transform3D(Basis(_axis, ang) * _basis, _origin)
	if k >= 1.0:
		burst(get_parent(), _origin + _dir * _h * 0.8 + Vector3.UP * 0.4, 60, 4.0)
		if _cb.is_valid():
			_cb.call()
		queue_free()
