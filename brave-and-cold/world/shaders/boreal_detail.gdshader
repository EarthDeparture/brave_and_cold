shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bough_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D diversity_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D diversity_far_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D diversity_bark : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D diversity_bark_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
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
    ALPHA=1.0;
    NORMAL_MAP=vec3(.5,.5,1.0);
    if(surface_kind>=.3 && surface_kind<.8){
        vec4 bough;
        if(surface_kind>.70){bough=texture(diversity_far_albedo,UV);}
        else if(surface_kind>.55){bough=texture(diversity_albedo,UV);}
        else {bough=texture(bough_albedo,UV);}
        ALBEDO=bough.rgb;
        ALPHA=bough.a;
    }else if(surface_kind>=.8){
        ALBEDO=COLOR.rgb;
    }else if(surface_kind<=.05){
        float grain=sin(UV.x*114.0+sin(UV.y*13.0)*1.4)*sin(UV.x*41.0+UV.y*2.0);
        ALBEDO=COLOR.rgb*(.86+.14*grain);
    }else{
        vec2 bark_uv=vec2(.02+UV.x*.46+step(.15,surface_kind)*.5,UV.y);
        ALBEDO=COLOR.rgb*texture(diversity_bark,bark_uv).rgb;
        NORMAL_MAP=texture(diversity_bark_normal,bark_uv).rgb;
    }
    ALPHA_SCISSOR_THRESHOLD=.35;
    NORMAL_MAP_DEPTH=.6;
    ROUGHNESS=.93;
    SPECULAR=.13;
    if(!FRONT_FACING){NORMAL=-NORMAL;}
}
