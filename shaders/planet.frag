#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 baseColor;
    vec4 accentColor;
    vec4 lightDir; // xyz = 3D light dir in view space (or 3D world velocity for Interloper), w = bodyTypeID
    vec4 params;   // x = loopTime, y = sunProgress (0..1), z = swellRatio, w = isLocked
    vec4 bakeInfo; // x = sphere radius in screen px, y = bake texture width (px), z = quadMultiplier
    vec4 camAngles;// x = camera yaw, y = camera pitch, zw = view-space sun XY for comet
};

layout(binding = 1) uniform sampler2D bakeTex;

const float PI  = 3.14159265;
const float TAU = 6.2831853;

const float TH_BUMP = 0.16;
const float BH_BUMP = 0.22;
const float BR_BUMP = 0.15;
const float IL_BUMP = 0.35;
const float TW_ASH_R0 = 0.52;  // Ash Twin: radius at height 0
const float TW_ASH_K  = 0.45;  // Ash Twin: radius per unit height
const float TW_EMB_R0 = 0.74;  // Ember Twin: radius at height 0
const float TW_EMB_K  = 0.30;  // Ember Twin: radius per unit height
const float SAND_LUMP_FREQ = 9.0;
const float SAND_LUMP_EPS  = 0.02;
const float SAND_LUMP_BUMP = 0.05;

float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
                   mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
                   mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.05;
        a *= 0.5;
    }
    return v;
}

mat3 rotateX(float a) {
    float c = cos(a), s = sin(a);
    return mat3(1, 0, 0, 0, c, -s, 0, s, c);
}

mat3 rotateY(float a) {
    float c = cos(a), s = sin(a);
    return mat3(c, 0, s, 0, 1, 0, -s, 0, c);
}

mat3 rotateZ(float a) {
    float c = cos(a), s = sin(a);
    return mat3(c, -s, 0, s, c, 0, 0, 0, 1);
}

mat3 worldToView() {
    float cy = cos(camAngles.x);
    float sy = -sin(camAngles.x);
    float cp = cos(camAngles.y);
    float sp = -sin(camAngles.y);
    mat3 Ry = mat3(cy, 0.0, -sy,   0.0, 1.0, 0.0,   sy, 0.0, cy);
    mat3 Rx = mat3(1.0, 0.0, 0.0,  0.0, cp, sp,     0.0, -sp, cp);
    return Rx * Ry;
}

float sdOctDrum(vec3 p, float r, float h) {
    vec2 q = abs(p.xz);
    float oct = max(max(q.x, q.y), (q.x + q.y) * 0.7071) - r;
    float cap = abs(p.y) - h;
    return max(oct, cap);
}

float sdBox3(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

vec2 mapSunStation(vec3 p, float t) {
    vec3 q = p;
    q.x = abs(q.x) - 0.48;

    float mainDrum = sdOctDrum(q, 0.25, 0.11);
    float upperTier = sdOctDrum(q - vec3(0.0, 0.07, 0.0), 0.17, 0.07);
    float lowerDish = sdOctDrum(q - vec3(0.0, -0.08, 0.0), 0.28, 0.035);
    float drum = min(mainDrum, min(upperTier, lowerDish));

    float panelRecess = sdOctDrum(q - vec3(0.0, 0.13, 0.0), 0.13, 0.03);
    float podDist = max(drum, -panelRecess);

    float ringR = abs(length(p.xz) - 0.48) - 0.032;
    float ringDist = max(ringR, abs(p.y) - 0.038);

    float bridgeStub = sdBox3(vec3(abs(p.x) - 0.26, p.y, p.z), vec3(0.14, 0.032, 0.055));
    vec3 archP = vec3(abs(p.x) - 0.12, p.y, p.z);
    float archRing = max(abs(length(archP.yz) - 0.065) - 0.018, abs(archP.x) - 0.018);
    float bridgeDist = min(bridgeStub, archRing);

    vec3 d1 = rotateZ(t * 0.7) * rotateX(t * 0.5) * (p - vec3( 0.035 * sin(t * 0.9),  0.025 * cos(t * 0.6),  0.02));
    vec3 d2 = rotateY(t * 0.8) * rotateX(t * 0.4) * (p - vec3(-0.040 * cos(t * 0.7), -0.020 * sin(t * 0.8), -0.03));
    float debDist = min(sdBox3(d1, vec3(0.022, 0.012, 0.018)),
                        sdBox3(d2, vec3(0.018, 0.014, 0.022)));

    float d = min(min(podDist, ringDist), min(bridgeDist, debDist));

    float matId = 2.0;
    if (d == podDist) {
        float ang = atan(q.z, q.x);
        float rib = abs(sin(ang * 4.0));
        float rad = length(q.xz);
        bool isSolarFace = (abs(q.y) > 0.085) && (rad < 0.235) && (rad > 0.055) && (rib > 0.18);
        bool isWindowSlit = (abs(q.y) < 0.032) && (rib > 0.45);
        if (isWindowSlit) matId = 3.0;
        else if (isSolarFace) matId = 1.0;
    } else if (d == bridgeDist && archRing < bridgeStub) {
        matId = 3.0;
    }
    return vec2(d, matId);
}

vec3 calcStationNormal(vec3 p, float t) {
    const float e = 0.0025;
    vec2 k = vec2(1.0, -1.0);
    return normalize(
        k.xyy * mapSunStation(p + k.xyy * e, t).x +
        k.yyx * mapSunStation(p + k.yyx * e, t).x +
        k.yxy * mapSunStation(p + k.yxy * e, t).x +
        k.xxx * mapSunStation(p + k.xxx * e, t).x
    );
}

vec2 dirToUV(vec3 p) {
    return vec2(atan(p.z, p.x) / TAU + 0.5,
                asin(clamp(p.y, -1.0, 1.0)) / PI + 0.5);
}

float bakeLod(float z) {
    float texelsPerPx = bakeInfo.y / (TAU * max(bakeInfo.x, 1.0));
    float l = log2(max(texelsPerPx, 0.001)) - 0.5 * log2(max(z, 0.2));
    return max(l, 0.0);
}

struct Baked {
    vec4  tex;
    vec3  nObj;
    float hBlur;
};

Baked readBaked(vec3 p, float lod, float k) {
    Baked b;
    vec2 uv = dirToUV(p);

    float du = exp2(lod) / bakeInfo.y;
    float dv = du * 2.0;

    b.tex = textureLod(bakeTex, uv, lod);
    float hE = textureLod(bakeTex, vec2(uv.x + du, uv.y), lod).a;
    float hW = textureLod(bakeTex, vec2(uv.x - du, uv.y), lod).a;
    float hN = textureLod(bakeTex, vec2(uv.x, clamp(uv.y + dv, 0.001, 0.999)), lod).a;
    float hS = textureLod(bakeTex, vec2(uv.x, clamp(uv.y - dv, 0.001, 0.999)), lod).a;

    float cosLat = max(sqrt(max(1.0 - p.y * p.y, 0.0)), 0.15);
    float gE = (hE - hW) / (2.0 * TAU * du * cosLat);
    float gN = (hN - hS) / (2.0 * PI * dv);

    vec3 E = vec3(-p.z, 0.0, p.x);
    E /= max(length(E), 0.0001);
    vec3 N = cross(E, p);

    b.nObj  = normalize(p - k * (gE * E + gN * N));
    b.hBlur = textureLod(bakeTex, uv, lod + 3.0).a;
    return b;
}

float tallRadius(int bt, float h) {
    if (bt == 2) return TW_ASH_R0 + TW_ASH_K * h;
    if (bt == 3) return TW_EMB_R0 + TW_EMB_K * h;
    return (bt == 4) ? 0.89 + 0.52 * (h - 0.54) : 0.80 + 0.70 * (h - 0.30);
}

float marchTall(vec2 uvv, mat3 M, int bt, float lod, float sl, out vec3 dirOut) {
    float r2 = dot(uvv, uvv);
    float rMax = (bt == 4) ? 1.24 : ((bt == 7) ? 1.32 : ((bt == 3) ? 1.14 : 1.10));
    dirOut = vec3(0.0, 0.0, 1.0);
    if (r2 >= rMax * rMax) return 0.0;
    float z0 = sqrt(rMax * rMax - r2);
    int N = (bt >= 4) ? 28 : 44;
    float dz = 2.0 * z0 / float(N);
    float best = -1.0e3;
    float bestZ = 0.0;
    float zPrev = z0;

    vec3 baseObj = M * vec3(uvv.x, -uvv.y, 0.0);
    vec3 zAxisObj = M[2];

    for (int i = 1; i <= N; i++) {
        float z = z0 - dz * float(i);
        float len = sqrt(r2 + z * z);
        vec3 dirObj = (baseObj + zAxisObj * z) / len;
        float h = max(textureLod(bakeTex, dirToUV(dirObj), lod).a, sl);
        float m = tallRadius(bt, h) - len;
        if (m > best) { best = m; bestZ = z; }
        if (m >= 0.0) {
            float zHi = zPrev;
            float zLo = z;
            for (int k = 0; k < 4; k++) {
                float zm = 0.5 * (zHi + zLo);
                float lm = sqrt(r2 + zm * zm);
                vec3 dObjM = (baseObj + zAxisObj * zm) / lm;
                float hm = max(textureLod(bakeTex, dirToUV(dObjM), lod).a, sl);
                if (lm <= tallRadius(bt, hm)) zLo = zm; else zHi = zm;
            }
            dirOut = normalize(vec3(uvv.x, -uvv.y, 0.5 * (zHi + zLo)));
            return 1.0;
        }
        zPrev = z;
    }
    dirOut = normalize(vec3(uvv.x, -uvv.y, bestZ));
    return smoothstep(-0.012, 0.0, best);
}

vec4 limbHalo(int bt, vec2 uvv, float r, float edgeR, vec3 Lv, float rb) {
    if (bt == 2 || bt == 3) {
        float g = exp(-(r - rb) * 4.2) * (1.0 - smoothstep(edgeR - 0.22, edgeR, r));
        float litSide = smoothstep(-0.7, 0.7, dot(normalize(vec2(uvv.x, -uvv.y) + 1e-5), normalize(Lv.xy + 1e-5)));
        g = clamp(g, 0.0, 1.0) * 0.62;
        vec3 hc = mix(vec3(0.10, 0.45, 0.42), vec3(1.0, 0.45, 0.12), litSide);
        float ga = g * (0.30 + 0.70 * litSide);
        return vec4(hc * ga, ga);
    }
    if (bt == 4) {
        float haloGlow = exp(-(r - 0.86) * 13.0) * (1.0 - smoothstep(edgeR - 0.20, edgeR, r));
        float litSide = smoothstep(-0.7, 0.7, dot(normalize(vec2(uvv.x, -uvv.y) + 1e-5), normalize(Lv.xy + 1e-5)));
        haloGlow = clamp(haloGlow, 0.0, 1.0) * (0.22 + 0.78 * litSide) * 0.75;
        return vec4(vec3(0.28, 0.55, 1.0) * haloGlow, haloGlow);
    }
    float haloGlow = exp(-(r - 0.80) * 6.5) * (1.0 - smoothstep(edgeR - 0.20, edgeR, r));
    haloGlow = clamp(haloGlow, 0.0, 1.0) * 0.8;
    return vec4(vec3(1.0, 0.38, 0.08) * haloGlow, haloGlow * 0.7);
}

// Soft outer aura for bodies that have no halo of their own (kept subtle on purpose).
// rb = silhouette radius at this pixel, edgeR = quad edge in uv units. Premultiplied output.
vec4 outerAura(int bt, float r, float rb, float edgeR, vec2 uvv, vec3 Lv) {
    float k = 11.0;
    float strength = 0.34;
    vec3 col = vec3(1.0);
    float lit = smoothstep(-0.7, 0.7, dot(normalize(vec2(uvv.x, -uvv.y) + 1e-5), normalize(Lv.xy + 1e-5)));
    if (bt == 5)      { col = vec3(0.62, 0.55, 0.46); k = 13.0; strength = 0.28; }
    else if (bt == 6) { col = vec3(1.00, 0.46, 0.16); strength = 0.36; }
    else if (bt == 8) { col = mix(vec3(0.65, 0.25, 0.55), vec3(0.25, 0.90, 0.85), lit); }
    else if (bt == 9) { col = vec3(0.60, 0.85, 0.30); }
    else if (bt == 11){ col = vec3(0.68, 0.52, 0.92); strength = 0.38; }
    float g = exp(-max(r - rb, 0.0) * k) * (1.0 - smoothstep(edgeR - 0.15, edgeR, r)) * strength;
    g *= 0.55 + 0.45 * lit;
    g = clamp(g, 0.0, 1.0);
    return vec4(col * g, g);
}

void main() {
    vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
    int bType = int(round(lightDir.w));
    vec3 L = normalize(vec3(lightDir.xy, max(0.25, lightDir.z)));
    float t = params.x;

    // The quad of the non-"tall" bodies is larger than the shader was designed for, to leave room
    // for the aura. uv is rescaled so the sphere keeps exactly the same size on screen.
    float qmQuad = (bakeInfo.z > 0.5) ? bakeInfo.z : 2.22;
    float qBase = (bType == 0) ? 2.95 : (bType == 10) ? 4.2 : (bType == 1) ? 2.8 : (bType == 11) ? 2.3 : 2.22;
    bool tallType = (bType == 2 || bType == 3 || bType == 4 || bType == 7);
    float uvScale = qmQuad / qBase;
    if (!tallType) uv *= uvScale;

    // =========================================================
    // 0. THE SUN
    // =========================================================
    if (bType == 0) {
        float r = length(uv);
        if (r > 1.0) discard;
        float coreR = 0.62;

        if (r <= coreR) {
            vec2 suv = uv / coreR;
            float sz = sqrt(max(0.0, 1.0 - dot(suv, suv)));
            vec3 sNorm = rotateY(t * 0.12) * (transpose(worldToView()) * vec3(suv.x, -suv.y, sz));

            float cells = fbm(sNorm * 5.5 + vec3(t * 0.22));
            float swell = params.z;

            vec3 cHot = mix(vec3(1.0, 0.96, 0.75), vec3(1.0, 0.42, 0.08), swell);
            vec3 cMid = mix(vec3(0.98, 0.55, 0.08), vec3(0.72, 0.08, 0.01), swell);
            vec3 col = mix(cMid, cHot, cells);
            col += pow(1.0 - sz, 2.0) * vec3(1.0, 0.75, 0.3) * 0.55;

            float aa = smoothstep(coreR, coreR - 0.02, r);
            fragColor = vec4(col, 1.0) * aa * qt_Opacity;
        } else {
            float ang = atan(uv.y, uv.x);
            float promLoop = sin(ang * 7.0 + t * 0.45) * cos(ang * 3.0 - t * 0.25);
            float flareDist = coreR + 0.14 * (0.5 + 0.5 * promLoop) * (1.0 + params.z * 1.5);
            float flare = exp(-pow((r - flareDist) * 16.0, 2.0)) * smoothstep(0.2, 0.9, promLoop);

            float glow = pow(max(0.0, (1.0 - r) / (1.0 - coreR)), 2.2);
            vec3 gCol = mix(vec3(1.0, 0.60, 0.14), vec3(0.95, 0.18, 0.02), params.z);
            vec3 flareCol = mix(vec3(1.0, 0.90, 0.45), vec3(1.0, 0.45, 0.10), params.z);

            vec3 finalGlow = gCol * glow * 0.85 + flareCol * flare * 0.95;
            float totalA = clamp(glow * 0.85 + flare * 0.95, 0.0, 1.0);
            fragColor = vec4(finalGlow, totalA) * qt_Opacity;
        }
        return;
    }

    // =========================================================
    // 1. SUN STATION
    // =========================================================
    if (bType == 1) {
        if (length(uv) > uvScale) discard;

        mat3 V = worldToView();
        mat3 Rstat = rotateY(t * 0.32) * rotateX(0.42 + 0.18 * sin(t * 0.15)) * rotateZ(0.28);
        mat3 viewToObj = Rstat * transpose(V);
        mat3 objToView = V * transpose(Rstat);

        vec3 ro = viewToObj * vec3(uv.x, -uv.y, 1.25);
        vec3 rd = normalize(viewToObj * vec3(0.0, 0.0, -1.0));

        float tHit = 0.25;
        float minD = 10.0;
        vec2 res = vec2(10.0, 0.0);
        bool hit = false;

        for (int i = 0; i < 20; i++) {
            vec3 p = ro + rd * tHit;
            res = mapSunStation(p, t);
            minD = min(minD, res.x);
            if (res.x < 0.003) {
                hit = true;
                break;
            }
            tHit += res.x * 0.92;
            if (tHit > 2.4) break;
        }

        float stFade = 1.0 - smoothstep(uvScale - 0.15, uvScale, length(uv));
        float stG = exp(-minD * 11.0) * 0.40 * stFade;
        vec4 stAura = vec4(vec3(1.0, 0.80, 0.45) * stG, stG);

        vec3 pMid = ro + rd * 1.25;
        float warpBeam = exp(-pow(pMid.x * 8.5, 2.0)) * exp(-dot(pMid.yz, pMid.yz) * 320.0);
        vec3 beamCol = mix(vec3(1.0, 0.78, 0.35), vec3(0.45, 0.88, 1.0), 0.5 + 0.5 * sin(pMid.x * 35.0 - t * 6.0));

        if (!hit) {
            vec4 beamC = (warpBeam > 0.02) ? vec4(beamCol * warpBeam * 0.85, warpBeam * 0.85) : vec4(0.0);
            if (beamC.a + stAura.a > 0.003) {
                fragColor = (beamC + stAura * (1.0 - beamC.a)) * qt_Opacity;
                return;
            }
            discard;
        }

        vec3 pos = ro + rd * tHit;
        vec3 nObj = calcStationNormal(pos, t);
        vec3 nView = normalize(objToView * nObj);

        float matId = res.y;
        vec3 q = vec3(abs(pos.x) - 0.48, pos.y, pos.z);

        vec3 nomaiGold  = mix(vec3(0.76, 0.58, 0.24), vec3(0.96, 0.82, 0.46), 0.5 + 0.5 * nObj.y);
        vec3 bronzeDark = vec3(0.38, 0.26, 0.14);

        vec3 col = nomaiGold;
        float specPow = 28.0;
        float specStr = 0.55;
        vec3 emissive = vec3(0.0);

        if (matId < 1.5) {
            float radGrid = smoothstep(0.03, 0.07, abs(fract(length(q.xz) * 18.0) - 0.5));
            float angGrid = smoothstep(0.04, 0.09, abs(fract(atan(q.z, q.x) * 8.0 / PI) - 0.5));
            float cellMask = radGrid * angGrid;
            vec3 panelBlue = mix(vec3(0.10, 0.22, 0.38), vec3(0.18, 0.42, 0.62), 0.5 + 0.5 * sin(length(q.xz) * 28.0));
            col = mix(nomaiGold * 0.85, panelBlue, cellMask);
            specPow = 48.0;
            specStr = 0.90;
        } else if (matId > 2.5) {
            col = vec3(1.0, 0.88, 0.55);
            emissive = mix(vec3(1.0, 0.72, 0.28), vec3(0.45, 0.90, 1.0), step(abs(pos.x), 0.20)) * 1.15;
        } else {
            float trim = smoothstep(0.04, 0.08, abs(fract(q.y * 14.0) - 0.5));
            col = mix(bronzeDark, nomaiGold, trim);
        }

        float ndl = dot(nView, L);
        float halfLambert = ndl * 0.5 + 0.5;
        float diff = mix(0.32, 1.12, smoothstep(0.20, 0.68, halfLambert));

        vec3 Hh = normalize(L + vec3(0.0, 0.0, 1.0));
        float spec = pow(max(dot(nView, Hh), 0.0), specPow) * specStr * step(0.0, ndl);

        float sunHeat = pow(max(ndl, 0.0), 1.8) * (0.45 + 0.75 * params.z);
        vec3 heatCol = mix(vec3(1.0, 0.62, 0.18), vec3(1.0, 0.28, 0.05), params.z) * sunHeat;

        vec3 finalCol = col * diff + vec3(1.0, 0.92, 0.72) * spec + heatCol + emissive + beamCol * warpBeam * 0.45;
        float edgeAA = smoothstep(0.008, 0.0, minD);
        fragColor = (vec4(finalCol * edgeAA, edgeAA) + stAura * (1.0 - edgeAA)) * qt_Opacity;
        return;
    }

    // =========================================================
    // 6. BRITTLE HOLLOW
    // =========================================================
    if (bType == 6) {
        float r = length(uv);
        if (r > uvScale) discard;

        mat3 V   = worldToView();
        mat3 Vt  = transpose(V);
        mat3 Rp  = rotateY(t * 0.08);
        mat3 Rpi = transpose(Rp);

        float holeThresh = 0.22 + 0.14 * pow(clamp(params.y, 0.0, 1.0), 1.35);

        vec3 limbView = normalize(vec3(uv.x, -uv.y, sqrt(max(0.03, 0.82 - r * r))));
        vec3 limbDir  = Rp * (Vt * limbView);
        float hLimb   = textureLod(bakeTex, dirToUV(limbDir), bakeLod(0.35) + 0.5).a;
        float limbMountain = max(hLimb - 0.42, 0.0);
        float rs = 0.88 + 0.18 * limbMountain;
        if (r > rs) {
            fragColor = outerAura(6, r, rs, uvScale, uv, L) * qt_Opacity;
            return;
        }

        float z = sqrt(max(0.0, rs * rs - r * r)) / rs;
        vec3 nFrontGeo = normalize(vec3(uv.x / rs, -uv.y / rs, z));
        float lodB = bakeLod(max(z, 0.2));

        vec3 pBase = Rp * (Vt * nFrontGeo);
        float hPre = textureLod(bakeTex, dirToUV(pBase), lodB + 1.0).a;
        float heightOffset = (max(hPre, holeThresh) - 0.45) * 0.14;
        vec3 nFrontParallax = normalize(nFrontGeo + vec3(0.0, 0.0, heightOffset));
        vec3 pFront = Rp * (Vt * nFrontParallax);

        Baked f = readBaked(pFront, lodB, BH_BUMP);
        vec3 nF = normalize(mix(V * (Rpi * f.nObj), nFrontGeo, 0.15));

        float frontSolid = smoothstep(holeThresh, holeThresh + 0.022, f.tex.a);

        vec3 nWall = normalize(vec3(uv.x / rs, -uv.y / rs, max(z - 0.11, 0.025)));
        vec4 texWall = textureLod(bakeTex, dirToUV(Rp * (Vt * nWall)), lodB);
        float wallSolid = smoothstep(holeThresh + 0.015, holeThresh + 0.040, texWall.a);
        float bevelCliff = smoothstep(holeThresh - 0.035, holeThresh, f.tex.a) * (1.0 - frontSolid);
        float wallMask = clamp(max(bevelCliff, wallSolid) * (1.0 - frontSolid), 0.0, 1.0);
        float frontAlpha = clamp(frontSolid + wallMask, 0.0, 1.0);

        float ndlGeo = dot(nFrontGeo, L);
        float ndl    = dot(nF, L);
        float halfLambert = ndl * 0.5 + 0.5;
        float lightBand = mix(0.48, 1.08, smoothstep(0.24, 0.58, halfLambert));
        lightBand += clamp((ndl - ndlGeo) * 1.15, -0.32, 0.32) * smoothstep(-0.20, 0.45, ndlGeo);
        float cavity = clamp(1.0 + (f.tex.a - f.hBlur) * 2.8, 0.52, 1.28);

        float magmaMask = smoothstep(0.32, 0.65, f.tex.r - f.tex.b) * (1.0 - smoothstep(0.45, 0.58, f.tex.a));
        vec3 frontSurfCol = f.tex.rgb * cavity * lightBand + vec3(1.0, 0.42, 0.08) * magmaMask * 0.95;

        vec3 wallRockCol = mix(vec3(0.16, 0.14, 0.26), vec3(0.48, 0.29, 0.22), bevelCliff);
        float sunWallLit  = 0.40 + 0.55 * max(ndlGeo, 0.0);
        float bhUnderGlow = exp(-r * 2.0) * 0.80;
        vec3 cliffCol = wallRockCol * sunWallLit + vec3(0.48, 0.30, 0.92) * bhUnderGlow;

        vec3 frontCol = mix(cliffCol, frontSurfCol, frontSolid);

        float terminator = exp(-pow((ndlGeo + 0.05) * 4.2, 2.0)) * 0.20;
        float rim = pow(1.0 - z, 2.8);
        vec3 atmoCol = mix(vec3(0.52, 0.28, 0.82), vec3(0.38, 0.78, 0.96), smoothstep(-0.2, 0.4, ndlGeo));
        frontCol += (vec3(1.0, 0.55, 0.25) * terminator + atmoCol * rim * 0.75) * frontSolid;

        float bhR = 0.16 + 0.032 * clamp(params.y, 0.0, 1.0);
        float eventHorizon = 1.0 - smoothstep(bhR - 0.012, bhR + 0.010, r);

        float lensStrength = (bhR * bhR * 1.40) / max(r * r, bhR * bhR * 0.65);
        vec2 uvL = (uv / rs) * (1.0 - lensStrength);
        float rL2 = clamp(dot(uvL, uvL), 0.0, 0.98);
        vec3 nBack = normalize(vec3(uvL.x, -uvL.y, -sqrt(1.0 - rL2)));

        vec3 pBack = Rp * (Vt * nBack);
        vec4 bk = textureLod(bakeTex, dirToUV(pBack), lodB + 1.0);
        float backMask = smoothstep(holeThresh - 0.04, holeThresh + 0.02, bk.a);

        vec3 cavernRock = bk.rgb * vec3(0.38, 0.32, 0.62) * (0.50 + 0.70 * exp(-r * 1.8));
        float crystalGlow = smoothstep(0.62, 0.78, fract(bk.a * 17.0)) * backMask;
        float cityGlow    = smoothstep(0.75, 0.88, fract(bk.r * 23.0)) * backMask * (1.0 - abs(pBack.y));
        vec3 cavernCol = cavernRock
                       + vec3(0.35, 0.78, 1.00) * crystalGlow * 0.60
                       + vec3(1.00, 0.78, 0.35) * cityGlow * 0.80;

        float distFromEH = max(r - bhR, 0.0);
        float photonRing = exp(-pow((r - bhR * 1.05) * 24.0, 2.0));
        float swirl      = 0.75 + 0.25 * sin(atan(uv.y, uv.x) * 3.0 - t * 1.4 + r * 12.0);
        float accretion  = exp(-distFromEH * 5.5) * swirl;
        vec3 bhGlowCol   = vec3(0.68, 0.85, 1.00) * photonRing * 1.60
                         + vec3(0.50, 0.22, 0.95) * accretion * 0.85
                         + vec3(0.82, 0.32, 0.68) * exp(-distFromEH * 11.0) * 0.50;

        vec3 interiorCol = cavernCol * backMask + bhGlowCol * (1.0 - eventHorizon);
        interiorCol = mix(interiorCol, vec3(0.01, 0.01, 0.03), eventHorizon);
        float interiorA = clamp(max(backMask * 0.94, max(eventHorizon, accretion * 0.85)), 0.0, 1.0);

        vec3 outPre = frontCol * frontAlpha + (1.0 - frontAlpha) * interiorCol * interiorA;
        float outA  = frontAlpha + (1.0 - frontAlpha) * interiorA;
        float aa    = smoothstep(rs, rs - 0.025, r);
        fragColor   = (vec4(outPre * aa, outA * aa) + ((aa < 0.999) ? outerAura(6, r, rs, uvScale, uv, L) * (1.0 - aa) : vec4(0.0))) * qt_Opacity;
        return;
    }

    // =========================================================
    // 9. DARK BRAMBLE
    // =========================================================
    if (bType == 9) {
        float r = length(uv);
        if (r > uvScale) discard;

        mat3 V  = worldToView();
        mat3 Vt = transpose(V);
        mat3 Rb = rotateY(t * 0.05);

        vec3 limbView = normalize(vec3(uv.x, -uv.y, sqrt(max(0.03, 0.82 - r * r))));
        float hLimb = textureLod(bakeTex, dirToUV(Rb * (Vt * limbView)), bakeLod(0.35) + 0.3).a;
        float rs = 0.78 + 0.21 * clamp(hLimb * 1.25, 0.0, 1.0);
        if (r > rs) {
            fragColor = outerAura(9, r, rs, uvScale, uv, L) * qt_Opacity;
            return;
        }

        float z = sqrt(max(0.0, rs * rs - r * r)) / rs;
        float lodB = bakeLod(max(z, 0.2));

        vec3 nFront = vec3(uv.x / rs, -uv.y / rs, z);
        vec3 nBack  = vec3(uv.x / rs, -uv.y / rs, -z);

        Baked f = readBaked(Rb * (Vt * nFront), lodB, BR_BUMP);
        vec3 nF = normalize(V * (transpose(Rb) * f.nObj));
        float pF = smoothstep(0.35, 0.65, f.tex.r);
        float vF = smoothstep(0.25, 0.55, f.tex.b);
        float dlF = dot(nF, L) * 0.5 + 0.5;
        float litF = mix(0.12, 1.30, smoothstep(0.22, 0.82, dlF));
        float aoF = clamp(1.0 + (f.tex.a - f.hBlur) * 4.5, 0.22, 1.25);
        float rimF = pow(1.0 - z, 2.2);

        float tone = f.tex.g;
        vec3 barkDark = vec3(0.040, 0.034, 0.016);
        vec3 barkMid  = vec3(0.25, 0.175, 0.078);
        vec3 barkWarm = vec3(0.55, 0.32, 0.12);
        vec3 moss     = vec3(0.13, 0.17, 0.06);
        vec3 vineBase = mix(barkDark, barkMid, 0.30 + 0.45 * tone);
        vineBase = mix(vineBase, moss, smoothstep(0.55, 0.9, f.tex.a) * 0.50 * (1.0 - tone));
        vec3 vineF = vineBase * litF * aoF
                   + barkWarm * pow(max(dlF, 0.0), 3.0) * smoothstep(0.45, 0.9, tone) * 0.22 * aoF;
        float tip = smoothstep(0.93, 1.02, f.tex.a) * vF;
        vineF = mix(vineF, vec3(0.62, 0.55, 0.38) * litF, tip * 0.7);
        vineF += vec3(0.10, 0.22, 0.30) * rimF * 0.35 * vF;

        vec3 Hh = normalize(L + vec3(0.0, 0.0, 1.0));
        float glint = pow(max(dot(nF, Hh), 0.0), 38.0);
        float fres = pow(1.0 - clamp(nF.z, 0.0, 1.0), 1.6);
        vec3 glassDeep = vec3(0.025, 0.085, 0.125);
        vec3 glassLite = vec3(0.30, 0.58, 0.72);
        vec3 glassF = mix(glassDeep, glassLite, clamp(0.25 * tone + 0.55 * litF * (0.4 + fres) + 0.5 * fres, 0.0, 1.0));
        glassF += vec3(0.85, 0.95, 1.0) * glint * 0.45;
        float glassA = pF * clamp(0.40 + 0.55 * fres + 0.35 * glint, 0.0, 0.92);

        float shellK = 1.0;
        if (r < 0.80) {
            float winR = r + (fbm(vec3(uv * 2.0 + 13.0, 1.0)) - 0.5) * 0.30;
            shellK = mix(0.06, 1.0, smoothstep(0.14, 0.62, winR));
        }
        vF *= shellK;
        glassA *= mix(0.10, 1.0, shellK);

        float vOnly = vF * (1.0 - glassA);
        vec3 frontPre = vineF * vOnly + glassF * glassA;
        float frontA = clamp(vOnly + glassA, 0.0, 1.0);

        float ang = atan(uv.y, uv.x);
        float rr = max(r, 0.001);
        float knotA = 0.0;
        vec3 knotCol = vec3(0.0);
        float wobR = 0.0;
        if (rr < 0.70) {
            float wob  = fbm(vec3(uv * 3.3, t * 0.035)) - 0.5;
            float wob2 = fbm(vec3(uv * 4.1 + 7.0, t * 0.03 + 3.0)) - 0.5;

            float sp1 = ang * 5.0 + log(rr) * 3.4 + wob * 14.0 + t * 0.02;
            float sp2 = ang * 3.0 - log(rr) * 2.4 + wob2 * 12.0 - t * 0.015;
            float w1 = mix(0.80, 0.42, smoothstep(0.08, 0.55, rr));
            float w2 = mix(0.72, 0.34, smoothstep(0.08, 0.55, rr));
            float wv = 0.62 + 0.75 * fbm(vec3(uv * 3.8 + 3.0, 0.7));
            w1 *= wv;
            w2 *= 1.35 - 0.7 * wv;
            float a1 = abs(sin(sp1));
            float a2 = abs(sin(sp2));
            float rope1 = 1.0 - smoothstep(w1 - 0.14, w1, a1);
            float rope2 = (1.0 - smoothstep(w2 - 0.14, w2, a2)) * 0.9;
            float prof1 = sqrt(max(1.0 - (a1 / w1) * (a1 / w1), 0.0));
            float prof2 = sqrt(max(1.0 - (a2 / w2) * (a2 / w2), 0.0));
            float knotMask = smoothstep(0.062, 0.100, rr) * (1.0 - smoothstep(0.38, 0.66, rr));
            knotA = max(rope1, rope2) * knotMask;
            float prof = (rope1 >= rope2) ? prof1 : prof2;
            float fiberK = 0.6 + 0.4 * sin(ang * 40.0 + log(rr) * 25.0 + wob * 14.0);
            float coreLit = exp(-rr * 3.2);
            float rimLit = pow(1.0 - prof, 1.5);
            knotCol = vec3(0.030, 0.024, 0.012) * (0.4 + 0.6 * prof)
                         + vec3(0.72, 0.44, 0.18) * coreLit * (0.10 * prof + 0.55 * rimLit) * fiberK;
            wobR = wob;
        }
        float halo = exp(-rr * rr * 8.0);
        float rays = pow(0.5 + 0.5 * sin(ang * 13.0 + wobR * 9.0 + t * 0.05), 3.0) * exp(-rr * 3.4);
        vec3 fogCol = vec3(0.95, 0.88, 0.66);
        float coreMask = 1.0 - smoothstep(0.040, 0.082, rr);
        float coreGlow = exp(-rr * 9.0);

        vec4 bk = textureLod(bakeTex, dirToUV(Rb * (Vt * nBack)), lodB);
        float pB = smoothstep(0.35, 0.65, bk.r);
        float vB = smoothstep(0.25, 0.55, bk.b);
        float backA = max(pB * 0.6, vB);
        vec3 backCol = mix(vec3(0.03, 0.06, 0.09), vec3(0.07, 0.045, 0.025) * (0.6 + 0.8 * bk.g), vB) * backA;

        vec3 interiorPre = backCol
                         + fogCol * halo * 0.34
                         + fogCol * rays * 0.20 * (1.0 - knotA * 0.8);
        interiorPre = interiorPre * (1.0 - knotA) + knotCol * knotA;
        interiorPre += fogCol * coreGlow * 0.75 + vec3(1.0, 0.97, 0.84) * coreMask * 1.5;
        float interiorA = clamp(max(max(backA * 0.80, halo * 0.55), max(knotA, coreMask)), 0.0, 1.0);

        vec3 outPre = frontPre + (1.0 - frontA) * interiorPre;
        float outA = frontA + (1.0 - frontA) * interiorA;
        float aa = smoothstep(rs, rs - 0.02, r);
        fragColor = (vec4(outPre * aa, outA * aa) + ((aa < 0.999) ? outerAura(9, r, rs, uvScale, uv, L) * (1.0 - aa) : vec4(0.0))) * qt_Opacity;
        return;
    }

    // =========================================================
    // 10. THE INTERLOPER (True 3D World-Anchored Raymarch)
    // =========================================================
    if (bType == 10) {
        vec3 worldFwd = normalize(lightDir.xyz);
        vec3 worldUp  = vec3(0.0, 1.0, 0.0);
        if (abs(dot(worldFwd, worldUp)) > 0.9) worldUp = vec3(0.0, 0.0, 1.0);
        vec3 worldRight = normalize(cross(worldFwd, worldUp));
        worldUp = cross(worldRight, worldFwd);

        mat3 worldToComet = mat3(
            worldFwd.x, worldUp.x, worldRight.x,
            worldFwd.y, worldUp.y, worldRight.y,
            worldFwd.z, worldUp.z, worldRight.z
        );

        mat3 V = worldToView();
        mat3 viewToWorld = transpose(V);
        mat3 viewToComet = worldToComet * viewToWorld;

        float fovDist = 2.4;
        vec3 rayOriginComet = viewToComet * vec3(0.0, 0.0, fovDist);
        vec3 rayDirComet    = normalize(viewToComet * vec3(uv.x, -uv.y, -fovDist));

        float tHit = 0.5;
        bool hitBody = false;
        vec3 pComet = vec3(0.0);

        for (int i = 0; i < 48; i++) {
            vec3 p = rayOriginComet + rayDirComet * tHit;

            float x = p.x;
            float rCross = length(p.yz);

            float baseR = 0.28;
            if (x > 0.0) {
                float k = x / 0.32;
                if (k <= 1.0) baseR = 0.28 * sqrt(max(0.0, 1.0 - k * k));
                else baseR = -0.1;
            } else {
                float rearT = clamp(-x / 0.45, 0.0, 1.0);
                float angle = atan(p.z, p.y);
                float teeth = sin(angle * 8.0) * cos(angle * 4.0 + 0.5);
                teeth = pow(0.5 + 0.5 * teeth, 2.0) * rearT * 0.14;
                baseR = (0.28 - 0.06 * rearT) + teeth;
                if (x < -0.46 - teeth) baseR = -0.1;
            }

            float d = rCross - baseR;

            if (d < 0.002 && x <= 0.34 && x >= -0.58) {
                hitBody = true;
                pComet = p;
                break;
            }

            tHit += max(d * 0.6, 0.006);
            if (tHit > 4.5) break;
        }

        float tailAlpha = 0.0;
        vec3 tailCol = vec3(0.0);

        // closest approach of this view ray to the comet's axis (the old x=0 plane test
        // put almost every pixel at tailDist = 0, so the tail was nearly invisible)
        float yzLen2 = dot(rayDirComet.yz, rayDirComet.yz);
        float tTailAxis = -dot(rayOriginComet.yz, rayDirComet.yz) / max(yzLen2, 1.0e-4);
        vec3 pTail = rayOriginComet + rayDirComet * max(tTailAxis, 0.0);

        {
            float tailDist = clamp((-pTail.x) / 1.6, 0.0, 1.0);
            float tailRad  = length(pTail.yz);

            float coneR = 0.22 + tailDist * 0.55;
            float coreR = 0.10 + tailDist * 0.25;

            float edgeFade = smoothstep(0.0, 0.12, tailDist) * smoothstep(1.0, 0.70, tailDist);
            float radFade  = smoothstep(coneR * 1.8, coneR * 0.3, tailRad);

            float streak = fbm(vec3(pTail.x * 5.0 - t * 3.0, pTail.y * 10.0, pTail.z * 10.0));
            float coreGas = exp(-(tailRad * tailRad) / (coreR * coreR * 0.4)) * (0.8 + 0.4 * streak);
            float comaGas = exp(-(tailRad * tailRad) / (coneR * coneR * 0.8));

            vec3 cWhiteCyan = vec3(0.85, 0.96, 1.0);
            vec3 cDeepBlue  = vec3(0.18, 0.42, 0.85);
            vec3 cOuterComa = vec3(0.08, 0.15, 0.45);

            tailCol = mix(cDeepBlue, cWhiteCyan, coreGas);
            tailCol = mix(cOuterComa, tailCol, comaGas);
            tailAlpha = clamp((coreGas * 0.95 + comaGas * 0.45) * edgeFade * radFade, 0.0, 0.85);
        }

        float comaD = length(cross(rayOriginComet, rayDirComet));
        float comaG = exp(-max(comaD - 0.30, 0.0) * 7.0) * 0.28 * (1.0 - smoothstep(0.80, 1.0, length(uv)));
        vec4 coma = vec4(vec3(0.65, 0.85, 1.0) * comaG, comaG);

        if (hitBody) {
            vec3 nLocal = (pComet.x > 0.0)
                ? normalize(vec3(pComet.x * 1.5, pComet.y, pComet.z))
                : normalize(vec3(pComet.x * 0.4, pComet.y, pComet.z));
            vec3 nView = normalize(V * (transpose(worldToComet) * nLocal));

            vec3 texDir = normalize(pComet);
            Baked b = readBaked(texDir, bakeLod(max(nView.z, 0.2)), IL_BUMP);

            // True view-space direction toward the Sun passed in camAngles.zw
            vec3 actualL = normalize(vec3(camAngles.zw, 0.35));
            float ndl = dot(nView, actualL);
            float halfLambert = ndl * 0.5 + 0.5;
            float lit = mix(0.35, 1.15, smoothstep(0.15, 0.80, halfLambert));

            vec3 Hh = normalize(actualL + vec3(0.0, 0.0, 1.0));
            float spec = pow(max(dot(nView, Hh), 0.0), 38.0) * 0.85 * step(0.0, ndl);

            float rim = pow(1.0 - max(nView.z, 0.0), 2.4);

            vec3 surfCol = b.tex.rgb * lit + vec3(1.0) * spec + vec3(0.4, 0.8, 1.0) * rim * 0.5;

            if (pComet.x < -0.15) {
                float shadow = smoothstep(-0.15, -0.45, pComet.x);
                surfCol = mix(surfCol, surfCol * 0.35, shadow * 0.8);
            }

            vec3 finalCol = mix(surfCol, tailCol, tailAlpha * 0.25);
            fragColor = vec4(finalCol, 1.0) * qt_Opacity;
            return;
        }

        if (tailAlpha > 0.001 || coma.a > 0.002) {
            fragColor = (vec4(tailCol * tailAlpha, tailAlpha) + coma * (1.0 - tailAlpha)) * qt_Opacity;
            return;
        }

        discard;
    }

    // =========================================================
    // 11. QUANTUM MOON
    // =========================================================
    if (bType == 11) {
        float r = length(uv);
        if (r > uvScale) discard;
        if (r > 0.96) {
            fragColor = outerAura(11, r, 0.96, uvScale, uv, L) * qt_Opacity;
            return;
        }

        float z = sqrt(max(0.0, 0.92 - r * r));
        vec3 pNorm = normalize(vec3(uv.x, -uv.y, z));

        mat3 V = worldToView();
        vec3 pWorld = transpose(V) * pNorm;

        float clouds = fbm(pWorld * 3.6 + vec3(t * 0.06, -t * 0.03, t * 0.05));

        vec3 colCore = vec3(0.52, 0.49, 0.58);
        vec3 colPeak = vec3(0.82, 0.78, 0.88);
        vec3 moonCol = mix(colCore, colPeak, smoothstep(0.25, 0.75, clouds));

        float diff = max(0.22, dot(pNorm, L) * 0.6 + 0.4);
        float rim = pow(1.0 - z, 2.4);

        vec3 auraCol = vec3(0.68, 0.52, 0.92);
        vec3 finalCol = moonCol * diff + auraCol * (rim * 0.65);

        float edgeAA = smoothstep(0.96, 0.92, r);
        fragColor = (vec4(finalCol * edgeAA, edgeAA) + ((edgeAA < 0.999) ? outerAura(11, r, 0.96, uvScale, uv, L) * (1.0 - edgeAA) : vec4(0.0))) * qt_Opacity;
        return;
    }

    // =========================================================
    // STANDARD / DISPLACED PLANETS (2, 3, 4, 5, 7, 8)
    // =========================================================
    float qm = (bakeInfo.z > 0.5) ? bakeInfo.z : 2.22;
    bool tw = (bType == 2 || bType == 3);
    bool tall = (bType == 4 || bType == 7 || tw);
    float qs = tall ? qm / 2.22 : 1.0;
    uv *= qs;
    float edgeR = tall ? qs : uvScale;
    float r = length(uv);
    if (r > edgeR) discard;

    mat3 Vw = worldToView();
    mat3 Vt = transpose(Vw);
    mat3 Rp = rotateY(t * 0.12);
    mat3 Rpi = transpose(Rp);

    float rs = 0.94;
    if (bType == 5) {
        vec3 limbView = normalize(vec3(uv.x, -uv.y, sqrt(max(0.03, 0.84 - r * r))));
        vec3 limbDir  = Rp * (Vt * limbView);
        float hLimb   = textureLod(bakeTex, dirToUV(limbDir), bakeLod(0.35)).a;
        rs = 0.80 + 0.567 * (hLimb - 0.35);
    }

    float sandL = -1.0;
    if (bType == 2) sandL = mix(1.04, 0.34, params.y);
    else if (bType == 3) {
        float pe = params.y;
        sandL = 0.08 + 0.50 * smoothstep(0.0, 0.62, pe) + 0.30 * smoothstep(0.72, 1.0, pe);
    }
    float Rn = tw ? tallRadius(bType, sandL) : ((bType == 4) ? 0.89 : ((bType == 7) ? 0.80 : rs));
    float cov = 1.0;
    vec4 haloC = vec4(0.0);
    vec3 marchDir = vec3(0.0, 0.0, 1.0);
    float tmix = 0.0;

    if (tall) {
        haloC = limbHalo(bType, uv, r, edgeR, L, Rn);
        float rIn = tw ? Rn - 0.03 : Rn - 0.12;
        if (r > rIn) {
            float cM = marchTall(uv, Rp * Vt, bType, bakeLod(0.35) + (tw ? 0.3 : 0.8), sandL, marchDir);
            tmix = tw ? smoothstep(rIn, rIn + 0.06, r) : smoothstep(rIn, Rn - 0.04, r);
            cov = mix(1.0, cM, tmix);
        }
        if (cov <= 0.001) {
            fragColor = haloC * qt_Opacity;
            return;
        }
    } else if (r > rs) {
        fragColor = outerAura(bType, r, rs, edgeR, uv, L) * qt_Opacity;
        return;
    }

    float z = sqrt(max(0.0, Rn * Rn - r * r)) / Rn;
    vec3 viewNorm = normalize(vec3(uv.x / Rn, -uv.y / Rn, z));
    if (tall && tmix > 0.0) {
        viewNorm = normalize(mix(viewNorm, marchDir, tmix));
        z = max(viewNorm.z, 0.0);
    }
    vec3 pCoord = Rp * (Vt * viewNorm);

    vec3 surf = baseColor.rgb;
    float atmosphereRimStrength = 0.45;
    vec3 atmoColor = accentColor.rgb;
    vec3 shadeN = viewNorm;
    float cavity = 1.0;
    float waterMask = 0.0;
    vec3 emissive = vec3(0.0);

    if (tw) {
        Baked b = readBaked(pCoord, bakeLod(z), (bType == 2) ? 0.20 : 0.22);
        float hs = b.tex.a;
        float isSand = 1.0 - smoothstep(sandL - 0.02, sandL + 0.02, hs);
        vec3 sandA = vec3(0.80, 0.66, 0.44);
        vec3 sandB = vec3(0.95, 0.83, 0.61);
        vec3 sandCol;
        vec3 sandNObj;
        if (bType == 2) {
            vec3 Eo = normalize(vec3(-pCoord.z, 0.0, pCoord.x) + vec3(1.0e-4, 0.0, 0.0));
            vec3 No = cross(Eo, pCoord);
            vec3 q = pCoord * SAND_LUMP_FREQ + vec3(3.1, 1.3, 7.7);
            float h0 = fbm(q);
            float hE = fbm(q + Eo * (SAND_LUMP_EPS * SAND_LUMP_FREQ));
            float hN = fbm(q + No * (SAND_LUMP_EPS * SAND_LUMP_FREQ));
            vec3 gH = (hE - h0) * Eo + (hN - h0) * No;
            sandNObj = normalize(pCoord - gH * (SAND_LUMP_BUMP / SAND_LUMP_EPS));
            sandCol = mix(sandA, sandB, 0.25 + 0.55 * smoothstep(0.30, 0.72, h0));
        } else {
            float ph = pCoord.y * 46.0 + 7.0 * fbm(pCoord * 3.4 + vec3(1.7, 4.1, 2.9));
            sandCol = mix(sandA, sandB, 0.40 + 0.30 * smoothstep(0.15, 0.85, 0.5 + 0.5 * sin(ph)));
            vec3 tN = normalize(vec3(0.0, 1.0, 0.0) - pCoord * pCoord.y);
            sandNObj = normalize(pCoord + tN * (cos(ph) * 0.055));
        }
        surf = mix(b.tex.rgb, sandCol, isSand);
        vec3 nB = Vw * (Rpi * b.nObj);
        vec3 nS = Vw * (Rpi * sandNObj);
        shadeN = normalize(mix(nB, nS, isSand));
        float rockAO = mix(0.78, 1.0, smoothstep(0.10, 0.46, hs));
        cavity = mix(clamp(1.0 + (hs - b.hBlur) * 3.0, 0.50, 1.20) * rockAO, 1.0, isSand);
        atmoColor = (bType == 2) ? vec3(0.90, 0.62, 0.36) : vec3(0.95, 0.52, 0.30);
        atmosphereRimStrength = (bType == 2) ? 0.35 : 0.50;
    } else if (bType == 4) {
        Baked b = readBaked(pCoord, bakeLod(z), TH_BUMP);
        waterMask = 1.0 - smoothstep(0.335, 0.352, b.tex.a);
        surf = b.tex.rgb;
        vec3 nB = Vw * (Rpi * b.nObj);
        shadeN = normalize(mix(nB, viewNorm, waterMask));
        cavity = mix(clamp(1.0 + (b.tex.a - b.hBlur) * 2.6, 0.68, 1.18), 1.0, waterMask);
        atmoColor = vec3(0.45, 0.78, 1.0);
        atmosphereRimStrength = 0.65;
    } else if (bType == 5) {
        Baked b = readBaked(pCoord, bakeLod(z), 0.18);
        surf = b.tex.rgb;
        shadeN = normalize(Vw * (Rpi * b.nObj));
        cavity = clamp(1.0 + (b.tex.a - b.hBlur) * 2.4, 0.65, 1.18);
        atmosphereRimStrength = 0.12;
    } else if (bType == 7) {
        Baked b = readBaked(pCoord, bakeLod(z), 0.22);
        float isLava = smoothstep(0.25, 0.55, b.tex.r - b.tex.b);
        surf = mix(b.tex.rgb, b.tex.rgb * 0.20, isLava);
        shadeN = normalize(Vw * (Rpi * b.nObj));
        cavity = clamp(1.0 + (b.tex.a - b.hBlur) * 2.2, 0.65, 1.20);
        emissive = b.tex.rgb * isLava * 1.10 + vec3(0.85, 0.32, 0.08) * (1.0 - isLava) * 0.14;
        atmoColor = vec3(1.0, 0.40, 0.08);
        atmosphereRimStrength = 0.70;
    } else if (bType == 8) {
        Baked b = readBaked(pCoord, bakeLod(z), 0.15);
        waterMask = 1.0 - smoothstep(0.55, 0.65, b.tex.a);
        surf = b.tex.rgb;
        vec3 nB = Vw * (Rpi * b.nObj);
        shadeN = normalize(mix(nB, viewNorm, 0.3));
        cavity = clamp(1.0 + (b.tex.a - b.hBlur) * 2.0, 0.75, 1.15);
        atmoColor = vec3(0.45, 0.92, 0.78);
        atmosphereRimStrength = 0.85;
    }

    float ndlGeo = dot(viewNorm, L);
    float ndl = dot(shadeN, L);
    float halfLambert = ndl * 0.5 + 0.5;
    float lightBand = mix(tw ? 0.30 : 0.55, 1.05, smoothstep(0.26, 0.58, halfLambert));
    lightBand += clamp((ndl - ndlGeo) * 1.0, -0.28, 0.28) * smoothstep(-0.15, 0.4, ndlGeo);

    float terminator = exp(-pow((ndlGeo + 0.05) * 4.2, 2.0)) * 0.22;
    vec3 warmBounce = vec3(1.0, 0.55, 0.25) * terminator;
    if (bType == 5) warmBounce *= 0.25;

    float rim = pow(1.0 - z, 2.8);
    if (tall && r > Rn) rim *= 0.3;
    vec3 cyanAura = vec3(0.25, 0.90, 0.85);
    vec3 purpleAura = vec3(0.65, 0.25, 0.55);
    vec3 dynamicAuraCol = (bType == 8)
        ? mix(purpleAura, cyanAura, smoothstep(-0.2, 0.4, ndlGeo))
        : atmoColor;
    if (bType == 5) dynamicAuraCol = vec3(0.50, 0.46, 0.42);
    if (bType == 4) dynamicAuraCol = mix(vec3(0.15, 0.25, 0.55), vec3(0.30, 0.60, 1.0), smoothstep(-0.2, 0.4, ndlGeo));
    vec3 rimGlow = dynamicAuraCol * rim * atmosphereRimStrength;

    vec3 Hh = normalize(L + vec3(0.0, 0.0, 1.0));
    float glint = smoothstep(0.30, 0.50, pow(max(dot(viewNorm, Hh), 0.0), 70.0)) * waterMask * step(0.0, ndlGeo);

    vec3 finalCol = surf * cavity * lightBand + emissive + warmBounce + rimGlow + vec3(1.0, 0.95, 0.80) * glint * 0.6;
    if (tw) finalCol += surf * vec3(0.11, 0.09, 0.26) * (1.0 - smoothstep(0.0, 0.45, ndlGeo));
    float edgeAA = tall ? cov : smoothstep(rs, rs - 0.025, r);
    if (tall) {
        fragColor = (vec4(finalCol * edgeAA, edgeAA) + haloC * (1.0 - edgeAA)) * qt_Opacity;
    } else {
        fragColor = (vec4(finalCol * edgeAA, edgeAA) + ((edgeAA < 0.999) ? outerAura(bType, r, rs, edgeR, uv, L) * (1.0 - edgeAA) : vec4(0.0))) * qt_Opacity;
    }
}
