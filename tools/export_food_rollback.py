"""Create a separate save for pre-food-preservation 9f3dff6. Never modify the original.

Dried portions become their cooked equivalents, retaining the fraction of shelf
life spent. Rack portions return to lookout provisions; fuel and knife costs stay.
Run before reverting code. Reverted carried cooked portions are heavier.
"""
from pathlib import Path
import argparse,copy,json
RECIPES={'venison_dried':('venison_cooked',72),'wolf_meat_dried':('wolf_meat_cooked',72),'bear_meat_dried':('bear_meat_cooked',72),'trout_dried':('trout_cooked',60),'whitefish_dried':('whitefish_cooked',60),'pike_dried':('pike_cooked',60)}
def merge(container,item,n,seconds):
 key='counts' if 'counts' in container else 'c'
 counts=container.setdefault(key,{});ages=container.setdefault('age',{})
 old=counts.get(item,0);counts[item]=old+n
 if item!='rotten_meat':ages[item]=(ages.get(item,0)*old+seconds*n)/(old+n)
def compatible_copy(data):
 if not isinstance(data,dict) or data.get('v')!=1:raise ValueError('Expected a version-one Godot JSON save object')
 out=copy.deepcopy(data)
 def visit(value):
  if isinstance(value,dict):
   for key in ('counts','c'):
    counts=value.get(key)
    if not isinstance(counts,dict):continue
    for item,(old,hours) in RECIPES.items():
     n=counts.pop(item,0)
     if n>0:
      age=value.setdefault('age',{}).pop(item,0)/240*hours
      value.get('cond',{}).pop(item,None);merge(value,old,n,age)
   for child in list(value.values()):visit(child)
  elif isinstance(value,list):
   for child in value:visit(child)
 visit(out)
 home=out.get('opening',{}).get('home',{})
 reserved=home.pop('preservation',{}).get('portions',[])
 for p in reserved:
  item=p.get('id')
  if item=='rotten_meat':merge(home.setdefault('storage',{}),item,1,0)
  elif item in RECIPES:
   old,hours=RECIPES[item];shelf=p.get('shelf_s',240*3600)
   age=p.get('age_s',0)/shelf*(hours*3600) if shelf>0 else 0
   merge(home.setdefault('storage',{}),old,1,age)
 for p in out.get('pickups',[]):
  if p.get('id') in RECIPES:
   old,hours=RECIPES[p['id']];p['id']=old;p['age_s']=p.get('age_s',0)/240*hours
 return out
def export(source:Path,destination:Path):
 if source.resolve()==destination.resolve():raise ValueError('Output must be a separate file')
 result=compatible_copy(json.loads(source.read_text(encoding='utf-8-sig')))
 with destination.open('x',encoding='utf8',newline='\n') as file:
  json.dump(result,file,ensure_ascii=False,indent=2);file.write('\n')
 return destination
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source',type=Path);parser.add_argument('destination',type=Path)
 args=parser.parse_args();print(export(args.source,args.destination))
