"""Bake native shape-key actions explicitly around Blender 5.2 NLA sampling cache.
Retain exported bone tracks and geometry; append synchronized scalar morph tracks.
"""
import json,struct
from pathlib import Path
import bpy
def bake_morph_tracks(path):
    raw=Path(path).read_bytes();size=struct.unpack_from('<I',raw,12)[0]
    g=json.loads(raw[20:20+size]);length=struct.unpack_from('<I',raw,20+size)[0]
    binary=bytearray(raw[28+size:28+size+length]);report={}
    def accessor(values,minimum=None,maximum=None):
        while len(binary)%4:binary.append(0)
        offset=len(binary);binary.extend(struct.pack('<'+'f'*len(values),*values))
        view=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(values)*4})
        entry={'bufferView':view,'componentType':5126,'count':len(values),'type':'SCALAR'}
        if minimum is not None:entry['min']=[minimum];entry['max']=[maximum]
        index=len(g['accessors']);g['accessors'].append(entry);return index
    for animation in g['animations']:
        clip=animation['name'];samples=79 if clip=='FlexCycle' else 2
        frames=list(range(79)) if samples==79 else [0,30]
        times=[frame/30 for frame in frames];time_accessor=accessor(times,0,times[-1])
        report[clip]={}
        for channel in animation['channels']:
            if channel['target']['path']!='weights':continue
            node=g['nodes'][channel['target']['node']];obj=bpy.data.objects[node['name']]
            names=g['meshes'][node['mesh']]['extras']['targetNames'];keys=obj.data.shape_keys
            strip=next(t.strips[0] for t in keys.animation_data.nla_tracks if t.name==clip)
            bag=strip.action.layers[0].strips[0].channelbag(strip.action_slot)
            curves={curve.data_path:curve for curve in bag.fcurves}
            values=[float(curves['key_blocks["'+name+'"].value'].evaluate(frame)) for frame in frames for name in names]
            sampler=animation['samplers'][channel['sampler']]
            sampler.update(input=time_accessor,output=accessor(values),interpolation='LINEAR')
            report[clip][obj.name]={'samples':samples,'maximum':max(values),'first':values[:len(names)],'last':values[-len(names):]}
    g['buffers'][0]['byteLength']=len(binary)
    encoded=json.dumps(g,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
    binary.extend(b'\0'*((-len(binary))%4))
    output=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary
    Path(path).write_bytes(output)
    (Path(path).parent/'morph_export.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('ANATOMICAL_MORPH_EXPORT_PASS',len(report))
if __name__=='__main__':
    out=Path(__file__).parent/'generated/anatomical_hands_v2'
    bpy.ops.wm.open_mainfile(filepath=str(out/'anatomical_hands.blend'))
    bake_morph_tracks(out/'godot/anatomical_hands.glb')
    import hashlib
    meta=json.loads((out/'manifest.json').read_text());meta['glb_sha256']=hashlib.sha256((out/'godot/anatomical_hands.glb').read_bytes()).hexdigest()
    (out/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8',newline='\n')
