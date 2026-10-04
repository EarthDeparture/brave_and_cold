class_name WalkRibbon3D
extends Node3D
## Height-only adapter for an existing visible terrain ribbon.
var walk_surface:=WalkSurface.new()
func floor_at_world(foot:Vector3,_terrain_height:float=NAN)->float:
	return walk_surface.height_at(foot.x,foot.z,foot.y)
