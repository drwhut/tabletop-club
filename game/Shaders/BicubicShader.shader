shader_type spatial;

uniform sampler2D Texture;
uniform vec2 TexturePixelSize;

vec4 cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

void fragment() {
	vec2 origin = UV / TexturePixelSize - 0.5;
	
	vec2 fxy = fract(origin);
	origin -= fxy;
	
	vec4 xcubic = cubic(fxy.x);
	vec4 ycubic = cubic(fxy.y);
	
	vec4 c = origin.xxyy + vec2(-0.5, 1.5).xyxy;
	
	vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	vec4 offset = c + vec4(xcubic.yw, ycubic.yw) / s;
	
	offset *= TexturePixelSize.xxyy;
	
	vec4 sample0 = texture(Texture, offset.xz);
	vec4 sample1 = texture(Texture, offset.yz);
	vec4 sample2 = texture(Texture, offset.xw);
	vec4 sample3 = texture(Texture, offset.yw);
	
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	
	vec4 color_y0 = mix(sample3, sample2, sx);
	vec4 color_y1 = mix(sample1, sample0, sx);
	vec4 color = mix(color_y0, color_y1, sy);
	
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
