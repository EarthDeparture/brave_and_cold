class_name WinterPathMaterial
extends RefCounted
static func create(half_width:float,length_m:float)->ShaderMaterial:
 var m:=ShaderMaterial.new()
 m.shader=preload("res://world/shaders/winter_service_path.gdshader")
 m.set_shader_parameter("gravel_albedo",preload("res://assets/route_detail/textures/gravel_alb.png"))
 m.set_shader_parameter("gravel_normal",preload("res://assets/route_detail/textures/gravel_nrm.png"))
 m.set_shader_parameter("powder_albedo",preload("res://assets/environment_detail/textures/powder_alb.png"))
 m.set_shader_parameter("powder_normal",preload("res://assets/environment_detail/textures/powder_nrm.png"))
 m.set_shader_parameter("spatial_fields",preload("res://assets/road_detail/textures/road_fields.png"))
 m.set_shader_parameter("half_width",half_width);m.set_shader_parameter("route_length",length_m)
 return m
