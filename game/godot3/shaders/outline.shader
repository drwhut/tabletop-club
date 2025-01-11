// This shader is based off code uploaded by axilirate on Godot Shaders (CC0):
// https://godotshaders.com/shader/pixel-perfect-outline-shader/

shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 OutlineColor: hint_color;
uniform float OutlineWidth = 1.0;

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * OutlineWidth * 2.0;
	
	clip_position.xy += offset;
	
	POSITION = clip_position;
}

void fragment() {
	ALBEDO = OutlineColor.rgb;
	ALPHA = OutlineColor.a;
}
