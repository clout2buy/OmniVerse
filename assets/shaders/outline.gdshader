// Inverted-hull ink outline. Used as next_pass on the cel material.
shader_type spatial;
render_mode cull_front, unshaded, depth_prepass_alpha;

uniform float width : hint_range(0.0, 0.2) = 0.025;
uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.04, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = alpha;
}
