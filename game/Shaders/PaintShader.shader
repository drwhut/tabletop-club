shader_type canvas_item;

uniform float AspectRatio;
uniform vec4 BrushColor: hint_color;
uniform bool BrushEnabled;
uniform vec2 BrushPosition;
uniform float BrushSize;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	
	if (BrushEnabled) {
		vec2 disp = UV - BrushPosition;
		disp.x *= AspectRatio;
		float dist = length(disp);
		
		if (dist <= BrushSize) {
			COLOR = BrushColor;
		} else {
			COLOR = base;
		}
	} else {
		COLOR = base;
	}
}
