"""Embedded Blender source helper: select bone and corrective actions together."""
import bpy
CLIP='Relaxed'
def play_clip(clip):
    for name in ['HandRig','LeftHandRig']:
        rig=bpy.data.objects[name];anim=rig.animation_data;anim.action=None;anim.use_nla=False
        strip=next(t.strips[0] for t in anim.nla_tracks if t.name==clip)
        for t in anim.nla_tracks:t.mute=True
        anim.action=strip.action;anim.action_slot=strip.action_slot
    for name in ['BareHand','BareHandLeft']:
        keys=bpy.data.objects[name].data.shape_keys;anim=keys.animation_data;anim.action=None;anim.use_nla=False
        strip=next(t.strips[0] for t in anim.nla_tracks if t.name==clip)
        for t in anim.nla_tracks:t.mute=True
        anim.action=strip.action;anim.action_slot=strip.action_slot
    bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=78 if clip=='FlexCycle' else 30;bpy.context.scene.frame_set(0)
    print('Selected bone + corrective clip:',clip,'— play the timeline.')
if __name__=='__main__':play_clip(CLIP)
