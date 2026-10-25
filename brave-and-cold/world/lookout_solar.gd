class_name LookoutSolar
extends Node3D
## Ground equipment and maintenance; energy lives in saved LookoutAssignment.
var world: Node3D
var model: Node3D
var snow_surfaces: Array[Node3D]=[]
var display: Label3D
const LOCAL := Vector2(-8.5,2.2)
func build(w: Node3D, boundary: RefugeBoundary) -> void:
	world=w;w.fire_lookout.add_child(self)
	position=boundary.ground_local(LOCAL.x,LOCAL.y)
	model=(load("res://assets/lookout_solar/relay_solar_array.glb") as PackedScene).instantiate();add_child(model)
	# Only the physical rack footprint blocks contact; no pad, grading or path edits.
	boundary.obstacle_rects.append(Rect2(LOCAL.x-1.28,LOCAL.y-.54,2.56,1.14))
	for id:String in ["SnowLeft","SnowRight"]:
		var surface:=model.find_child(id,true,false) as Node3D
		if surface!=null:snow_surfaces.append(surface)
	display=Label3D.new();display.position=Vector3(1.02,.99,.587);display.font_size=28;display.pixel_size=.0008;display.outline_size=0;display.shaded=true;add_child(display)
	# Extend discrete rack feet to surveyed ground, without a blocking slab.
	for x:float in [-1.12,1.12]:
		for z:float in [-.42,.42]:
			var point:=to_global(Vector3(x,.18,z));var ground:float=world.terrain.data.get_height(point)
			var length:=maxf(.02,point.y-ground)
			var foot:=MeshInstance3D.new();var tube:=CylinderMesh.new();tube.top_radius=.045;tube.bottom_radius=.055;tube.height=length;tube.radial_segments=8;foot.mesh=tube
			var material:=StandardMaterial3D.new();material.albedo_color=Color(.23,.27,.25);material.roughness=.85;foot.material_override=material;add_child(foot);foot.global_position=Vector3(point.x,ground+length*.5,point.z)
	update_presentation()
func update_presentation() -> void:
	var s:LookoutAssignment=world.opening_state
	for surface:Node3D in snow_surfaces:
		surface.visible=s.solar.snow_cover>.025
		surface.scale.y=maxf(.025,s.solar.snow_cover)
	var condition:="WINTER REG" if s.solar.winter_controller else "CONNECTED"
	if not s.solar.fault().is_empty():condition="FAULT"
	display.text="PV %.0f W\n%s"%[s.solar_watts(),condition if s.repair_stage==3 else "ISOLATED"]
	display.modulate=Color(.67,.9,.69) if s.solar_watts()>0 else Color(.83,.78,.63)
func actions() -> Array:
	var out:Array=[world.opening._action(to_global(Vector3(1.02,1,.63)),"Inspect solar charger and reserve",read_status,0,.02)]
	if world.opening_state.solar.snow_cover>.025:
		out.append(world.opening._action(to_global(Vector3(0,1,.65)),"Brush snow from solar panels • %.0f%% covered"%(world.opening_state.solar.snow_cover*100),clear_snow,4,.03))
	return out
func clear_snow() -> void:
	world.opening_state.solar.clear_snow();update_presentation()
	world._say("Panels brushed clear. Daylight can reach the cells; clouds still reduce output.")
func read_status() -> void:
	world.opening.read_power_status()
