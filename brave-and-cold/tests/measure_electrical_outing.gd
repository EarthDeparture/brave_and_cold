extends "res://tests/measure_opening_route.gd"
## Same actual controller outing, with the optional shoulder stops and refit.
## Direct interactions, no exploration/menu time; not a human or FPS benchmark.
func mark(id:String) -> void:
	super.mark(id)
	var sample:Dictionary=samples[-1]
	sample.electrical_issue=w.opening.electrical.service.to_dict()
	sample.winter_controller=w.opening_state.solar.winter_controller
	sample.tested_lead_installed=w.opening_state.solar.tested_lead_installed
	sample.fuse_pack=w.inv.count("dc_fuse")
	sample.controller_pack=w.inv.count("winter_controller")
	sample.cable_pack=w.inv.count("dc_cable")
	sample.connector_pack=w.inv.count("sealed_connector")
func chain(route:Array[Vector3]) -> bool:
	for point:Vector3 in route:
		if not await walk(point):return false
		var field:ElectricalFieldwork=w.opening.electrical
		var cache:Node3D=w.first_week.models[1]
		if not field.service.packet_claimed and Vector2(point.x,point.z).distance_to(Vector2(cache.global_position.x,cache.global_position.z))<6:
			if not await walk(cache.to_global(Vector3(0,0,.95))):return false
			if not await action("Collect sealed fuse"):return false
			if not field.service.packet_claimed:failed="Crew packet was not issued";return false
			mark("crew_spares_collected")
			if not await walk(point):return false
		var spur:Node3D=w.first_week.models[2]
		if not field.service.cable_claimed and Vector2(point.x,point.z).distance_to(Vector2(spur.global_position.x,spur.global_position.z))<6:
			if not await walk(spur.to_global(Vector3(0,0,.95))):return false
			if not await action("Isolate unused crew spur"):return false
			if not await walk(spur.to_global(Vector3(-.8,0,.7))):return false
			if not await walk(spur.to_global(Vector3(-.8,0,-.85))):return false
			if not await walk(spur.to_global(Vector3(0,0,-1.0))):return false
			if not await action("Test and recover isolated spur cable"):return false
			if not field.service.cable_claimed:failed="Isolated lead was not recovered";return false
			mark("spur_cable_recovered")
			if not await walk(spur.to_global(Vector3(-.8,0,-.85))):return false
			if not await walk(spur.to_global(Vector3(-.8,0,.7))):return false
			if not await walk(point):return false
	return true
func action(prefix:String) -> bool:
	# Enforce the real interaction radius, rather than the older diagnostic's 3 m.
	for entry:Dictionary in w.opening.actions():
		if String(entry.text).begins_with(prefix) and w.player.position.distance_to(entry.pos)>float(entry.r):
			failed="Action outside actual reach: "+prefix;return false
	var ok:bool=await super.action(prefix)
	if w.reading.is_open:w.reading.close()
	if not ok:return false
	if prefix=="Collect reserved transfer relay":
		if not await action("Collect matched winter controller"):return false
		if not w.opening.electrical.service.controller_claimed:failed="Controller issue failed";return false
		mark("winter_controller_collected")
	if prefix=="Verify backup transfer":
		# Walk around the rack's west side, preserving its physical collision.
		var tower:FireLookout=w.fire_lookout
		if not await walk(tower.to_global(Vector3(-10.5,0,.5))):return false
		if not await walk(tower.to_global(Vector3(-10.5,0,3.8))):return false
		if not await walk(w.opening.solar_site.to_global(Vector3(.6,0,1.5))):return false
		if not await action("Fit winter controller"):return false
		if not w.opening_state.solar.winter_controller:failed="Winter controller was not fitted";return false
		mark("winter_controller_fitted")
	return true
