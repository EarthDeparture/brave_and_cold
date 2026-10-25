extends SceneTree
## Natural habitat, nutrition, cover, field plan and actual save restoration.
var checks:=0
var failures:=0
class CoveredForest extends ForestScatter:
	var cover:=0
	func trunks_on_segment(_ax:float,_az:float,_bx:float,_bz:float)->int:return cover
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for c:Node in n.get_children():freeze(c)
func build(saved:Dictionary={})->Node3D:
	SaveGame.pending=saved;seed(20261004);var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 600:
		await process_frame
		if w.reading!=null and w.collapse!=null:break
	freeze(w);w.out_path="test-no-autosave";w._frames=100;return w
func run()->void:
	create_timer(180).timeout.connect(func()->void:quit(2))
	Inventory.infinite=false
	var inv:=Inventory.new();var needs:=Needs.new();inv.needs=needs
	for raw:String in Inventory.ITEMS:
		if not Inventory.ITEMS[raw].get("raw",false):continue
		var cooked:String=Inventory.ITEMS[raw].cooked
		check(Inventory.ITEMS[raw].kcal==Inventory.ITEMS[cooked].kcal,"cooking conserves portion energy: "+raw)
		inv.add(raw);var before:float=needs.calories;var count:=inv.count(raw)
		check(inv.use(raw).begins_with("Cook") and inv.count(raw)==count and needs.calories==before,"raw consumption requires cooking without spending stock: "+raw)
	var c:=Node3D.new();root.add_child(c);var c2:=Node3D.new();root.add_child(c2)
	Carcass.advance_food(c,18000)
	for i in 5:Carcass.advance_food(c2,3600)
	check(Carcass.age_s(c)==18000 and Carcass.food_age(c)==6300 and Carcass.age_s(c2)==Carcass.age_s(c),"sleep-size and split updates conserve carcass food and scent clocks")
	Carcass.advance_food(c,-100);check(Carcass.age_s(c)==18000,"negative time cannot reverse scent age")
	Carcass.wind_dir=Vector2.RIGHT
	check(Carcass.smelled_by(c,Vector3(140,0,0)) and not Carcass.smelled_by(c,Vector3(-45,0,0)),"aged scent retains wind-dependent detection")
	c.free();c2.free()
	var deer:=Deer.new();var player:=Player.new();root.add_child(player);root.add_child(deer);freeze(player);freeze(deer)
	var forest:=CoveredForest.new();deer.forest=forest;deer.player=player;player.position=Vector3(30,1.7,0)
	check(deer._sees_player(),"standing player visible in open hunting range")
	forest.cover=2;check(not deer._sees_player(),"two intervening trunks hide a distant stalker")
	forest.cover=0;player.crouching=true;check(not deer._sees_player(),"crouching reduces visual detection range")
	deer._on_noise(player.position,40,player);check(deer.state==Deer.State.ALERT,"audible noise still alerts prey concealed from sight")
	player.position.x=3;check(deer._sees_player(),"very close prey cannot be hidden by cover")
	deer.free();player.free();forest.free()
	var w:Node3D=await build();var path:Array=w.fire_lookout.site.path.points_world_xyz
	for value:int in [20261004,20261005,20261006]:
		for animal:Deer in w.deer:animal.free()
		w.deer.clear();w.opening_state.seed_value=value;w._spawn_route_deer(6)
		var valid:bool=w.deer.size()==6
		for animal:Deer in w.deer:
			animal.set_process(false);var p:=Vector2(animal.position.x,animal.position.z);var nearest:=INF
			for row:Array in path:nearest=minf(nearest,p.distance_to(Vector2(row[0],row[2])))
			valid=valid and nearest<170 and p.distance_to(Vector2(w.fire_lookout.position.x,w.fire_lookout.position.z))>=80 and is_nan(w.ice.ice_at(p.x,p.y))
		check(valid,"six natural finite prey near logging-route habitat: seed "+str(value))
	var text:String=w.opening.field_plan_text()
	check(text.contains("Inspect") and text.contains("FIELD PLAN") and text.contains("Walkie"),"opening field plan gives work and actual departure information")
	w.opening_state.repair_stage=1;w.opening_state.parts_claimed=true
	check(w.opening.field_plan_text().contains("Retrieve the relay"),"claimed part outside the pack does not produce false carry advice")
	w.opening_state.repair_stage=3;w.opening.fuel_s=3600
	check(w.opening.field_plan_text().contains("Choose your next outing") and w.opening.field_plan_text().contains("1.0 game hours"),"completed assignment transitions to actual independent survival stock")
	var killed:Deer=w.deer[0];killed.hit(999,killed.position);Carcass.advance_food(killed,7200)
	var snapshot:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	check(snapshot.deer.size()==5 and snapshot.carcasses.size()==1 and snapshot.carcasses[0].scent_age_s==7200,"snapshot retains five living animals and one aged kill")
	w.queue_free();await process_frame;await process_frame;w=await build(snapshot)
	check(w._alive_list(w.deer).size()==5 and get_nodes_in_group("carcasses").size()==1,"real world reload preserves finite prey instead of refilling habitat")
	var carcass:Node3D=get_nodes_in_group("carcasses")[0]
	check(Carcass.age_s(carcass)==7200 and Carcass.food_age(carcass)==2520,"real world reload preserves scent and edible-food age separately")
	var audio:=GameAudio.new();var no_repeat:=true
	for material:String in ["wood","ice"]:
		var previous:AudioStream=null
		for i in 50:
			var next:AudioStream=audio._surface_step(material);no_repeat=no_repeat and next!=previous;previous=next
	check(no_repeat,"surface footsteps never repeat a sample consecutively")
	audio.free();w.queue_free();await process_frame;await process_frame;SaveGame.pending={}
	print("OPENING_QUALITY_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
