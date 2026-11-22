#version 440

// The Bubble Monitor going full screen (BubbleDesign.qml): the UI (`source`, drawn live) on a fine mesh, sucked like a
// cloth into its full-screen button (`target`). The parts nearest the button go first and the far corner last, so the
// cloth stretches towards the button as it goes in; it turns a little on the way (`swirl`) and a ripple runs over it.
// `prog` 0: at rest, 1: all of it in the button.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(location = 1) out float fold;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float prog;
    float swirl;      // radians it turns on the way in
    vec2 size;        // the UI, px
    vec2 target;      // the button's middle, in the UI's coordinates
};

void main() {
    vec2 rel = qt_Vertex.xy - target;
    // 0 at the button, 1 at the corner farthest from it
    float far = max(max(length(target), length(target - vec2(size.x, 0.0))),
                    max(length(target - vec2(0.0, size.y)), length(target - size)));
    float d = length(rel) / far;
    const float lag = 0.5;
    float t = clamp((prog - d * lag) / (1.0 - lag), 0.0, 1.0);
    t = t * t * (3.0 - 2.0 * t);

    float a = swirl * t * t;
    vec2 q = mat2(cos(a), sin(a), -sin(a), cos(a)) * rel * (1.0 - 0.99 * t);
    vec2 nrm = length(q) > 0.001 ? vec2(-q.y, q.x) / length(q) : vec2(0.0);
    float moving = 4.0 * t * (1.0 - t);
    float w = sin(d * 12.0 - prog * 18.0);

    fold = w * moving;
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * vec4(target + q + nrm * w * 10.0 * moving, 0.0, 1.0);
}
