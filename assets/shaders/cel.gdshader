// OmniVerse cel shader. Banded diffuse, rim light, optional emission and alpha.
// Pair with outline.gdshader as next_pass (see Cel.material()).
shader_type spatial;
render_mode cull_back, depth_prepass_alpha;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float bands : hint_range(1.0, 8.0) = 3.0;
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.5;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.2;
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	ALBEDO = albedo.rgb;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = smoothstep(0.55, 1.0, rim) * rim_strength;
	EMISSION = albedo.rgb * emission_strength + vec3(rim);
	ALPHA = alpha;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float shade = floor(ndl * bands) / bands;
	shade = mix(shadow_floor, 1.0, shade);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * shade;
}
