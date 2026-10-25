class_name WalkSurface
extends RefCounted
## Exact support on a ribbon's rendered triangles, indexed in world X/Z.
const CELL := 8.0
var _cells: Dictionary = {}

func build(rows: Array) -> void:
	_cells.clear()
	for i in range(rows.size()-1):
		for j in range(rows[i].size()-1):
			for triangle in [[rows[i][j],rows[i+1][j],rows[i][j+1]], [rows[i][j+1],rows[i+1][j],rows[i+1][j+1]]]:
				var a:Vector3=triangle[0];var b:Vector3=triangle[1];var c:Vector3=triangle[2]
				if absf(Vector2(b.x-a.x,b.z-a.z).cross(Vector2(c.x-a.x,c.z-a.z)))<.00001:continue
				var low:=Vector2(minf(a.x,minf(b.x,c.x)),minf(a.z,minf(b.z,c.z)))
				var high:=Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.z,maxf(b.z,c.z)))
				for x in range(floori(low.x/CELL),floori(high.x/CELL)+1):
					for z in range(floori(low.y/CELL),floori(high.y/CELL)+1):
						var key:=Vector2i(x,z)
						if not _cells.has(key):_cells[key]=[]
						_cells[key].append(triangle)

func height_at(x:float,z:float,foot_y:float=NAN) -> float:
	var result:=NAN
	for triangle in _cells.get(Vector2i(floori(x/CELL),floori(z/CELL)),[]):
		var a:Vector3=triangle[0];var b:Vector3=triangle[1];var c:Vector3=triangle[2]
		var ab:=Vector2(b.x-a.x,b.z-a.z);var ac:=Vector2(c.x-a.x,c.z-a.z);var ap:=Vector2(x-a.x,z-a.z)
		var denominator:=ab.cross(ac)
		var u:=ap.cross(ac)/denominator;var v:=ab.cross(ap)/denominator
		if u<-.00001 or v<-.00001 or u+v>1.00001:continue
		var h:=a.y+(b.y-a.y)*u+(c.y-a.y)*v
		# Do not teleport an actor underneath a raised bridge onto its deck.
		if not is_nan(foot_y) and h>foot_y+.65:continue
		if is_nan(result) or h>result:result=h
	return result
