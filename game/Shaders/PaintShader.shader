shader_type canvas_item;

uniform float AspectRatio;
uniform vec4 BrushColor: hint_color;
uniform bool BrushEnabled;
uniform vec2 BrushPosition1;
uniform vec2 BrushPosition2;
uniform float BrushSize;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	
	if (BrushEnabled) {
		// TODO: Use the AspectRatio in these calculations.
		
		vec2 rect_dir = normalize(BrushPosition2 - BrushPosition1);
		vec2 perpendicular = vec2(-rect_dir.y, rect_dir.x); // 90 deg CCW.
		vec2 to_corner = BrushSize * perpendicular;
		
		vec2 a = BrushPosition1 + to_corner;
		vec2 b = BrushPosition1 - to_corner;
		vec2 d = BrushPosition2 + to_corner;
		
		vec2 a_to_p = UV - a;
		vec2 a_to_b = b - a;
		vec2 a_to_d = d - a;
		
		float dot_p_b = dot(a_to_p, a_to_b);
		float dot_b_b = dot(a_to_b, a_to_b);
		float dot_p_d = dot(a_to_p, a_to_d);
		float dot_d_d = dot(a_to_d, a_to_d);
		
		if (0.0 < dot_p_b && dot_p_b < dot_b_b && 0.0 < dot_p_d && dot_p_d < dot_d_d) {
			COLOR = BrushColor;
		} else {
			vec2 disp = UV - BrushPosition1;
			//disp.x *= AspectRatio;
			float len = length(disp);
			
			if (len < BrushSize) {
				COLOR = BrushColor;
			} else {
				disp = UV - BrushPosition2;
				//disp.x *= AspectRatio;
				len = length(disp);
				
				if (len < BrushSize) {
					COLOR = BrushColor;
				} else {
					COLOR = base;
				}
			}
		}
	} else {
		COLOR = base;
	}
}
