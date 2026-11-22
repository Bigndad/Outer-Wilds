#version 440

// The cloth's colour (bubble_cloth.vert moves it): the UI, lighter and darker along the ripple's folds.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 1) in float fold;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float prog;
    float swirl;
    vec2 size;
    vec2 target;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    c.rgb *= 1.0 + 0.18 * fold;
    fragColor = c * qt_Opacity;
}
