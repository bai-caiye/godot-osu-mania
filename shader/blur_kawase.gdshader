shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float radius : hint_range(0.0, 5.0) = 5.0;

void fragment() {
    vec4 color = vec4(0.0);
    float total = 0.0;
    
    for(float x = -1.0; x <= 1.0; x += 2.0) {
        for(float y = -1.0; y <= 1.0; y += 2.0) {
            vec2 offset = vec2(x, y) * radius * SCREEN_PIXEL_SIZE;
            color += textureLod(screen_texture, SCREEN_UV + offset, radius);
            total += 1.0;
        }
    }
    COLOR = color / total;
}