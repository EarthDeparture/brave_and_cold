extends SceneTree
## Actual finite stock, reload visibility and continuous cache hinge motion.
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func run()->void:
	var c:=Clinic.new();root.add_child(c)
	c._dressing=(load(Clinic.MODEL) as PackedScene).instantiate();c.add_child(c._dressing)
	c.rear=Node3D.new();c.add_child(c.rear);c._bind_stock_visuals()
	var w:=Node3D.new();root.add_child(w);c.build_stock(w)
	check(c._dressing_units[4].visible,"last dressing is visible for five real bandages")
	c.stock[0].remove("bandage",1)
	check(not c._dressing_units[4].visible and c._dressing_units[3].visible,"withdrawal updates one physical dressing immediately without world polling")
	c.stock[0].put("bandage",1,1,0);check(c._dressing_units[4].visible,"deposit restores the physical dressing immediately")
	c.stock[1].remove("antiseptic",1)
	check(c._antiseptic_units[0].visible and not c._antiseptic_units[1].visible,"antiseptic units follow finite quantity")
	c.stock[1].remove("antibiotics",1);check(not c._medicine_unit.visible,"last antibiotic withdrawal hides its actual package")
	var saved:=c.stock[0].to_dict();c.stock[0].remove("bandage",5);c.stock[0].remove("rag",4)
	check(not c._stock_groups[0].visible,"empty shelf hides its grouped reserves")
	c.stock[0].load_dict(saved);check(c._stock_groups[0].visible and c._dressing_units[4].visible,"inventory reload refreshes previously emptied shelf")
	var route:=FirstWeekRoute.new();root.add_child(route)
	route.models.append(Node3D.new());route.add_child(route.models[0])
	route.models.append((load("res://assets/first_week/field_cache.glb") as PackedScene).instantiate());route.add_child(route.models[1])
	route._lid=route.models[1].find_child("CacheLid",true,false)
	route.cache=StorageChest.new();route.cache.visual_enabled=false;route.add_child(route.cache);route._bind_cache_visuals()
	route.cache.contents_changed.connect(route._update_cache_stock)
	route.cache.put("clean_water",2,1,0);route.cache.put("bandage",2,1,0);route.cache.put("beans",2,1,0);route.cache.put("matches",4,1,0)
	check(route._cache_stock_nodes[0].visible,"real water makes cached stock visible")
	route.cache.remove("clean_water",2);check(not route._cache_stock_nodes[0].visible,"last water withdrawal hides its props without per-frame searches")
	route.cache.load_dict({"c":{"clean_water":1}})
	check(route._cache_stock_nodes[0].visible and not route._cache_stock_nodes[1].visible,"cache reload refreshes all four stock groups")
	route.cache.want_open=true;route._process(.02);var opening:float=route._lid.rotation.x
	check(absf(opening)<deg_to_rad(100)*.052,"lid accelerates gently from closed")
	for i in 8:route._process(.02)
	var before:float=route._lid.rotation.x;route.cache.want_open=false
	check(route._lid.rotation.x==before,"reversing the lid target does not snap the hinge")
	route._process(.02);check(route._lid.rotation.x>before,"reversed lid closes continuously")
	for i in 30:route._process(.02)
	check(is_zero_approx(route._lid.rotation.x),"lid reaches exact closed endpoint")
	route.cache.want_open=true
	for i in 30:route._process(.02)
	check(is_equal_approx(route._lid.rotation.x,-deg_to_rad(100)),"lid reaches exact open endpoint")
	print("ENCOUNTER_PRESENTATION_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
