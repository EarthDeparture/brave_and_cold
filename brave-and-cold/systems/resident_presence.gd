class_name ResidentPresence
extends RefCounted
## Cosmetic state only. Separate RNG never changes routes, loot or outbreak dates.
var blink:=0.0
var yaw:=0.0
var pitch:=0.0
var eye_uv:=Vector2.ZERO
var nod:=0.0
var blink_count:=0
var _rng:=RandomNumberGenerator.new()
var _wait:=3.0
var _blink_t:=-1.0
var _nod_t:=-1.0
var _elapsed:=0.0
var _last_phase:=-1
func initialize(seed_value:int)->void:
	_rng.seed=seed_value+7321;_wait=_rng.randf_range(2.5,6.0);_last_phase=TownResidentState.Phase.ORDINARY
func acknowledge()->void:_nod_t=0.0
func interrupt()->void:_nod_t=-1.0;nod=0
func step(delta:float,phase:int,focus:Vector3,attend:bool,talking:bool)->void:
	var dt:=clampf(delta,0,.25);_elapsed+=dt
	if phase!=_last_phase:
		_last_phase=phase;_blink_t=-1;blink=0;interrupt()
	var alive:=phase<TownResidentState.Phase.UNRESPONSIVE or phase==TownResidentState.Phase.DEPARTED
	if alive:
		var duration:=.29 if phase==TownResidentState.Phase.ILL else .19
		if _blink_t>=0:
			_blink_t+=dt
			# Fast closure, brief closed interval, gentler opening.
			blink=smoothstep(0,.055,_blink_t)*(1-smoothstep(duration*.47,duration,_blink_t))
			if _blink_t>=duration:_blink_t=-1;blink=0;_wait=_rng.randf_range(2.6,6.8)
		else:
			_wait-=dt
			if _wait<=0:_blink_t=0;blink_count+=1
	else:
		_blink_t=-1;blink=move_toward(blink,.64 if phase==TownResidentState.Phase.UNRESPONSIVE else (.96 if phase==TownResidentState.Phase.DEAD else 0.0),dt*5)
	if _nod_t>=0:
		_nod_t+=dt;nod=-.06*sin(PI*clampf(_nod_t/.8,0,1))
		if _nod_t>=.8:interrupt()
	var want_yaw:=.016*sin(_elapsed*.37);var want_pitch:=.006*sin(_elapsed*.53)
	var eye_yaw:=0.0;var eye_pitch:=0.0
	if alive and attend and focus.length_squared()>.001:
		eye_yaw=atan2(-focus.x,-focus.z);eye_pitch=atan2(focus.y,Vector2(focus.x,focus.z).length())
		want_yaw=clampf(eye_yaw,-.52,.52);want_pitch=clampf(eye_pitch,-.25,.22)
	if not alive:want_yaw=0;want_pitch=-.055 if phase==TownResidentState.Phase.UNRESPONSIVE else 0
	var ease:=1-exp(-dt*(2.2 if phase==TownResidentState.Phase.ILL else (5.0 if talking else 3.3)))
	yaw=lerpf(yaw,want_yaw,ease);pitch=lerpf(pitch,want_pitch,ease)
	var wanted:=Vector2.ZERO
	if alive and attend:
		# glTF V decreases toward the top of the authored eye cap.
		wanted=Vector2(clampf(-sin(eye_yaw-yaw)*.10,-.075,.075),clampf(sin(eye_pitch-pitch)*.10,-.035,.035))
	eye_uv=eye_uv.lerp(wanted,1-exp(-dt*12))
