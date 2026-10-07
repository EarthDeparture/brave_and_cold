shader_type spatial;
render_mode cull_disabled;
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D powder_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D powder_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D spatial_fields : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float half_width = 1.0;
uniform float route_length = 570.0;
uniform bool runoff_mode = false;
uniform float fresh_snow = 0.0;
varying vec2 ground_xz;
void vertex(){ground_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
 vec4 field=texture(spatial_fields,ground_xz*vec2(.028,.041));
 vec4 breakup=texture(spatial_fields,UV*vec2(.31,.19)+vec2(.13,.58));
 float edge=abs(UV.x)/half_width;
 float wander=(field.g-.5)*.23;
 float tread=1.0-smoothstep(.19,.70+(field.r-.5)*.20,abs(UV.x-wander)/half_width);
 float travelled=tread*(.55+.45*breakup.g);
 float gravel=travelled*smoothstep(.30,.77,breakup.r*.65+field.b*.35)*(1.0-fresh_snow*.70);
 float inset=1.0-smoothstep(.45+(breakup.b-.5)*.15,.92,edge);
 float ends=smoothstep(0.0,4.0,UV.y)*smoothstep(0.0,4.0,route_length-UV.y);
 vec4 snow=texture(powder_albedo,ground_xz*.12);
 vec4 grit=texture(gravel_albedo,UV/.9);
 vec3 packed=snow.rgb*mix(vec3(1.0),vec3(.73,.76,.78),travelled*(1.0-fresh_snow*.60));
 vec3 colour=mix(packed,grit.rgb*.82,gravel*.45);
 // Broken crosswise boot compression, attenuated before subpixel aliasing.
 float resolved=1.0-smoothstep(.009,.04,length(fwidth(UV)));
 float rib=(1.0-smoothstep(.06,.14,abs(fract((UV.y+UV.x*.26)/.32)-.5)))*travelled*resolved;
 colour*=1.0-rib*.025+(grit.r-.35)*.12*resolved*travelled;
 if(runoff_mode) colour=mix(snow.rgb,grit.rgb*.68,travelled*.85);
 ALBEDO=colour;
 ALPHA=inset*ends*COLOR.a;
 ROUGHNESS=mix(.97,.76,travelled*(1.0-fresh_snow));
 SPECULAR=.16;
 vec3 snow_n=texture(powder_normal,ground_xz*.12).rgb;
 vec3 grit_n=texture(gravel_normal,UV/.9).rgb;
 NORMAL_MAP=mix(snow_n,grit_n,gravel*inset);
 NORMAL_MAP_DEPTH=mix(.65,.30,travelled);
 if(!FRONT_FACING)NORMAL=-NORMAL;
}
