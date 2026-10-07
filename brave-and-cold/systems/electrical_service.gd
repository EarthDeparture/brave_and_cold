class_name ElectricalService
extends RefCounted
## Finite issue records. Collection and fitting commit only on action completion.
var packet_claimed := false
var controller_claimed := false
var cable_claimed := false

func claim_packet(inv: Inventory) -> bool:
	if packet_claimed:return false
	# Both items must fit together. No partial claim or transient inventory mutation.
	var candidate := Inventory.new();candidate.counts=inv.counts.duplicate();candidate.extra=inv.extra.duplicate()
	if not candidate.can_add("dc_fuse"):return false
	candidate.add("dc_fuse")
	if not candidate.can_add("sealed_connector"):return false
	inv.add("dc_fuse");inv.add("sealed_connector");packet_claimed=true;return true

func claim_controller(inv: Inventory) -> bool:
	if controller_claimed or not inv.can_add("winter_controller"):return false
	inv.add("winter_controller");controller_claimed=true;return true

func recover_cable(inv: Inventory, isolated: bool) -> bool:
	if not isolated or cable_claimed or inv.count("service_kit")<1 or not inv.can_add("dc_cable"):return false
	inv.add("dc_cable");cable_claimed=true;return true

func fit_controller(inv: Inventory, solar: SolarSupply, commissioned: bool) -> bool:
	# Replace the controller and lead, or reuse an already fitted, tested lead.
	# The fuse remains a separate circuit check. No reserve energy is invented.
	if not commissioned or solar.winter_controller or inv.count("service_kit")<1:return false
	var reuse_lead:=solar.tested_lead_installed and solar.cable_ok
	if not reuse_lead and inv.count("dc_cable")<1:return false
	for id: String in ["winter_controller","sealed_connector"]:
		if inv.count(id)<1:return false
	for id: String in ["winter_controller","sealed_connector"]:inv.remove(id)
	if not reuse_lead:inv.remove("dc_cable")
	solar.controller_ok=true;solar.cable_ok=true;solar.tested_lead_installed=true;solar.winter_controller=true;return true

func repair(inv: Inventory, solar: SolarSupply, fault: String, commissioned: bool) -> bool:
	if not commissioned or inv.count("service_kit")<1:return false
	var item := "dc_fuse" if fault=="fuse" else ("dc_cable" if fault=="cable" else "")
	var failed := not solar.fuse_ok if fault=="fuse" else (not solar.cable_ok if fault=="cable" else false)
	if item.is_empty() or not failed or inv.count(item)<1:return false
	inv.remove(item)
	if fault=="fuse":solar.fuse_ok=true
	else:solar.cable_ok=true;solar.tested_lead_installed=true
	return true

func to_dict() -> Dictionary:
	return {"packet_claimed":packet_claimed,"controller_claimed":controller_claimed,"cable_claimed":cable_claimed}
func restore(d: Dictionary) -> void:
	packet_claimed=bool(d.get("packet_claimed",false));controller_claimed=bool(d.get("controller_claimed",false));cable_claimed=bool(d.get("cable_claimed",false))
