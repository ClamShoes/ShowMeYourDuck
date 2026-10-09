// Hey this is Hei! This shader "fakes" a 3D-camera perspective on CanvasItems.
// License: MIT

shader_type canvas_item;

// Camera FOV
uniform float fov : hint_range(1, 179) = 90;
uniform bool cull_back = true;
uniform float y_rot : hint_range(-180, 180) = 0.0;
uniform float x_rot : hint_range(-180, 180) = 0.0;
// Hover/feel tilt, added on top of y_rot/x_rot so the flip clip and the tilt never overwrite each other.
uniform float tilt_x : hint_range(-45, 45) = 0.0;
uniform float tilt_y : hint_range(-45, 45) = 0.0;
// At 0, the image retains its size when unrotated.
// At 1, the image is resized so that it can do a full
// rotation without clipping inside its rect.
uniform float inset : hint_range(0, 1) = 0.0;

varying flat vec2 o;
varying vec3 p;
// Fragment COLOR is pre-multiplied by the unwarped texture, so modulate has to come via the vertex.
varying vec4 tint;

void vertex(){
	tint = COLOR;
	float yr = y_rot + tilt_y;
	float xr = x_rot + tilt_x;
	float sin_b = sin(yr / 180.0 * PI);
	float cos_b = cos(yr / 180.0 * PI);
	float sin_c = sin(xr / 180.0 * PI);
	float cos_c = cos(xr / 180.0 * PI);
	
	mat3 inv_rot_mat;
	inv_rot_mat[0][0] = cos_b;
	inv_rot_mat[0][1] = 0.0;
	inv_rot_mat[0][2] = -sin_b;
	
	inv_rot_mat[1][0] = sin_b * sin_c;
	inv_rot_mat[1][1] = cos_c;
	inv_rot_mat[1][2] = cos_b * sin_c;
	
	inv_rot_mat[2][0] = sin_b * cos_c;
	inv_rot_mat[2][1] = -sin_c;
	inv_rot_mat[2][2] = cos_b * cos_c;
	
	
	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((UV - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;

	VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE * t * (1.0 - inset);
}

void fragment(){
	if (cull_back && p.z <= 0.0) discard;
	vec2 uv = (p.xy / p.z).xy - o;
	COLOR = texture(TEXTURE, uv + 0.5) * tint;
	COLOR.a *= step(max(abs(uv.x), abs(uv.y)), 0.5);
}
