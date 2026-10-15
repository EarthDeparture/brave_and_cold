shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float intensity = 1.0; // FireSource.glow(): 1 roaring, ~.2 embers, 0 cold
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 grid=UV*vec2(7.,5.);
 vec2 cell=floor(grid);
 float seed=hash(cell);
 vec2 offset=vec2(seed-.5,hash(cell+19.2)-.5)*.38;
 vec2 q=(fract(grid)-.5-offset)*vec2(.9+seed*.6,1.0+hash(cell+4.)*.6);
 float shape=(1.-smoothstep(.20,.48,length(q)))*step(.14,seed);
 float heat=.20+.65*seed+.12*sin(TIME*.8+seed*6.283);
 float crust=.55+.45*hash(floor(UV*vec2(65.,47.)));
 vec3 coal=mix(vec3(.12,.004,.001),vec3(.88,.20,.014),heat);
 vec3 glow=coal*shape*crust*intensity;
 ALBEDO=glow;
 EMISSION=glow;
}
