extends SceneTree
var checks:=0
var failures:=0
var created:=0
var reserve_ids:Array[int]=[]
var pop:Population
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func make(pos:Vector3,id:int)->Zombie:
	created+=1;reserve_ids.append(id)
	var z:=Zombie.new();root.add_child(z);z.set_process(false)
	z._model=Node3D.new();z.add_child(z._model);z._id=id;z.position=pos;z.add_to_group("hostile")
	pop.world_list.append(z);return z
func run()->void:
	var player:=Player.new();root.add_child(player);player.set_process(false);player.set_physics_process(false)
	pop=Population.new();root.add_child(pop);pop.player=player;pop.make_zombie=make;pop.reserve_target=3
	var identity:int=pop._next_id
	pop._prepare_reserve()
	check(created==1 and pop.pool.size()==1,"one reserve construction per preparation step")
	check(pop.count_alive()==0 and pop.all_alive().is_empty() and pop.world_list.is_empty(),"reserve nodes do not create population or enter save data")
	check(not pop.pool[0].visible and not pop.pool[0].is_in_group("hostile") and not pop.pool[0].is_processing(),"reserve node has no visible model, AI or hostile membership")
	pop._prepare_reserve();pop._prepare_reserve();pop._prepare_reserve()
	check(created==3 and pop.pool.size()==3 and pop.reserve_target==0,"resource preparation stops at its bounded target")
	check(pop._next_id==identity and reserve_ids==[-1,-2,-3],"preparation leaves living identity allocation unchanged")
	var z:Zombie=pop.acquire(Vector3(10,0,0));pop.active.append(z);pop.world_list.append(z)
	check(created==3 and z._id==identity and pop._next_id==identity+1,"first living acquisition reuses resources and receives its proper identity")
	check(pop.count_alive()==1 and pop.all_alive().size()==1,"reuse materializes exactly one living member")
	pop.reserve_target=4;pop._prepare_reserve()
	check(created==3,"nearby threat defers background construction")
	z.position.x=100;pop._prepare_reserve()
	check(created==4,"quiet distance resumes bounded preparation")
	print("POPULATION_RESERVE_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
