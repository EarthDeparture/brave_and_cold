"""Embedded in native scenes: bind a grouped rigid-component action clip.
In Blender's Text Editor choose the asset/clip below, then Run Script and play.
Each clip starts from the saved rest pose, avoiding stale transforms from others.
"""
import bpy
from mathutils import Matrix
ASSET='ridge_scout_rifle'
CLIP='reload_empty'
def preview_clip(asset_id,clip):
    root=bpy.data.objects.get(asset_id)
    if not root:
        root=next((o for o in bpy.context.scene.objects if o.get('asset_id') and o.animation_data),None)
    if not root:
        print('This reload prop has no weapon animation.');return
    objects=[root]+list(root.children_recursive);count=0;end=0
    for o in objects:
        if 'authoring_rest_matrix' in o:
            data=list(o['authoring_rest_matrix']);o.matrix_basis=Matrix([data[k:k+4] for k in range(0,16,4)])
        if o.animation_data:
            o.animation_data.action=None;o.animation_data.use_nla=False
            for track in o.animation_data.nla_tracks:
                track.mute=True
                if track.name==clip:
                    strip=track.strips[0];o.animation_data.action=strip.action;o.animation_data.action_slot=strip.action_slot
                    count+=1;end=max(end,track.strips[-1].frame_end)
    if not count:raise ValueError('No clip '+clip+' on '+root.name)
    scene=bpy.context.scene;scene.frame_start=0;scene.frame_end=round(end);scene.frame_set(0)
    print('Selected',root.name,clip,'/',count,'component tracks. Play the timeline to preview.')
if __name__=='__main__':preview_clip(ASSET,CLIP)
