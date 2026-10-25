extends "res://tests/test_viewmodel.gd"
func run() -> void:
	p=Player.new();root.add_child(p);p.set_process(false);p.set_physics_process(false);p.cam=Camera3D.new();p.add_child(p.cam)
	vm=Viewmodel.new();vm.player=p;vm.detail_enabled=true;p.cam.add_child(vm);vm.set_process(false)
	for kind:String in ["drink","treat","hammer","reach"]:
		vm.begin_work(kind,2);vm.update_work(1);vm._process(0)
		var max_x:=0.0;var max_y:=0.0;var maximum:=Vector3.ZERO
		for point in skin_vertices(vm._right):
			var local:Vector3=vm._sl_r.transform.affine_inverse()*(vm._right.transform*point)
			if local.z<0 or local.z>.15:continue
			max_x=maxf(max_x,absf(local.x));max_y=maxf(max_y,absf(local.y))
			if local.length()>maximum.length():maximum=local
		print("CUFF ",kind," ",max_x," ",max_y," ",maximum)
		vm.end_work(false)
	p.free();await process_frame;quit()
