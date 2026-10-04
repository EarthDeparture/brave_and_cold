extends "res://tests/test_viewmodel.gd"
## Imported skin contact throughout the complete rifle-to-bolt transition.
const STOCK:Array=[[-.402,-.044,.0165,.066],[-.380,-.043,.0185,.064],[-.320,-.037,.0195,.056],[-.260,-.028,.0195,.048],[-.200,-.018,.019,.042],[-.140,-.011,.0185,.039],[-.080,-.007,.018,.037],[-.020,-.004,.0185,.038],[.050,0,.019,.040],[.120,.004,.0195,.040],[.220,.008,.0195,.036],[.340,.012,.019,.032],[.460,.016,.0185,.029],[.560,.018,.018,.026],[.600,.019,.0165,.0235]]
func stock_overlap(point:Vector3)->float:
 var axial:float=-point.z
 for i in STOCK.size()-1:
  var a:Array=STOCK[i];var b:Array=STOCK[i+1]
  if axial<a[0] or axial>b[0]:continue
  var k:float=(axial-a[0])/(b[0]-a[0]);var center:float=lerpf(a[1],b[1],k);var width:float=lerpf(a[2],b[2],k);var height:float=lerpf(a[3],b[3],k)
  var radial:float=pow(pow(absf(point.x/width),2.8)+pow(absf((point.y-center)/height),2.8),1/2.8)
  return maxf(0,(1-radial)*minf(width,height))
 return 0
func run()->void:
 p=Player.new();root.add_child(p);p.set_process(false);p.cam=Camera3D.new();p.add_child(p.cam)
 vm=load("res://tests/visual/fixtures/pre_clearance_viewmodel.gd").new() if OS.get_cmdline_user_args().has("baseline=1") else Viewmodel.new();vm.player=p;p.cam.add_child(vm);vm.set_process(false)
 var rows:Array=[];var worst:Dictionary={"overlap":0.0};var output:="res://shots/grip-route-followup/grip-current.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("report="):output=arg.trim_prefix("report=")
 for gloved in [false,true]:
  for i in range(141):
   var time:float=.38+i*.005;pose("rifle",-1,time)
   var inverse:=vm._rifle.transform.affine_inverse();var penetration:=0.0
   for point in skin_vertices(vm._right,gloved):penetration=maxf(penetration,stock_overlap(inverse*(vm._right.transform*point)))
   var row:Dictionary={"time":time,"gloved":gloved,"overlap":penetration};rows.append(row)
   if penetration>worst.overlap:worst=row
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
 var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(rows,"\t"));f.close()
 print("GRIP_TRANSITION_COMPLETE worst=",JSON.stringify(worst));p.free();quit(0 if worst.overlap<.0035 else 1)
