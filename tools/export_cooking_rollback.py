"""Create a separate save compatible with pre-hunt-cooking d3a9f87.

Return reserved cabin portions to lookout storage (inventory for legacy saves).
Unfinished food returns raw with its source age; completed food retains cooked
age. Existing drying-rack stock is unchanged. Tool and fuel costs stay spent.
Never modify the source or overwrite an existing destination.
"""
from pathlib import Path
import argparse,copy,json
from export_food_rollback import merge
RAW={'venison_cooked':'venison_raw','wolf_meat_cooked':'wolf_meat_raw','bear_meat_cooked':'bear_meat_raw','trout_cooked':'trout_raw','whitefish_cooked':'whitefish_raw','pike_cooked':'pike_raw'}
def compatible_copy(data):
 if not isinstance(data,dict) or data.get('v')!=1:raise ValueError('Expected a version-one Godot JSON save object')
 out=copy.deepcopy(data)
 for cabin in out.get('cabins',[]):
  for p in cabin.pop('cooking',{}).get('portions',[]):
   item=p.get('id')
   if item not in RAW and item!='rotten_meat':raise ValueError('Unknown reserved food: '+str(item))
   if float(p.get('remaining_s',0))>0 and item in RAW:item=RAW[item]
   age=max(0,float(p.get('age_s',0)))
   if p.get('shelf_s',0)>0 and age>=p['shelf_s']:item='rotten_meat';age=0
   home=out.get('opening',{}).get('home')
   target=home.setdefault('storage',{}) if isinstance(home,dict) else out.setdefault('inv',{})
   merge(target,item,1,age)
 return out
def export(source:Path,destination:Path):
 if source.resolve()==destination.resolve():raise ValueError('Output must be a separate file')
 result=compatible_copy(json.loads(source.read_text(encoding='utf-8-sig')))
 with destination.open('x',encoding='utf8',newline='\n') as f:json.dump(result,f,ensure_ascii=False,indent=2);f.write('\n')
 return destination
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('destination',type=Path)
 args=p.parse_args();print(export(args.source,args.destination))
