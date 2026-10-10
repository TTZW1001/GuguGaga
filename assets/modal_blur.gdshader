shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 3.0).rgb;
	COLOR = vec4(mix(c, vec3(0.16, 0.19, 0.17), 0.34), 1.0);
}
