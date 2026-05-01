shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 0.831, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    float alpha = col.a;
    vec4 result = mix(vec4(0.0), glow_color, alpha);
    result.rgb += glow_color.rgb * alpha * glow_strength;
    COLOR = result;
}
