class_name CookDisplay
extends Node3D
## Original skillet mesh; state comes from reserved food, never from decorative stock.
var raw_texture:Texture2D
var cooked_texture:Texture2D=preload("res://assets/cooking/meat_seared.png")
var pans:Array[Node3D]=[]
var foods:Array[Node3D]=[]
var marks:Array[Node3D]=[]
var materials:Array[StandardMaterial3D]=[]
func build(slots:int) -> void:
	for i in slots:
		var pan:Node3D=(load("res://assets/cooking/skillet_portion.glb") as PackedScene).instantiate()
		add_child(pan);pan.position.x=(i-(slots-1)*.5)*.34
		pans.append(pan);foods.append(pan.find_child("PanFood",true,false));marks.append(pan.find_child("SearMarks",true,false))
		var mi:=foods[i].find_child("Surface_food_marbling",true,false) as MeshInstance3D
		var material:StandardMaterial3D=mi.get_active_material(0).duplicate()
		mi.material_override=material;materials.append(material);raw_texture=material.albedo_texture
		for mesh:MeshInstance3D in pan.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=55
	sync([])
func sync(portions:Array) -> void:
	for i in foods.size():
		foods[i].visible=i<portions.size();marks[i].visible=false
		if i>=portions.size():continue
		var p:Dictionary=portions[i];var rotten:=String(p.id)=="rotten_meat"
		var k:=clampf(1-float(p.get("remaining_s",p.get("t",0)))/CookBatch.COOK_S,0,1)
		materials[i].albedo_texture=cooked_texture if k>=.8 else raw_texture
		materials[i].albedo_color=Color(.32,.48,.20) if rotten else (Color(.90,.86,.78) if k>=.8 else Color(1,.9,.88).lerp(Color(.70,.58,.45),k))
		materials[i].roughness=lerpf(.48,.9,k)
		marks[i].visible=not rotten and k>.8
