shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bough_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform vec2 wind_direction=vec2(0.8,0.6);
uniform float wind_speed=4.0;
uniform float wind_phase=0.0;
varying float surface_kind;
void vertex(){
    surface_kind=COLOR.a;
    float height=length(MODEL_MATRIX[1].xyz);
    vec3 root=MODEL_MATRIX[3].xyz;
    float seed=dot(root.xz,vec2(0.033,0.047));
    float mask=pow(smoothstep(0.14,1.0,VERTEX.y),2.0);
    float sway=sin(wind_phase*0.72+seed)*0.65+sin(wind_phase*1.37+seed*1.7)*0.25;
    vec3 local_wind=inverse(mat3(MODEL_MATRIX))*vec3(wind_direction.x,0.0,wind_direction.y);
    VERTEX+=local_wind*height*0.013*min(wind_speed/20.0,1.4)*mask*sway;
}
void fragment(){
    float foliage=step(.3,surface_kind)*(1.0-step(.8,surface_kind));
    vec4 bough=texture(bough_albedo,UV);
    float grain=sin(UV.x*114.0+sin(UV.y*13.0)*1.4)*sin(UV.x*41.0+UV.y*2.0);
    vec3 solid=COLOR.rgb*mix(.86+.14*grain,1.0,step(.8,surface_kind));
    ALBEDO=mix(solid,bough.rgb,foliage);
    ALPHA=mix(1.0,bough.a,foliage);
    ALPHA_SCISSOR_THRESHOLD=.35;
    ROUGHNESS=.93;
    SPECULAR=.13;
    if(!FRONT_FACING){NORMAL=-NORMAL;}
}
