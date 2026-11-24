#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 baseColor;
    vec4 accentColor;
    vec4 lightDir;   // xyz = Sun direction in view space, w = time
    vec4 params;     // x = isMetric, y = pct (0..1), z = hot, w = selected
};

void main() {
    vec2 p = vec2(qt_TexCoord0.x * 2.0 - 1.0, 1.0 - qt_TexCoord0.y * 2.0);
    float r2 = dot(p, p);
    if (r2 > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    float r = sqrt(r2);
    vec3 N = vec3(p.x, p.y, sqrt(max(0.0, 1.0 - r2)));
    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 L = normalize(lightDir.xyz);
    vec3 L2 = normalize(vec3(-0.48, 0.62, 0.62));

    // Diffuse from Sun + gentle fill light so dark side still reads as 3D
    float diffSun = max(dot(N, L), 0.0);
    float wrapSun = clamp((dot(N, L) + 0.35) / 1.35, 0.0, 1.0);
    float diffFill = max(dot(N, L2), 0.0) * 0.38;

    // Specular highlights (Sun + rim fill)
    vec3 H1 = normalize(L + V);
    vec3 H2 = normalize(L2 + V);
    float spec1 = pow(max(dot(N, H1), 0.0), 56.0) * 0.85;
    float spec2 = pow(max(dot(N, H2), 0.0), 28.0) * 0.35;

    // Fresnel glass rim + subtle soap-bubble iridescence
    float fresnel = pow(1.0 - clamp(N.z, 0.0, 1.0), 2.5);
    vec3 irid = 0.5 + 0.5 * cos(6.28318 * (fresnel * 1.15 + lightDir.w * 0.06 + vec3(0.0, 0.33, 0.67)));

    vec3 base = baseColor.rgb;
    vec3 shaded = base * (0.26 + 0.62 * wrapSun + diffFill);

    // Subtle internal translucency / core depth for orb feel
    float coreGlow = pow(clamp(N.z, 0.0, 1.0), 1.6) * 0.14;
    shaded += mix(base, accentColor.rgb, 0.35) * coreGlow;

    // Fresnel rim & iridescence
    vec3 rimCol = mix(accentColor.rgb, irid, 0.32);
    shaded += rimCol * fresnel * (0.55 + 0.45 * params.w);

    // Crisp speculars
    shaded += vec3(1.0, 0.98, 0.93) * (spec1 + spec2);

    // Hot process pulse tint near rim
    if (params.z > 0.5) {
        shaded += vec3(1.0, 0.36, 0.28) * fresnel * 0.45;
    }

    // Metric progress arc embedded directly on the sphere's front rim
    if (params.x > 0.5 && r > 0.78 && r < 0.91) {
        float ang = atan(p.x, p.y); // 0 at top, clockwise
        if (ang < 0.0) ang += 6.2831853;
        float frac = ang / 6.2831853;
        float ringMask = smoothstep(0.78, 0.80, r) * (1.0 - smoothstep(0.89, 0.91, r));
        if (frac <= params.y) {
            shaded = mix(shaded, accentColor.rgb * 1.15, ringMask * 0.92);
        } else {
            shaded = mix(shaded, vec3(0.18, 0.21, 0.28), ringMask * 0.45);
        }
    }

    float edgeAlpha = 1.0 - smoothstep(0.955, 1.0, r);
    float alpha = edgeAlpha * mix(0.86, 0.98, clamp(fresnel + params.x * 0.35, 0.0, 1.0));
    fragColor = vec4(shaded * alpha, alpha) * qt_Opacity;
}
