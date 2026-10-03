"""Plan an additive lookout placement and foot access without editing valley content.

Requires an exact baseline exported by the game's RoadNet/ForestScatter under
shots/lookout/map_baseline.json. Existing terrain, scatter, roads and buildings
are read-only inputs. Run with tools/terrain/.venv/Scripts/python.exe.
"""
from __future__ import annotations

import argparse
import hashlib
import heapq
import json
import math
import os
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import maximum_filter, minimum_filter, map_coordinates
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "brave-and-cold"
MAP = GAME / "data/maps/valley_b"
CELL = 2.0
PATH_HALF_WIDTH = 1.0
TREE_WALK_MARGIN = 0.35
MAX_GRADE = 0.30
YAW_DEGREES = (0, 30, 60, 90, 120, 150)
# Precise model extents, rather than a larger clearing that would alter trees.
MODEL_RECT = (-4.0, 6.7, -3.4, 3.4)


def load_map():
    meta = json.loads((MAP / "meta.json").read_text())
    n = int(meta["size_m"])
    raw = np.fromfile(MAP / "height.r16", dtype="<u2").reshape(n, n)
    height = raw.astype(np.float64) / 65535 * (meta["z_max_m"] - meta["z_min_m"]) + meta["z_min_m"]
    masks = {key: np.asarray(Image.open(MAP / f"{key}.png").convert("L")) for key in ("canopy", "slope", "water_mask")}
    return meta, height, masks


def sample(height, points):
    points = np.atleast_2d(points)
    half = height.shape[0] / 2
    return map_coordinates(height, [points[:, 1] + half, points[:, 0] + half], order=1, mode="nearest")


def local_to_world(local, origin, yaw):
    a = math.radians(yaw)
    rotation = np.array([[math.cos(a), math.sin(a)], [-math.sin(a), math.cos(a)]])
    return np.asarray(local) @ rotation.T + origin


def world_to_local(world, origin, yaw):
    a = math.radians(yaw)
    rotation = np.array([[math.cos(a), math.sin(a)], [-math.sin(a), math.cos(a)]])
    return (np.asarray(world) - origin) @ rotation


def rect_distance(points, rect):
    x0, x1, z0, z1 = rect
    dx = np.maximum(np.maximum(x0 - points[:, 0], points[:, 0] - x1), 0)
    dz = np.maximum(np.maximum(z0 - points[:, 1], points[:, 1] - z1), 0)
    return np.hypot(dx, dz)


def site_candidates(height, masks, trunks, road, buildings):
    n = height.shape[0]
    rel = maximum_filter(height, size=17) - minimum_filter(height, size=17)
    y, x = np.mgrid[96:n-96:4, 96:n-96:4]
    positions = np.column_stack((x.ravel()-n/2, y.ravel()-n/2))
    elevations = height[y.ravel(), x.ravel()]
    relief = rel[y.ravel(), x.ravel()]
    tree = cKDTree(trunks[:, :2])
    nearest, _ = tree.query(positions)
    road_dist, _ = cKDTree(road).query(positions)
    building_dist, _ = cKDTree(buildings).query(positions)
    good = (elevations > 350) & (relief < 2) & (nearest > 7.0) & (road_dist < 900) & (road_dist > 80) & (building_dist > 70)
    ids = np.where(good)[0]
    scores = elevations[ids] - road_dist[ids] * 0.09 - relief[ids] * 3 + np.minimum(nearest[ids], 14) * 1.0
    best = []
    for index in ids[np.argsort(-scores)]:
        origin = positions[index]
        if any(np.linalg.norm(origin - p[1]) < 30 for p in best):
            continue
        nearby = trunks[tree.query_ball_point(origin, 24)]
        # Tree canopy broadening is deliberately conservative: radius derived
        # from actual runtime trunk radius, never a new scatter exclusion.
        heights = (nearby[:, 2] - .12) / .012
        # Includes the largest spruce source reach, random branch spread and
        # the scatter's maximum 1.3 horizontal girth multiplier.
        canopy_radii = heights * .30
        for yaw in YAW_DEGREES:
            local = world_to_local(nearby[:, :2], origin, yaw)
            distances = rect_distance(local, MODEL_RECT)
            if np.any(distances < canopy_radii):
                continue
            xx, zz = np.meshgrid(np.linspace(-4, 6.7, 23), np.linspace(-3.4, 3.4, 15))
            footprint = local_to_world(np.column_stack((xx.ravel(), zz.ravel())), origin, yaw)
            hh = sample(height, footprint)
            if np.ptp(hh) > 2.0:
                continue
            best.append((float(elevations[index] - road_dist[index]*.09), origin, yaw, float(hh.min()), float(hh.max()), float(distances.min()), float((distances-canopy_radii).min())))
            break
        if len(best) >= 12:
            break
    return sorted(best, reverse=True, key=lambda p: p[0])


def make_route(height, masks, trunks, road, origin, yaw, grade=MAX_GRADE):
    """Bounded-slope eight-neighbour route with exact existing trunk avoidance."""
    n = height.shape[0]
    m = n // int(CELL)
    coordinates = np.arange(m)*CELL + CELL*.5-n*.5
    xx, zz = np.meshgrid(coordinates, coordinates)
    flat = np.column_stack((xx.ravel(), zz.ravel()))
    h = sample(height, flat).reshape(m, m)
    tree = cKDTree(trunks[:, :2])
    distance, nearest = tree.query(flat)
    clearance = (distance - trunks[nearest, 2]).reshape(m, m)
    canopy = masks["canopy"][1::2, 1::2] / 255 * 40
    slope = masks["slope"][1::2, 1::2] / 255 * 90
    water = maximum_filter(masks["water_mask"], size=5)[1::2, 1::2] > 127
    allowed = (clearance >= PATH_HALF_WIDTH+TREE_WALK_MARGIN) & ~water & (slope < 30)
    allowed[:32] = allowed[-32:] = False
    allowed[:, :32] = allowed[:, -32:] = False
    # First flight runs from local z+1.8 toward -1.8, centred at x4.45.
    # Stop just before that first tread so the route meets the opening.
    destination = local_to_world([[4.45, 2.4]], origin, yaw)[0]
    goal = np.rint((destination+n*.5-CELL*.5)/CELL).astype(int)
    gx, gz = int(goal[0]), int(goal[1])
    if not allowed[gz, gx]:
        return None
    roadtree = cKDTree(road)
    road_dist, road_nearest = roadtree.query(flat)
    joins = np.where((road_dist < 3.0) & allowed.ravel())[0]
    dist = np.full(m*m, np.inf)
    prev = np.full(m*m, -1, dtype=np.int32)
    heap = []
    for cell in joins:
        dist[cell] = float(road_dist[cell])
        heapq.heappush(heap, (dist[cell], int(cell)))
    # Batch nearest-trunk queries instead of millions of scalar KD-tree calls.
    midpoint_clearance = {}
    for dx,dz in ((1,0),(0,1),(1,1),(1,-1)):
        mid = flat + np.array([dx*CELL*.5,dz*CELL*.5])
        md,mi = tree.query(mid)
        midpoint_clearance[(dx,dz)] = (md-trunks[mi,2]).reshape(m,m)
    offsets = [(dx, dz, math.hypot(dx, dz)*CELL) for dx in (-1,0,1) for dz in (-1,0,1) if dx or dz]
    goal_index = gz*m+gx
    expanded = 0
    while heap:
        cost, i = heapq.heappop(heap)
        if cost != dist[i]:
            continue
        if i == goal_index:
            break
        z,x = divmod(i,m)
        expanded += 1
        for dx,dz,length in offsets:
            tx,tz=x+dx,z+dz
            if tx < 0 or tz < 0 or tx >= m or tz >= m or not allowed[tz,tx]:
                continue
            rise = abs(h[tz,tx]-h[z,x])/length
            if rise > grade:
                continue
            # Midpoint also respects actual tree surfaces. This prevents a
            # diagonal edge passing between legal grid nodes through a trunk.
            if (dx,dz) in midpoint_clearance:
                mid_clear=midpoint_clearance[(dx,dz)][z,x]
            else:
                mid_clear=midpoint_clearance[(-dx,-dz)][tz,tx]
            if mid_clear < PATH_HALF_WIDTH+TREE_WALK_MARGIN:
                continue
            j=tz*m+tx
            weight=1+rise*rise*18+min(float(canopy[tz,tx]),20)*.025+max(0,float(slope[tz,tx])-12)*.035
            candidate=cost+length*weight
            if candidate < dist[j]:
                dist[j]=candidate
                prev[j]=i
                heapq.heappush(heap,(candidate,j))
    if not math.isfinite(dist[goal_index]):
        return None
    chain=[]
    i=goal_index
    while i != -1:
        z,x=divmod(i,m)
        chain.append([coordinates[x],coordinates[z]])
        i=int(prev[i])
    chain.reverse()
    join=road[int(road_nearest[int(np.rint((chain[0][1]+n*.5-CELL*.5)/CELL))*m+int(np.rint((chain[0][0]+n*.5-CELL*.5)/CELL))])]
    chain=[join.tolist()]+chain+[destination.tolist()]
    return np.asarray(chain), expanded


def validate_route(height, masks, trunks, points):
    # Half-metre validation on every final segment (not just A* nodes).
    all_samples=[]
    for a,b in zip(points[:-1],points[1:]):
        count=max(2,math.ceil(np.linalg.norm(b-a)/.5)+1)
        all_samples.extend(a+(b-a)*t for t in np.linspace(0,1,count))
    p=np.asarray(all_samples)
    h=sample(height,p)
    lengths=np.linalg.norm(np.diff(p,axis=0),axis=1)
    rises=np.abs(np.diff(h))/np.maximum(lengths,1e-9)
    rises=rises[lengths>1e-8]
    tree=cKDTree(trunks[:,:2])
    d,i=tree.query(p,k=8)
    clearance=np.min(d-trunks[i,2],axis=1)
    pix=np.clip(np.rint(p+height.shape[0]/2).astype(int),0,height.shape[0]-1)
    wet=masks["water_mask"][pix[:,1],pix[:,0]]>127
    return {"max_grade_percent":float(rises.max()*100),"p95_grade_percent":float(np.percentile(rises,95)*100),"minimum_trunk_surface_clearance_m":float(clearance.min()),"water_samples":int(wet.sum()),"sample_count":len(p),"length_m":float(np.linalg.norm(np.diff(points,axis=0),axis=1).sum()),"ascent_m":float(np.maximum(np.diff(sample(height,points)),0).sum())}


def report(height, masks, trunks, road, points, origin, output):
    os.environ.setdefault("MPLCONFIGDIR", tempfile.mkdtemp(prefix="lookout_matplotlib_"))
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig,ax=plt.subplots(figsize=(11,9))
    ax.imshow(height,extent=(-1024,1024,1024,-1024),cmap="terrain",alpha=.88)
    ax.contour(np.arange(2048)-1024,np.arange(2048)-1024,height,levels=np.arange(180,500,20),colors="black",linewidths=.35,alpha=.4)
    ax.plot(road[:,0],road[:,1],color="white",lw=2,label="Existing road (unchanged)")
    ax.plot(points[:,0],points[:,1],color="crimson",lw=2,label="Added maintenance footpath")
    ax.scatter(*origin,s=110,c="cyan",edgecolors="black",marker="^",label="New lookout")
    ax.scatter(trunks[::8,0],trunks[::8,1],s=.6,c="darkgreen",alpha=.4)
    ax.set_xlabel("World x (m)");ax.set_ylabel("World z (m)");ax.set_title("Additive mountain lookout / terrain and existing access")
    ax.legend(loc="lower left");ax.set_aspect("equal")
    fig.tight_layout();fig.savefig(output,dpi=140);plt.close(fig)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline",type=Path,default=GAME/"shots/lookout/map_baseline.json")
    parser.add_argument("--output",type=Path,default=GAME/"data/lookout_site.json")
    args=parser.parse_args()
    baseline=json.loads(args.baseline.read_text())
    meta,height,masks=load_map()
    trunks=np.asarray(baseline["trunks"],dtype=float)
    road=np.asarray(baseline["road"],dtype=float)
    buildings=np.asarray([[b["pos"][0],b["pos"][2]] for b in baseline["buildings"]])
    candidates=site_candidates(height,masks,trunks,road,buildings)
    print("Candidates:",[(c[1].tolist(),c[2],round(c[3],2),round(c[4]-c[3],2)) for c in candidates],flush=True)
    for _,origin,yaw,low,high,tree_dist,canopy_clearance in candidates:
        result=make_route(height,masks,trunks,road,origin,yaw)
        if result is None:
            print("No bounded access:",origin.tolist(),flush=True);continue
        points,expanded=result
        stats=validate_route(height,masks,trunks,points)
        print("Route:",origin.tolist(),stats,"expanded",expanded,flush=True)
        if stats["max_grade_percent"]>MAX_GRADE*100+.5 or stats["minimum_trunk_surface_clearance_m"]<PATH_HALF_WIDTH+.15 or stats["water_samples"]:
            continue
        stair_base=local_to_world([[4.45,1.8]],origin,yaw)[0]
        base=float(sample(height,stair_base)[0])+.03
        heights=sample(height,points)
        files=["height.r16","meta.json","canopy.png","slope.png","water_mask.png"]
        data={"schema_version":1,"id":"mountain_lookout_01","description":"Additive electrical-maintenance lookout on a naturally open mountain shoulder; existing valley content is preserved.","preserved_existing_map":True,
              "origin":{"x":float(origin[0]),"y":round(base-meta["z_min_m"],4),"y_asl":round(base,4),"z":float(origin[1])},"yaw_degrees":yaw,
              "footprint":{"local_bounds_xz":list(MODEL_RECT),"min_ground_y":round(low-meta["z_min_m"],4),"max_ground_y":round(high-meta["z_min_m"],4),"relief_m":round(high-low,4),"minimum_tree_center_to_model_m":round(tree_dist,4),"minimum_conservative_canopy_clearance_m":round(canopy_clearance,4),"foundation_extension_m":round(max(0,base-low)+.20,4),"origin_height_policy":"terrain below stair base local x4.45,z+1.8 plus0.03m; short foundations adapt to unchanged terrain"},
              "route":[[round(float(p[0]),4),round(float(p[1]),4)] for p in points],"path":{"kind":"maintenance_footpath","width_m":PATH_HALF_WIDTH*2,"join_world_xz":points[0].tolist(),"end_world_xz":points[-1].tolist(),"points_world_xyz":[[round(float(p[0]),4),round(float(h-meta["z_min_m"]),4),round(float(p[1]),4)] for p,h in zip(points,heights)],**{k:round(v,4) if isinstance(v,float) else v for k,v in stats.items()}},
              "validation":{"source":"Exact Godot RoadNet and ForestScatter baseline; bilinear one-metre lidar terrain","baseline_sha256":hashlib.sha256(args.baseline.read_bytes()).hexdigest(),"existing_tree_count":len(trunks),"existing_road_point_count":len(road),"route_grade_limit_percent":MAX_GRADE*100,"terrain_edits":0,"tree_removals":0,"existing_road_edits":0,"source_sha256":{f:hashlib.sha256((MAP/f).read_bytes()).hexdigest() for f in files}}}
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(data,indent=2)+"\n")
        image=GAME/"shots/lookout/site_access_plan.png"
        image.parent.mkdir(parents=True,exist_ok=True)
        report(height,masks,trunks,road,points,origin,image)
        print("Wrote",args.output,"and",image,flush=True)
        return
    raise SystemExit("No naturally clear mountain site with validated access found; no content modified.")


if __name__=="__main__":
    main()
