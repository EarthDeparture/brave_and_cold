"""Reproduce the old walking controller as an ignored diagnostic fixture."""
import argparse,re,subprocess
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--ref',default='39d91cb');args=ap.parse_args()
root=Path(__file__).resolve().parents[2]
source=subprocess.check_output(['git','show',args.ref+':brave-and-cold/entities/player/player.gd'],cwd=root,text=True)
functions=list(re.finditer(r'^func ',source,re.M))
wanted={'ground_at','_move','_slope_step','_eye_ground','_head_bob','_surface_probe_y','reset_jump','request_jump','_jump_vertical'}
chunks=[]
for i,match in enumerate(functions):
    end=functions[i+1].start() if i+1<len(functions) else len(source)
    chunk=source[match.start():end]
    if re.match(r'func (\w+)',chunk).group(1) in wanted:chunks.append(chunk)
assert len(chunks)==len(wanted)
path=root/'brave-and-cold/shots/walk-surfaces/baseline_player.gd';path.parent.mkdir(parents=True,exist_ok=True)
path.write_text('extends Player\n'+''.join(chunks),newline='\n')
print(path)
