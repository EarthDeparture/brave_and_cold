shader_type spatial;
render_mode cull_disabled;
uniform sampler2D aggregate_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aggregate_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D powder_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D powder_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D spatial_fields : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fresh_snow = 0.0;
uniform float route_length = 2558.0;
varying vec2 ground_xz;
void vertex(){ground_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
 // Metric UV: lateral metres and cumulative centreline distance. No camera swimming.
 vec2 metre=UV;
 vec4 broad=texture(spatial_fields,metre*vec2(.12,.021));
 vec4 breakup=texture(spatial_fields,metre*vec2(.27,.15)+vec2(.21,.37));
 float lateral=abs(metre.x);
 float side=step(0.0,metre.x);
 vec4 lane=texture(spatial_fields,vec2(side*.43+.17,metre.y*.015));
 float wander=(lane.g-.5)*.24;
 // Two wheel paths per lane, softened by irregular snow and road grit.
 float wheel=min(abs(lateral-(.70+wander)),abs(lateral-(2.00+wander)));
 float wear=1.0-smoothstep(.08,.34+(breakup.r-.5)*.22,wheel);
 float shoulder=smoothstep(2.45+(broad.r-.5)*.22,3.25,lateral);
 float deposit=smoothstep(.32,.76,breakup.r*.6+broad.g*.4);
 float cover=clamp(.63+deposit*.25-wear*.39*(.15+.85*smoothstep(.20,.72,breakup.g))+fresh_snow*.19,0.0,1.0);
 cover=mix(cover,1.0,shoulder);
 vec4 grit=texture(aggregate_albedo,metre/2.4);
 vec4 snow=texture(powder_albedo,ground_xz*.12);
 vec4 grit_n=texture(aggregate_normal,metre/2.4);
 vec4 snow_n=texture(powder_normal,ground_xz*.12);
 vec3 asphalt=grit.rgb*(1.18+broad.b*.16);
 // Dirty compacted snow is confined to traffic lanes, clean powder on banks.
 vec3 compacted=snow.rgb*mix(vec3(.66,.69,.71),vec3(.93,.95,.98),shoulder);
 vec3 colour=mix(asphalt,compacted,cover);
 float centerline=(1.0-smoothstep(.033,.06,lateral))*step(.58,fract(metre.y/8.0));
 float exposed_paint=centerline*(1.0-cover)*smoothstep(.38,.65,breakup.g)*.52;
 colour=mix(colour,vec3(.48,.37,.105),exposed_paint);
 // Small compression ribs are only resolved close to the boots.
 float resolved=1.0-smoothstep(.012,.065,length(fwidth(metre)));
 float ribs=1.0-smoothstep(.12,.34,abs(fract((metre.y+metre.x*.6)/.095)-.5));
 colour*=1.0-ribs*wear*resolved*.035;
 ALBEDO=colour;
 // Match the adjacent terrain powder without visible dithering or transparency.
 float side_edge=1.0-smoothstep(3.45+(broad.b-.5)*.35,4.9,lateral);
 float end_edge=smoothstep(0.0,8.0,metre.y)*smoothstep(0.0,8.0,route_length-metre.y);
 float road_weight=side_edge*end_edge;
 vec3 edge_powder=texture(powder_albedo,ground_xz*.12).rgb;
 ALBEDO=colour;
 ALPHA=road_weight;
 float polished=wear*(1.0-cover)*smoothstep(.35,.65,broad.g);
 ROUGHNESS=mix(.87,.53,polished);
 SPECULAR=mix(.17,.30,polished);
 NORMAL_MAP=mix(grit_n.rgb,snow_n.rgb,cover);
 NORMAL_MAP_DEPTH=mix(.32,.65,cover);
 if(!FRONT_FACING) NORMAL=-NORMAL;
}
