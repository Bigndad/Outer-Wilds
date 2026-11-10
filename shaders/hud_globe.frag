#version 440
// Audio-visualiser globe. Samples the minimap grid texture on a fake sphere;
// latitude rows (equator = bass, poles = treble) glow with the 8 band levels.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
    vec4 bandsA;      // bands 0..3
    vec4 bandsB;      // bands 4..7
    float spin;       // radians
    float tilt;       // radians
} ubuf;

layout(binding = 1) uniform sampler2D src;

const float PI = 3.14159265359;

float bandAt(int i) {
    return (i < 4) ? ubuf.bandsA[i] : ubuf.bandsB[i - 4];
}

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    float r2 = dot(p, p);
    float r = sqrt(r2);
    float z = sqrt(max(1.0 - r2, 0.0));
    float edgeA = 1.0 - smoothstep(0.975, 1.0, r);

    // sphere normal, tilted toward the viewer a little
    float ct = cos(ubuf.tilt);
    float st = sin(ubuf.tilt);
    float ny = -p.y * ct + z * st;
    float nz = p.y * st + z * ct;

    float lat = asin(clamp(ny, -1.0, 1.0));
    float lon = atan(p.x, nz) + ubuf.spin;
    // continuous (un-fract'ed) coords drive the derivatives, so the wrap line does not pick the lowest mip
    vec2 uvC = vec2(lon / (2.0 * PI) + 0.5, clamp(0.5 - lat / PI, 0.0, 1.0));
    vec2 uv = vec2(fract(uvC.x), uvC.y);
    vec4 s = textureGrad(src, uv, dFdx(uvC), dFdy(uvC));

    // derivatives are taken above, so the early-out can come after the sample
    if (r2 >= 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    float lum = dot(s.rgb, vec3(0.299, 0.587, 0.114));
    float line = smoothstep(0.30, 0.40, lum);   // grid lines are light grey

    // band for this latitude (0 = equator ... 7 = poles), smoothly interpolated
    float rowF = clamp(abs(lat) / (0.5 * PI), 0.0, 0.999);
    float f = rowF * 7.0;
    int i0 = int(f);
    int i1 = min(i0 + 1, 7);
    float e = mix(bandAt(i0), bandAt(i1), f - float(i0));

    // per-column variation so cells ripple instead of lighting as flat rings
    float colId = floor(uv.x * 10.0);
    float h = fract(sin(colId * 12.9898 + float(i0) * 78.233) * 43758.5453);
    float glow = e * (0.55 + 0.45 * h);

    float rim = r * r * r;
    float lit = 0.65 + 0.35 * z;

    vec3 base = ubuf.tint.rgb;
    vec3 c = base * (line * (0.28 + 0.9 * e)) * lit
           + base * ((1.0 - line) * glow * 0.85) * lit
           + base * rim * 0.45;
    float a = clamp(0.10 + line * 0.55 + glow * 0.70 + rim * 0.35, 0.0, 1.0);
    c = min(c + base * 0.04, vec3(a));

    fragColor = vec4(c, a) * (edgeA * ubuf.qt_Opacity);
}
