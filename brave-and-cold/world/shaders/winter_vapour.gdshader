shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 tint=vec3(.75,.82,.91);
uniform float opacity=0.0;
uniform float phase=0.0;
void vertex(){
 mat4 facing=mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
 MODELVIEW_MATRIX=VIEW_MATRIX*facing;MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
}
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float shape=exp(-dot(p,p)*3.8)*(1.0-smoothstep(.75,1.0,length(p)));
 float eddy=.73+.27*sin(p.x*9.0+phase+sin(p.y*5.0-phase*.4));
 ALBEDO=tint;ALPHA=shape*eddy*opacity;
}
