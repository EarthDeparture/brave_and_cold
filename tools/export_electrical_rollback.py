"""Make a separate save compatible with pre-electrical-fieldwork commit 4292c60.

Run before reverting code. Never edits the input or overwrites an existing output.
Only new component inventories/pickups and new hardware/issue fields are removed.
"""
from pathlib import Path
import argparse,copy,json

NEW_ITEMS={'dc_fuse','sealed_connector','dc_cable','winter_controller'}
NEW_SOLAR_FIELDS={'fuse_ok','cable_ok','winter_controller','tested_lead_installed'}

def compatible_copy(data):
 if not isinstance(data,dict):raise ValueError('Expected a JSON save object')
 if data.get('v')!=1:raise ValueError('Expected version-one Godot JSON save')
 out=copy.deepcopy(data)
 def visit(value):
  if isinstance(value,dict):
   for key,child in value.items():
    if key in {'counts','cond','age','c'} and isinstance(child,dict):
     for item in NEW_ITEMS:child.pop(item,None)
    visit(child)
  elif isinstance(value,list):
   for child in value:visit(child)
 visit(out)
 out['pickups']=[p for p in out.get('pickups',[]) if p.get('id') not in NEW_ITEMS]
 opening=out.get('opening',{})
 opening.get('home',{}).pop('electrical',None)
 solar=opening.get('state',{}).get('solar',{})
 for field in NEW_SOLAR_FIELDS:solar.pop(field,None)
 return out

def export(source:Path,destination:Path):
 if source.resolve()==destination.resolve():raise ValueError('Output must be a separate file')
 data=json.loads(source.read_text(encoding='utf-8-sig'))
 converted=compatible_copy(data)
 # Exclusive creation also rejects a path alias that already points to input.
 with destination.open('x',encoding='utf-8',newline='\n') as file:
  json.dump(converted,file,ensure_ascii=False,indent=2);file.write('\n')
 return destination

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('source',type=Path);parser.add_argument('destination',type=Path)
 args=parser.parse_args();print(export(args.source,args.destination))
