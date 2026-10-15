class_name InteriorLighting
extends Node3D
## One interior light standard for every enclosed building, in the TLD manner:
##  - a soft cool daylight pool through each window, scaled by what its glass,
##    boards and curtain let through (Opening.open_fraction);
##  - a sky-bounce fill so shaded corners stay readable but dim;
##  - a warm room bounce from the building's FireSource (stove glow).
## Buildings only hand over their openings, room centre/size and fire; GameWorld
## drives update() centrally from the sky and weather. Lights fade out beyond
## ACTIVE_R so distant buildings cost nothing.
const SUN_DAY := Color(.84, .90, 1.0)
const SKY_OVERCAST := Color(.80, .84, .90)
const SKY_NIGHT := Color(.30, .40, .64)
const BOUNCE_TINT := Color(.64, .56, .48)  # light that has hit timber floors and walls
const FIRE_COLOR := Color(1.0, .70, .46)  # warm, not red: TLD firelight is amber
const ACTIVE_R := 40.0
var openings: Array = []
var fire: FireSource
var spot_energy := 9.0  # tuned in shots/interiors (dark painted timber albedo needs it)
var fill_energy := 2.0
var fire_energy := 0.55
var _spots: Array[SpotLight3D] = []
var _fill: OmniLight3D
var _fire_fill: OmniLight3D

## room_center / fire_local are in the owner's local space; this node sits at the owner origin.
func build(p_openings: Array, room_center: Vector3, room_radius: float, p_fire: FireSource = null, fire_local := Vector3.INF, shadowed_windows := 1) -> void:
	add_to_group("interior_lighting")
	openings = p_openings.filter(func(o: Opening) -> bool: return o.kind == "window")
	fire = p_fire
	var shadows := shadowed_windows
	for o: Opening in openings:
		var inward: Vector3 = -(o.transform.basis.z).normalized()
		var spot := SpotLight3D.new(); add_child(spot)
		var from: Vector3 = o.position + inward * 0.55 + Vector3.UP * 0.25  # clear of thick log/plank walls so the wall cannot shadow its own window
		var aim: Vector3 = o.position + inward * 2.4 + Vector3.DOWN * 1.35
		spot.transform = Transform3D(Basis.looking_at(aim - from, Vector3.UP), from)
		spot.spot_angle = 50.0; spot.spot_angle_attenuation = 1.8
		spot.spot_range = room_radius * 1.8; spot.spot_attenuation = 1.2
		spot.light_specular = 0.15
		spot.shadow_enabled = shadows > 0; shadows -= 1
		spot.shadow_blur = 2.5
		_fade(spot); _spots.append(spot)
	_fill = OmniLight3D.new(); add_child(_fill)
	_fill.position = room_center; _fill.omni_range = room_radius * 1.6; _fill.omni_attenuation = 0.7
	_fill.shadow_enabled = false; _fill.light_specular = 0.0; _fade(_fill)
	if fire != null and fire_local != Vector3.INF:
		_fire_fill = OmniLight3D.new(); add_child(_fire_fill)
		_fire_fill.position = fire_local + Vector3.UP * 1.5  # ceiling bounce above the stove
		_fire_fill.omni_range = room_radius * 1.7; _fire_fill.omni_attenuation = 0.8
		_fire_fill.light_color = FIRE_COLOR; _fire_fill.shadow_enabled = false; _fire_fill.light_specular = 0.0
		_fade(_fire_fill)

func _fade(light: Light3D) -> void:
	light.distance_fade_enabled = true; light.distance_fade_begin = ACTIVE_R; light.distance_fade_length = 10.0
	light.distance_fade_shadow = 20.0

## day 0..1 (1 = full daylight), overcast 0..1, precip 0..1.
func update(day: float, overcast: float, precip: float) -> void:
	var sky := SKY_NIGHT.lerp(SUN_DAY.lerp(SKY_OVERCAST, overcast), day)
	var direct := day * (1.0 - 0.35 * overcast) * (1.0 - 0.30 * precip)
	var through := 0.0
	for i in _spots.size():
		var k: float = (openings[i] as Opening).open_fraction()
		through += k
		var spot := _spots[i]
		spot.light_color = sky
		spot.light_energy = spot_energy * direct * k
		spot.visible = spot.light_energy > 0.01
	var open := clampf(through / maxf(1.0, float(openings.size())), 0.0, 1.0)
	_fill.light_color = sky.lerp(BOUNCE_TINT, 0.35)
	_fill.light_energy = fill_energy * (0.12 + 0.88 * day * (1.0 - 0.25 * overcast)) * (0.30 + 0.70 * open)
	if _fire_fill != null:
		var g := fire.glow()
		_fire_fill.light_energy = fire_energy * g
		_fire_fill.visible = g > 0.0

func window_count() -> int: return _spots.size()
func light_energy_total() -> float:
	var e := _fill.light_energy + (_fire_fill.light_energy if _fire_fill != null else 0.0)
	for s in _spots: e += s.light_energy
	return e
