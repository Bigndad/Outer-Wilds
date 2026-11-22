#version 440

// The Bubble Monitor going full screen (BubbleDesign.qml), after the cloth has gone into the middle: ink spreads from
// there with a ragged, slowly moving edge until it covers the screen, and wherever it has spread the full-screen
// monitor (`source`) shows already. A thin rim in the theme colour runs along the ink's front.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;         // the window, px
    vec2 center;      // where the ink spreads from
    float inkR;       // how far it has spread, px
    float time;       // seconds, for the edge's ripple
    vec4 inkColor;    // the ink's body
    vec4 rimColor;    // the rim
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
    return v;
}

void main() {
    vec2 p = qt_TexCoord0 * res;
    float d = length(p - center);
    float n = fbm(p * 0.006 + vec2(time * 0.18, -time * 0.12));
    float edge = inkR * (0.76 + 0.48 * n);
    // the ink's dark front, a band ahead of where the monitor shows
    float body = inkR > 0.5 ? 1.0 - smoothstep(edge - 4.0, edge + 10.0, d) : 0.0;
    float show = inkR > 0.5 ? 1.0 - smoothstep(edge - 40.0, edge - 14.0, d) : 0.0;

    vec4 content = texture(source, qt_TexCoord0);
    vec4 col = mix(inkColor, content, show);
    float rim = smoothstep(edge - 40.0, edge - 14.0, d) * (1.0 - smoothstep(edge - 8.0, edge + 2.0, d));
    col.rgb = mix(col.rgb, rimColor.rgb, clamp(rim * 0.7, 0.0, 1.0) * body);
    fragColor = col * body * qt_Opacity;
}
