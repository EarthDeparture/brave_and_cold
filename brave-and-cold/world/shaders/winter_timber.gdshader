shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 object_point;
varying vec3 object_normal;
void vertex(){object_point=VERTEX;object_normal=NORMAL;}
void fragment(){
 vec3 n=pow(abs(object_normal),vec3(6.0));n/=max(dot(n,vec3(1.0)),.001);
 vec3 a=texture(grain,object_point.zy*vec2(1.4,.22)).rgb;
 vec3 b=texture(grain,object_point.xz*vec2(1.4,.22)).rgb;
 vec3 c=texture(grain,object_point.xy*vec2(1.4,.22)).rgb;
 vec3 texture_colour=a*n.x+b*n.y+c*n.z;
 // The interior batch also contains blue cloth, painted metal, and paper.
 // Restrict timber grain to warm wood colours in that vertex palette.
 float wood_mask=smoothstep(.005,.035,COLOR.r-COLOR.g)*smoothstep(.005,.02,COLOR.g-COLOR.b);
 ALBEDO=COLOR.rgb*mix(vec3(1.0),texture_colour/vec3(.54,.45,.34),.65*wood_mask);
 ROUGHNESS=.88;SPECULAR=.17;
 if(!FRONT_FACING)NORMAL=-NORMAL;
}
