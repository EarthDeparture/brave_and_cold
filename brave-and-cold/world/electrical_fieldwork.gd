class_name ElectricalFieldwork
extends Node3D
## Optional resilience outing on the existing route. No new solid ground geometry.
var world: Node3D
var service := ElectricalService.new()
var packet: Node3D
var controller_stock: Node3D
var cable: Node3D
var slate: Node3D
var issue_label: Label3D
const DEPOT_LOCAL := Vector3(1.60,1.402,.75)

func build(w: Node3D, saved: Dictionary) -> void:
	world=w;service.restore(saved)
	# Sealed issue packet retained inside the existing pivoted lid. It follows
	# opening/closing and cannot float above the box when the lid moves away.
	packet=prop("spare_packet",world.first_week._lid,Vector3(-.17,-.015,.26));packet.rotation.x=PI
	cable=prop("dc_cable",world.first_week.models[2],Vector3(0,.06,-.35))
	var ground:float=world.terrain.data.get_height(cable.global_position)
	cable.global_position.y=ground+.004
	if not world.stores.is_empty():
		var kit:=prop("controller_case",world.stores[0],DEPOT_LOCAL)
		controller_stock=kit.find_child("ControllerStock",true,false) as Node3D
		slate=prop("delivery_slate",world.stores[0],Vector3(1.60,1.402,.07))
		issue_label=Label3D.new();slate.add_child(issue_label);issue_label.position=Vector3(0,.023,.018);issue_label.rotation.x=-PI/2
		issue_label.font_size=26;issue_label.pixel_size=.0008;issue_label.outline_size=0;issue_label.shaded=true
		issue_label.modulate=Color(.18,.22,.18)
	update_presentation()

func prop(id: String, parent: Node3D, local: Vector3) -> Node3D:
	var n:Node3D=(load("res://assets/electrical_fieldwork/"+id+".glb") as PackedScene).instantiate()
	parent.add_child(n);n.position=local;return n

func update_presentation() -> void:
	if packet!=null:packet.visible=not service.packet_claimed
	if cable!=null:cable.visible=not service.cable_claimed
	if controller_stock!=null:controller_stock.visible=not service.controller_claimed
	if issue_label!=null:
		var elapsed_days:=int(floor((world.opening_state.last_s+world.opening_state.calendar_origin_s)/86400))
		issue_label.text="%s\n%s"%["ISSUED • CASE EMPTY" if service.controller_claimed else "READY FOR COLLECTION","NEXT LOAD: UNCONFIRMED" if elapsed_days>=1 else "NEXT LOAD: EXPECTED TOMORROW"]

func actions() -> Array:
	var op:LookoutOpening=world.opening
	var out:Array=[op._action(world.first_week.models[1].to_global(Vector3(.35,.85,.30)),"Read electrical crew issue record",read_record,0,.045)]
	out.append(op._action(op.home_point(Vector3(.95,.88,-1.35)),"Read winter service issue • optional fieldwork",read_record,0,.045))
	if not service.packet_claimed:out.append(op._action(packet.global_position+Vector3.UP*.05,"Collect sealed fuse and connector packet",claim_packet,3,.04))
	if slate!=null:out.append(op._action(slate.global_position+Vector3.UP*.025,"Read depot delivery slate",read_record,0,.035))
	if controller_stock!=null and not service.controller_claimed:
		out.append(op._action(world.stores[0].to_global(DEPOT_LOCAL+Vector3.UP*.08),"Collect matched winter controller",claim_controller,3,.035))
	if not service.cable_claimed:
		out.append(op._action(cable.global_position+Vector3.UP*.20,"Test and recover isolated spur cable" if world.first_week.feeder_isolated else "Spur cable • isolate feeder first",recover_cable,6,.04))
	var s:SolarSupply=op.state.solar
	var at:Vector3=op.solar_site.to_global(Vector3(1.02,1,.63))
	if op.state.repair_stage==3:
		if not s.winter_controller:out.append(op._action(at,"Fit winter controller • tested lead + sealed connectors",fit_controller,8,.035))
		if not s.fuse_ok:out.append(op._action(at,"Replace diagnosed open DC fuse",func()->void:repair("fuse"),4,.04))
		if not s.cable_ok:out.append(op._action(at,"Replace diagnosed damaged DC cable",func()->void:repair("cable"),6,.045))
	return out

func claim_packet() -> void:
	var ok:=service.claim_packet(world.inv);update_presentation()
	world._say("One fuse and a sealed connector pair signed out. Keep the fuse as a spare." if ok else "Already issued, or make room for both parts; the packet stays here.")
func claim_controller() -> void:
	var ok:=service.claim_controller(world.inv);update_presentation()
	if ok:world.opening_state.depot_visited=true
	world._say("Matched controller signed out. Bring the sealed connectors and tested spur cable to the compound array." if ok else "Already issued, or pack full; the controller stays in its case.")
func recover_cable() -> void:
	var ok:=service.recover_cable(world.inv,world.first_week.feeder_isolated);update_presentation()
	world._say("Spare lead tested and recovered. The disconnected crew branch remains isolated." if ok else "Isolate the spur, bring the service kit and make room. This cable can be recovered only once.")
func fit_controller() -> void:
	# Settle preceding time with the old hardware before the installation boundary.
	world.opening.advance(0)
	var ok:=service.fit_controller(world.inv,world.opening_state.solar,world.opening_state.repair_stage==3)
	world.opening.update_presentation()
	world._say("Winter controller fitted and tested. Conversion improved; reserve energy and outside outages are unchanged. Daylight still supplies the charge." if ok else "Commission the relay first; need service kit, controller, sealed connectors and a tested lead (carried or already installed). Nothing spent.")
func repair(fault: String) -> void:
	world.opening.advance(0)
	var ok:=service.repair(world.inv,world.opening_state.solar,fault,world.opening_state.repair_stage==3)
	world.opening.update_presentation()
	world._say("Diagnosed DC fault repaired. Daylight can charge the reserve; no battery energy was added." if ok else "Exact fault, matching part, commissioned relay and service kit required. Nothing spent.")
func read_record() -> void:
	var shipment:="Tomorrow's delivery is still on the slate." if world.clock.day==1 else "Tomorrow's load has no confirmed departure. Nobody has crossed it out; nobody has signed it in either. The stock already here is all we can count."
	var text:="KESTREL 07 • WINTER SERVICE ISSUE\n\nMara's handover\nThe transfer relay is a separate repair. The compound array already has a working regulator; winter fitting is optional. Do not wait for these spares to commission the relay.\n\nCounted stock\nCrew reserve on the logging track: one matched DC fuse and one sealed connector pair. %s\nNorth Ridge Supply counter: one matched winter controller. %s\nCrew-spur cabinet: one recoverable test lead. %s\n\nRefit\nIsolate the unused crew feeder with the service kit before recovering its cable. Fit the matched controller, connectors and cable at the compound array, using the same kit. The winter regulator improves conversion from 78%% to 86%% in service; it does not add panels or a bigger battery. Keep the fuse for an actual open-fuse fault.\n\nBefore travelling\nRead local power status. Night and covered panels are not broken hardware. Brush snow and switch off unnecessary loads first. A broken cable needs a cable, an open fuse needs a fuse, and a failed controller needs the matched refit. Supplies do not replenish after collection.\n\nDelivery slate\n%s\n\nMara: Please leave the crew branch isolated. If the next crew gets through, they can sign it back in. June has enough circuits to keep track of today."%["Signed out." if service.packet_claimed else "Sealed packet available.","Issued; case empty." if service.controller_claimed else "Waiting in its fitted case.","Recovered; branch remains isolated." if service.cable_claimed else "Still at the cabinet.",shipment]
	text+="\n\nPreviously fitted lead\nIf you already used the recovered lead to repair the solar cable, the refit reuses that installed, tested lead. It neither asks for a second cable nor returns the first to your pack. A matched refit can also replace a failed controller and cable together."
	world.reading.open("North Ridge • counted electrical stock",text,world.player,world.hud)
func to_dict() -> Dictionary:return service.to_dict()
