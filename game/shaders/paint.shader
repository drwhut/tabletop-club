shader_type canvas_item;

uniform float AspectRatio;
uniform vec4 BrushColor: hint_color;
uniform bool BrushEnabled;
uniform vec2 BrushPosition;
uniform float BrushSize;

// The following globals are pre-calculated by the CPU.
uniform vec2 InverseQuadCol1;
uniform vec2 InverseQuadCol2;
uniform vec2 QuadCorner;

void fragment() {
	bool replace_color = false;
	
	if (BrushEnabled) {
		mat2 inv_quad = mat2(InverseQuadCol1, InverseQuadCol2);
		vec2 coeff = inv_quad * (UV - QuadCorner);
		
		if (coeff.x > 0.0 && coeff.x < 1.0 && coeff.y > 0.0 && coeff.y < 1.0) {
			replace_color = true;
		} else {
			vec2 disp = UV - BrushPosition;
			disp.x *= AspectRatio;
			float len = length(disp);
			
			if (len < BrushSize) {
				replace_color = true;
			}
		}
	}
	
	if (replace_color) {
		COLOR = BrushColor;
	} else {
		COLOR = texture(TEXTURE, UV);
	}
}
