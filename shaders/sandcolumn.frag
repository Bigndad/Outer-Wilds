#version 440
// =====================================================================
// sandcolumn.frag - the sand stream between Ash Twin and Ember Twin.
// Drawn on a quad centred between the twins and rotated along the line
// Ash -> Ember (texcoord x runs Ash -> Ember, y across the column).
// CameraRig.qml z-sorts this quad between the two twins.
// =====================================================================
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 colInfo;   // x = column length px, y = column half-width px, z = loopTime (s), w = strength 0..1
};

// ---- tweak knobs ----
const float COL_WOBBLE   = 0.12;   // how much the column width wanders
const float COL_RAGGED   = 0.20;   // ragged / sandy edge amount
const float COL_FLOW     = 1.3;    // sand speed along the column (toward Ember)
const float COL_TAPER    = 0.18;   // fatter at Ash, thinner at Ember (0 = none)
const float COL_GRAINS   = 0.90;   // grain sparkle threshold (higher = fewer)

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main() {
    float len   = max(colInfo.x, 1.0);
    float halfW = max(colInfo.y, 1.0);
    float t     = colInfo.z;
    float k     = colInfo.w;

    float x = qt_TexCoord0.x;
    float s = x * len;                                   // px along the column
    float v = (qt_TexCoord0.y - 0.5) * 3.2;              // across, in half-widths (quad is 3.2 half-widths tall)
    float u = s / halfW;                                 // along, in half-widths

    float w = 1.0 + COL_WOBBLE * (vnoise(vec2(u * 0.35 - t * 0.35, 3.0)) * 2.0 - 1.0)
                  + 0.06 * sin(u * 0.8 - t * 1.4);
    w *= mix(1.0 + COL_TAPER, 1.0 - COL_TAPER, x);

    float edgeN = vnoise(vec2(u * 2.4 - t * COL_FLOW * 0.8, v * 2.2)) - 0.5;
    float d = abs(v) / w + COL_RAGGED * edgeN;
    float body = 1.0 - smoothstep(0.80, 1.0, d);

    // streaks of sand running along the flow
    float n1 = vnoise(vec2(u * 0.55 - t * COL_FLOW, v * 6.0));
    float n2 = vnoise(vec2(u * 1.60 - t * COL_FLOW * 1.7, v * 12.0));
    float streak = 0.6 * n1 + 0.4 * n2;

    // cylinder shading: bright middle, darker edges, slight top-light
    float dn = clamp(abs(v) / w, 0.0, 1.0);
    float cz = sqrt(max(1.0 - dn * dn, 0.0));
    float shade = 0.50 + 0.60 * cz + 0.10 * (-v / w);

    vec3 dark = vec3(0.64, 0.49, 0.31);
    vec3 lite = vec3(1.00, 0.89, 0.65);
    vec3 col = mix(dark, lite, smoothstep(0.15, 0.85, streak)) * shade;

    // sparkling grains drifting with the flow
    vec2 gp = vec2(u * 7.0 - t * COL_FLOW * 3.0, v * 7.0);
    float g = step(COL_GRAINS, hash21(floor(gp))) * (1.0 - smoothstep(0.0, 0.6, length(fract(gp) - 0.5)));
    col += vec3(1.0, 0.94, 0.78) * g * 0.6 * body;

    // fade where the column dives into the twins
    float fadePx = halfW * 2.5;
    float a = body * smoothstep(0.0, fadePx, s) * smoothstep(0.0, fadePx, len - s);
    a = clamp(a * 0.96, 0.0, 1.0) * k;

    fragColor = vec4(col * a, a) * qt_Opacity;
}
