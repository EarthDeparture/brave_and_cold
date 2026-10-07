class_name InfectedGait
extends RefCounted
## Presentation-only, world-space stance anchors with two-bone leg solving.
## The actor's collision movement supplies distance and never follows this pose.
var anchors:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var planted:Array[bool]=[false,false]
var plant_heading:Array[float]=[0.0,0.0]
var last_heading:=0.0
var active:=false
var ankle_bases:Array[Basis]=[Basis.IDENTITY,Basis.IDENTITY]
var floor_bases:Array[Basis]=[Basis.IDENTITY,Basis.IDENTITY]
const THIGH:=Vector3(0,-.44,.01)
const CALF:=Vector3(0,-.39,-.025)
const ANKLE_HEIGHT:=.0785

func reset()->void:
	planted=[false,false];active=false;ankle_bases=[Basis.IDENTITY,Basis.IDENTITY];floor_bases=[Basis.IDENTITY,Basis.IDENTITY]

func solve(actor:Zombie,phase:float,stride:float)->void:
	var heading:=actor.global_rotation.y
	if active and absf(wrapf(heading-last_heading,-PI,PI))>.12:planted=[false,false]
	last_heading=heading;active=true
	var model:Node3D=actor._model
	var scale_y:=model.global_basis.get_scale().y
	model.position.y=0
	var targets:Array[Vector3]=[]
	var body_offset:=0.0
	for i in 2:
		if planted[i] and absf(wrapf(heading-plant_heading[i],-PI,PI))>.12:planted[i]=false
		var u:=fposmod(phase/TAU+i*.5,1)
		var stance:=u<.60
		var swing:=(u-.60)/.40
		var local_z:=stride*(u-.30) if stance else lerpf(stride*.30,-stride*.30,smoothstep(0,1,swing))
		var x:=(-1.0 if i==0 else 1.0)*.10
		var target:=model.to_global(Vector3(x,0,local_z-.015))
		if stance:
			if not planted[i]:
				target.y=actor._corpse_floor(target)+ANKLE_HEIGHT*scale_y
				anchors[i]=target
				plant_heading[i]=heading
				floor_bases[i]=floor_basis(actor,target)
			target=anchors[i]
		else:
			target.y=actor._corpse_floor(target)+(ANKLE_HEIGHT+.065*sin(PI*swing))*scale_y
			floor_bases[i]=model.global_basis.orthonormalized()
		planted[i]=stance
		targets.append(target)
		# Preserve an adult-length stride without stretching the leg. The hip
		# follows the most restrictive foot, producing a small natural bob
		# instead of shortening the stride into a rapid shuffle.
		var local:=model.to_local(target)
		var horizontal:=Vector2(local.x-x,local.z).length()
		var reach:=(THIGH.length()+CALF.length())*.985
		var vertical:=sqrt(maxf(.01,reach*reach-horizontal*horizontal))
		body_offset=minf(body_offset,(local.y+vertical-.92)*model.scale.y)
	model.position.y=maxf(body_offset,-.20*model.scale.y)
	for i in 2:
		var x:=(-1.0 if i==0 else 1.0)*.10
		var target:=targets[i]
		var hip:=Vector3(x,.92,0)
		var offset:=model.to_local(target)-hip
		var l1:=THIGH.length();var l2:=CALF.length()
		var distance:=clampf(offset.length(),absf(l1-l2)+.001,l1+l2-.001)
		var direction:=offset.normalized()
		var bend:=Vector3.FORWARD-direction*Vector3.FORWARD.dot(direction)
		if bend.length_squared()<.001:bend=Vector3.RIGHT-direction*Vector3.RIGHT.dot(direction)
		bend=bend.normalized()
		var along:=(l1*l1+distance*distance-l2*l2)/(2*distance)
		var knee:=hip+direction*along+bend*sqrt(maxf(0,l1*l1-along*along))
		var reached:=hip+direction*distance
		var upper:=Basis(Quaternion(THIGH.normalized(),(knee-hip).normalized()))
		var lower:=Basis(Quaternion(CALF.normalized(),(upper.inverse()*(reached-knee)).normalized()))
		actor._legs[i].rotation=upper.get_euler()
		actor._knees[i].rotation=lower.get_euler()
		# Parent rotations are cancelled at the ankle, retaining the boot's
		# original rest orientation and sole. This does not move the actor.
		ankle_bases[i]=(upper*lower).inverse()*model.global_basis.orthonormalized().inverse()*floor_bases[i]

func floor_basis(actor:Zombie,p:Vector3)->Basis:
	var dx:=clampf((actor._corpse_floor(p+Vector3.RIGHT*.08)-actor._corpse_floor(p-Vector3.RIGHT*.08))/.16,-.4,.4)
	var dz:=clampf((actor._corpse_floor(p+Vector3.BACK*.08)-actor._corpse_floor(p-Vector3.BACK*.08))/.16,-.4,.4)
	var up:=Vector3(-dx,1,-dz).normalized()
	var back:=actor.global_basis.z.normalized()
	var right:=up.cross(back).normalized()
	return Basis(right,up,right.cross(up).normalized())
