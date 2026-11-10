#version 440
// HUD sprite: samples a white/colored PNG, multiplies by a tint and optionally
// masks it to the first `fill` fraction of an arc (clockwise from 12 o'clock).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;        // opaque colour multiplier
    float fill;       // 0..1 along the arc
    float startAng;   // radians, clockwise from 12 o'clock
    float sweepAng;   // radians; <= 0 disables the arc mask
} ubuf;

layout(binding = 1) uniform sampler2D src;

const float TAU = 6.28318530718;

void main() {
    vec4 s = texture(src, qt_TexCoord0);   // premultiplied by Qt
    float m = 1.0;
    if (ubuf.sweepAng > 0.0) {
        vec2 d = qt_TexCoord0 - vec2(0.5);
        float a = atan(d.x, -d.y) - ubuf.startAng;
        a = a - TAU * floor(a / TAU);
        float t = a / ubuf.sweepAng;
        m = 1.0 - smoothstep(ubuf.fill - 0.012, ubuf.fill, t);
        if (ubuf.fill <= 0.0) m = 0.0;
    }
    fragColor = vec4(s.rgb * ubuf.tint.rgb, s.a) * (m * ubuf.qt_Opacity);
}
